#if !os(OSX)
    import CoreFoundation
#endif

import Foundation
import Cifaddrs
import DNS


let duplicateNameCheckTimeInterval = TimeInterval(2)

// TODO: check name availability before claiming the service's name
public class NetService: Responder, Listener {
    public var domain: String
    public var type: String
    public var name: String

    private var fqdn: String

    public struct Options: OptionSet {
        public let rawValue: Int
        public init(rawValue:Int) {
            self.rawValue = rawValue
        }

        public static let noAutoRename = Options(rawValue: 1)
        public static let listenForConnections = Options(rawValue: 2)
    }

    // MARK: Creating Network Services

    convenience init(domain: String, type: String, name: String) {
        self.init(domain: domain, type: type, name: name, port: -1)
    }

    public init(domain: String, type: String, name: String, port: Int32) {
        assert(domain == "local.", "only local. domain is supported")
        assert(type.hasSuffix("."), "type label(s) should end with a period")

        self.domain = domain
        self.type = type
        self.name = name
        self.port = Int(port)
        fqdn = "\(name).\(type)\(domain)"
    }

    // MARK: Configuring Network Services

    public internal(set) var addresses: [sockaddr_storage]?

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

    // MARK: Managing Run Loops

    var currentRunLoop: RunLoop?

    public func schedule(in aRunLoop: RunLoop,
                         forMode mode: RunLoopMode) {
        currentRunLoop = aRunLoop
        if let source = socket4?.1 {
            CFRunLoopAddSource(aRunLoop.getCFRunLoop(), source, .defaultMode)
        }

        if let source = socket6?.1 {
            CFRunLoopAddSource(aRunLoop.getCFRunLoop(), source, .defaultMode)
        }
    }

    public func remove(from aRunLoop: RunLoop,
                       forMode mode: RunLoopMode) {
        currentRunLoop = nil
        if let source = socket4?.1 {
            CFRunLoopRemoveSource(aRunLoop.getCFRunLoop(), source, .defaultMode)
        }
        if let source = socket6?.1 {
            CFRunLoopRemoveSource(aRunLoop.getCFRunLoop(), source, .defaultMode)
        }
    }

    // MARK: Using Network Services
    var socket4: (CFSocket, CFRunLoopSource)?
    var socket6: (CFSocket, CFRunLoopSource)?

    var client: Client?
    var pointerRecord: PointerRecord?
    var serviceRecord: ServiceRecord?
    var hostRecords: [ResourceRecord]?
    var textRecord: TextRecord?

    enum PublishState: Equatable {
        case stopped
        case lookingForDuplicates(Int, Timer)
        case published

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
        precondition(publishState == .stopped)

        client = try! Client.shared()

        // TODO: support ipv6
        // TODO: auto rename
        // TODO: support noAutoRename option

        delegate?.netServiceWillPublish(self)

        if !options.contains(.noAutoRename) {
            // check if name is taken -- allow others a few seconds to respond

            client!.listeners.append(self)
            client!.multicast(message: Message(header: Header(response: false), questions: [Question(name: fqdn, type: .service)]))
            // TODO: remove listener

            let timer = Timer._scheduledTimer(withTimeInterval: duplicateNameCheckTimeInterval, repeats: false, block: {_ in self.publishPhaseTwo()})
            publishState = .lookingForDuplicates(1, timer)
        }

        if options.contains(.listenForConnections) {
            precondition(type.hasSuffix("._tcp."), "only listening on TCP is supported")

            // host server
            var ipv4 = sockaddr_storage.fromSockAddr { (sin: inout sockaddr_in) in
                sin.sin_family = sa_family_t(AF_INET)
                sin.sin_addr = in_addr(s_addr: UInt32(bigEndian: INADDR_ANY))
                sin.sin_port = in_port_t(self.port).bigEndian
                }.1
            let socket = try! tcpListener(address: &ipv4)
            var ipv6 = sockaddr_storage.fromSockAddr { (sin: inout sockaddr_in6) in
                sin.sin6_family = sa_family_t(AF_INET6)
                sin.sin6_addr = in6addr_any
                sin.sin6_port = in_port_t(ipv4.port!).bigEndian
                }.1
            let socket6 = try! tcpListener(address: &ipv6)

            port = Int(ipv4.port!)

            self.socket4 = (socket, CFSocketCreateRunLoopSource(nil, socket, 0)!)
            self.socket6 = (socket6, CFSocketCreateRunLoopSource(nil, socket6, 0)!)

            if let currentRunLoop = currentRunLoop {
                CFRunLoopRemoveSource(currentRunLoop.getCFRunLoop(), self.socket4!.1, .defaultMode)
                CFRunLoopRemoveSource(currentRunLoop.getCFRunLoop(), self.socket6!.1, .defaultMode)
            }
        }
    }

    func publishPhaseTwo() {
        if let index = client!.listeners.index(where: {$0 === self }) {
            client!.listeners.remove(at: index)
        }

        hostName = try! gethostname() + "."
        precondition(hostName!.hasSuffix(domain), "host name \(hostName) should have suffix \(domain)")

        // publish mdns
        pointerRecord = PointerRecord(name: "\(type)\(domain)", ttl: 4500, destination: fqdn)

        precondition(port > 0)
        serviceRecord = ServiceRecord(name: fqdn, ttl: 120, port: UInt16(port), server: hostName!)

        // TODO: update host records on IP address changes
        addresses = getifaddrs()
            .filter { Int($0.pointee.ifa_flags) & Int(IFF_LOOPBACK) == 0 }
            .flatMap { sockaddr_storage(fromSockAddr: $0.pointee.ifa_addr.pointee) }
        hostRecords = addresses!.flatMap { (sa) -> ResourceRecord? in
            switch sa.ss_family {
            case sa_family_t(AF_INET):
                return sa.withSockAddrType { (sin: inout sockaddr_in) in
                    HostRecord<IPv4>(name: hostName!, ttl: 120, ip: IPv4(address: sin.sin_addr))
                }
            case sa_family_t(AF_INET6):
                return sa.withSockAddrType { (sin: inout sockaddr_in6) in
                    HostRecord<IPv6>(name: hostName!, ttl: 120, ip: IPv6(address: sin.sin6_addr))
                }
            default: return nil
            }
        }

        textRecord?.name = fqdn

        // prepare for questions
        client!.responders.append(self)

        // broadcast availability
        broadcastService()
        publishState = .published
        delegate?.netServiceDidPublish(self)
    }

    func broadcastService() {
        client!.multicast(message: Message(header: Header(response: true), answers: [pointerRecord!], additional: [serviceRecord!] + hostRecords!))
    }

    func tcpListener(address: inout sockaddr_storage) throws -> CFSocket {
        #if os(OSX)
            let fd = socket(Int32(address.ss_family), SOCK_STREAM, IPPROTO_TCP)
        #else
            let fd = socket(Int32(address.ss_family), Int32(SOCK_STREAM.rawValue), Int32(IPPROTO_TCP))
        #endif
        guard fd >= 0 else {
            #if os(OSX)
                throw POSIXError(POSIXError.Code(rawValue: errno)!)
            #else
                throw POSIXError(_nsError: NSError(domain: NSPOSIXErrorDomain, code: Int(errno)))
            #endif
        }

        // allow reuse
        var yes: UInt32 = 1
        try posix(setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &yes, socklen_t(MemoryLayout<UInt32>.size)))

        try address.withSockAddr {
            try posix(bind(fd, $0, $1))
            try posix(listen(fd, 4))
        }

        try address.withMutableSockAddr {
            try posix(getsockname(fd, $0, &$1))
        }

        var context = CFSocketContext()
        context.info = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        #if os(OSX)
            return CFSocketCreateWithNative(nil, fd, CFSocketCallBackType.acceptCallBack.rawValue, acceptCallBack, &context)!
        #else
            return CFSocketCreateWithNative(nil, fd, CFOptionFlags(kCFSocketAcceptCallBack), acceptCallBack, &context)!
        #endif
    }

    func respond(toMessage message: Message) -> (answers: [ResourceRecord], authorities: [ResourceRecord], additional: [ResourceRecord])? {
        var answers = [ResourceRecord]()
        var additional = [ResourceRecord]()

        for question in message.questions {
            switch question.type {
            case .pointer where question.name == pointerRecord?.name:
                answers.append(pointerRecord!)
                additional.append(serviceRecord!)
                additional.append(contentsOf: hostRecords!)
            case .service where question.name == serviceRecord?.name:
                answers.append(serviceRecord!)
                additional.append(contentsOf: hostRecords!)
            case .host:
                // TODO: only return ipv4 addresses
                answers.append(contentsOf: hostRecords!.filter({ $0.name == question.name }))
            case .host6:
                // TODO: only return ipv6 addresses
                answers.append(contentsOf: hostRecords!.filter({ $0.name == question.name }))
            case .text where question.name == textRecord?.name:
                if let textRecord = textRecord {
                    answers.append(textRecord)
                } else {
                    abort()
                }
            default: break
            }
        }
        return (answers, [], additional)
    }

    func received(message: Message) {
        guard case .lookingForDuplicates(let (number, timer)) = publishState else { return }

        if message.answers.flatMap({ $0 as? ServiceRecord }).contains(where: { $0.name == fqdn }) {
            timer.invalidate()

            fqdn = "\(name) (\(number + 1)).\(type)\(domain)"
            client!.multicast(message: Message(header: Header(response: false), questions: [Question(name: fqdn, type: .service)]))
            let timer = Timer._scheduledTimer(withTimeInterval: duplicateNameCheckTimeInterval, repeats: false, block: {_ in
                self.name = "\(self.name) (\(number + 1))"
                self.publishPhaseTwo()
            })
            publishState = .lookingForDuplicates(number + 1, timer)
        }
    }

    public func resolve(withTimeout timeout: TimeInterval) {

    }

    public internal(set) var port: Int = -1

    public func stop() {
        precondition(publishState == .published)

        CFSocketInvalidate(socket4!.0)
        CFSocketInvalidate(socket6!.0)

        pointerRecord!.ttl = 0
        serviceRecord!.ttl = 0
        broadcastService()

        if let index = client!.responders.index(where: {$0 === self }) {
            client!.responders.remove(at: index)
        }

        publishState = .stopped
        delegate?.netServiceDidStop(self)
    }

    // MARK: Obtaining the DNS Hostname

    public var hostName: String?
}

extension NetService: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "NetService(domain: \(domain), type: \(type), name: \(name), port: \(port), hostName: \(hostName), addresses: \(addresses))"
    }
}


func acceptCallBack(socket: CFSocket?, callBackType: CFSocketCallBackType, address: CFData?, data: UnsafeRawPointer?, info: UnsafeMutableRawPointer?) {
    let service = Unmanaged<NetService>.fromOpaque(info!).takeUnretainedValue()
    let nativeHandle = data!.bindMemory(to: CFSocketNativeHandle.self, capacity: 1).pointee
    var readStream: Unmanaged<CFReadStream>?
    var writeStream: Unmanaged<CFWriteStream>?
    CFStreamCreatePairWithSocket(nil, nativeHandle, &readStream, &writeStream)
    service.delegate?.netService(service, didAcceptConnectionWith: readStream!.takeUnretainedValue(), outputStream: writeStream!.takeUnretainedValue())
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
                    didAcceptConnectionWith inputStream: InputStream,
                    outputStream: OutputStream)
}
