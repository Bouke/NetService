#if os(Linux)
    import Dispatch
#endif

import Foundation
import Cifaddrs
import DNS
import Socket


let duplicateNameCheckTimeInterval = TimeInterval(3)

// TODO: check name availability before claiming the service's name
public class NetService: Listener {
    public var domain: String
    public var type: String
    public var name: String

    internal var fqdn: String

    public struct Options: OptionSet {
        public let rawValue: Int
        public init(rawValue:Int) {
            self.rawValue = rawValue
        }

        public static let noAutoRename = Options(rawValue: 1)
        public static let listenForConnections = Options(rawValue: 2)
    }

    // MARK: Creating Network Services

    public convenience init(domain: String, type: String, name: String) {
        self.init(domain: domain, type: type, name: name, port: -1)
    }

    public init(domain: String, type: String, name: String, port: Int32) {
        precondition(domain == "local.", "only local. domain is supported")
        precondition(type.hasSuffix("."), "type label(s) should end with a period")
        precondition(port >= -1 && port <= 65535, "Port should be in the range 0-65535")

        self.domain = domain
        self.type = type
        self.name = name
        self.port = Int(port)
        fqdn = "\(name).\(type)\(domain)"
    }

    // MARK: Configuring Network Services

    public internal(set) var addresses: [Socket.Address]?

    public weak var delegate: NetServiceDelegate?

    // NOTE: Differs from Cocoa implementation (uses Data instead)
    public func setTXTRecord(_ recordData: [String: String]?) -> Bool {
        guard let recordData = recordData else {
            textRecord = nil
            return false
        }
        textRecord = TextRecord(name: fqdn, ttl: 120, attributes: recordData)
        return true
    }

    // MARK: Using Network Services
    var listenQueue: DispatchQueue?
    var socket4: Socket?
    var socket6: Socket?

    var responder: Responder?
    var pointerRecord: PointerRecord?
    var serviceRecord: ServiceRecord?
    var hostRecords: [ResourceRecord]?
    var textRecord: TextRecord?

    enum PublishState: Equatable {
        case stopped
        case lookingForDuplicates(Int, Timer)
        case published
        case didNotPublish(Error)

        static func == (lhs: PublishState, rhs: PublishState) -> Bool {
            switch (lhs, rhs) {
            case (.stopped, .stopped), (.published, .published): return true
            case (.lookingForDuplicates(_), .lookingForDuplicates(_)): return true
            default: return false
            }
        }
    }
    var publishState: PublishState = .stopped

    public func publish(options: Options = []) {
        precondition(publishState == .stopped, "invalid state, should be .stopped")
        precondition(port >= 0, "port should be >= 0")

        do {
            responder = try Responder.shared()
        } catch {
            return publishError(error)
        }
        hostName = responder!.hostname

        // TODO: support ipv6
        // TODO: auto rename
        // TODO: support noAutoRename option

        delegate?.netServiceWillPublish(self)

        if !options.contains(.noAutoRename) {
            // check if name is taken -- allow others a few seconds to respond

            responder!.listeners.append(self)
            do {
                try responder!.multicast(message: Message(header: Header(response: false), questions: [Question(name: fqdn, type: .service)]))
            } catch {
                return publishError(error)
            }
            // TODO: remove listener

            let timer = Timer._scheduledTimer(withTimeInterval: duplicateNameCheckTimeInterval, repeats: false, block: {_ in self.publishPhaseTwo()})
            publishState = .lookingForDuplicates(1, timer)
        }

        if options.contains(.listenForConnections) {
            precondition(type.hasSuffix("._tcp."), "only listening on TCP is supported")

            listenQueue = DispatchQueue.global(qos: .userInteractive)

            do {
                socket4 = try Socket.create(family: .inet, type: .stream, proto: .tcp)
                try socket4!.listen(on: self.port)
                self.port = Int(socket4!.signature!.port)

                socket6 = try Socket.create(family: .inet6, type: .stream, proto: .tcp)
                try socket6!.listen(on: self.port)
            } catch {
                publishError(error)
            }

            listenQueue!.async { [unowned self] in
                while true {
                    do {
                        let responderSocket = try self.socket4!.acceptClientConnection()
                        self.delegate?.netService(self, didAcceptConnectionWith: responderSocket)
                    } catch {
                        self.publishError(error)
                        break
                    }
                }
            }
            listenQueue!.async { [unowned self] in
                while true {
                    do {
                        let responderSocket = try self.socket6!.acceptClientConnection()
                        self.delegate?.netService(self, didAcceptConnectionWith: responderSocket)
                    } catch {
                        self.publishError(error)
                        break
                    }
                }
            }
        }

        if options.contains(.noAutoRename) {
            publishPhaseTwo()
        }
    }

    func publishPhaseTwo() {
        precondition(port > 0, "Port not configured")

        if let index = responder!.listeners.index(where: {$0 === self }) {
            responder!.listeners.remove(at: index)
        }
        
        addresses = responder!.addresses.map {
            var address = $0
            address.port = UInt16(self.port)
            return address
        }
        pointerRecord = PointerRecord(name: "\(type)\(domain)", ttl: 4500, destination: fqdn)
        serviceRecord = ServiceRecord(name: fqdn, ttl: 120, port: UInt16(port), server: hostName!)
        textRecord?.name = fqdn
        
        // broadcast availability
        do {
            try responder!.publish(self)
        } catch {
            return publishError(error)
        }
        
        publishState = .published
        delegate?.netServiceDidPublish(self)
    }

    func publishError(_ error: Error) {
        if case .lookingForDuplicates(let (_, timer)) = publishState {
            timer.invalidate()
        }
        publishState = .didNotPublish(error)
        switch error {
        case let error as NSError:
            delegate?.netService(self, didNotPublish: [error.description: NSNumber(integerLiteral: error.code)])
        case let error as POSIXError:
            delegate?.netService(self, didNotPublish: ["\(error.code.rawValue)": NSNumber(integerLiteral: Int(error.code.rawValue))])
        default:
            delegate?.netService(self, didNotPublish: [String(describing: error): -1])
        }

    }

    func received(message: Message) {
        guard case .lookingForDuplicates(let (number, timer)) = publishState else { return }

        if message.answers.flatMap({ $0 as? ServiceRecord }).contains(where: { $0.name == fqdn }) {
            timer.invalidate()

            fqdn = "\(name) (\(number + 1)).\(type)\(domain)"
            do {
                try responder!.multicast(message: Message(header: Header(response: false), questions: [Question(name: fqdn, type: .service)]))
            } catch {
                return publishError(error)
            }
            let timer = Timer._scheduledTimer(withTimeInterval: duplicateNameCheckTimeInterval, repeats: false, block: {_ in
                self.name = "\(self.name) (\(number + 1))"
                self.publishPhaseTwo()
            })
            publishState = .lookingForDuplicates(number + 1, timer)
        }
    }

    public func resolve(withTimeout timeout: TimeInterval) {
        preconditionFailure("Not implemented")
    }

    public internal(set) var port: Int = -1

    public func stop() {
        precondition(publishState == .published)
        try! responder!.unpublish(self)
        publishState = .stopped
        delegate?.netServiceDidStop(self)
    }

    // MARK: Obtaining the DNS Hostname

    public internal(set) var hostName: String?
}

extension NetService: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "NetService(domain: \(domain), type: \(type), name: \(name), port: \(port), hostName: \(String(describing: hostName))), addresses: \(String(describing: addresses)))"
    }
}


public protocol NetServiceDelegate: class {

    // MARK: Using Network Services

    func netServiceWillPublish(_ sender: NetService)

    func netServiceDidPublish(_ sender: NetService)

    func netService(_ sender: NetService,
                    didNotPublish errorDict: [String : NSNumber])

    func netServiceDidStop(_ sender: NetService)

    // MARK: Accepting Connections

    func netService(_ sender: NetService,
                    didAcceptConnectionWith socket: Socket)
}
