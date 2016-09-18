import Foundation
import Cifaddrs

// TODO: check name availability before claiming the service's name
public class NetService: Responder {
    public var domain: String
    public var type: String
    public var name: String

    // MARK: Creating Network Services

    public init(domain: String, type: String, name: String) {
        self.domain = domain
        self.type = type
        self.name = name
    }

    public init(domain: String, type: String, name: String, port: Int) {
        self.domain = domain
        self.type = type
        self.name = name
        self.port = port
    }

    // MARK: Configuring Network Services

    public internal(set) var addresses: [sockaddr_storage]?

    // NOTE: Differs from Cocoa implementation (uses Data instead)
    public func setTXTRecord(_ recordData: [String: String]?) -> Bool {
        guard let recordData = recordData else {
            textRecord = nil
            return false
        }
        textRecord = TextRecord(name: name, ttl: 120, attributes: recordData)
        return true
    }

    // MARK: Using Network Services

    var client: Client?
    var pointerRecord: PointerRecord?
    var serviceRecord: ServiceRecord?
    var hostRecords: [ResourceRecord]?
    var textRecord: TextRecord?

    public func publish() {
        pointerRecord = PointerRecord(name: "\(type).\(domain)", ttl: 4500, destination: name)

        var output = Data(count: 255)
        hostName = try! output.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<CChar>) -> String? in
            try posix(gethostname(bytes, 255))
            return String(cString: bytes)
        }
        precondition(hostName!.hasSuffix(domain))
        precondition(port > 0)
        serviceRecord = ServiceRecord(name: name, ttl: 120, port: UInt16(port), server: hostName!)

        var addrs: UnsafeMutablePointer<ifaddrs>?
        try! posix(getifaddrs(&addrs))
        guard let first = addrs else { abort() }
        hostRecords = sequence(first: first, next: { $0.pointee.ifa_next })
            .filter { Int32($0.pointee.ifa_flags) & IFF_LOOPBACK == 0 }
            .flatMap { sockaddr_storage(fromSockAddr: $0.pointee.ifa_addr.pointee) }
            .flatMap { (sa) -> ResourceRecord? in
                switch sa.ss_family {
                case sa_family_t(AF_INET):
                    return sa.withSockAddrType { (sin: inout sockaddr_in) in
                        HostRecord<IPv4>(name: hostName!, ttl: 120, ip: IPv4(address: sin.sin_addr))
                    }
                default: return nil
                }
            }

        // prepare for questions
        client = try! Client.shared()
        client!.responders.append(self)

        // broadcast availability
        client?.multicast(message: Message(header: Header(response: false), answers: [pointerRecord!], additional: [serviceRecord!] + hostRecords!))
    }

    func respond(toMessage message: Message) -> (answers: [ResourceRecord], authorities: [ResourceRecord], additional: [ResourceRecord])? {
        print("Questions:", message.questions)
        var answers = [ResourceRecord]()
        var additional = [ResourceRecord]()

        for question in message.questions {
            switch question.type {
            case .pointer where question.name == pointerRecord?.name:
                answers.append(pointerRecord!)
                additional.append(serviceRecord!)
                additional.append(contentsOf: hostRecords!)
            case .service where question.name == name:
                answers.append(serviceRecord!)
                additional.append(contentsOf: hostRecords!)
            case .host:
                // TODO: only return ipv4 addresses
                answers.append(contentsOf: hostRecords!.filter({ $0.name == question.name }))
            case .host6:
                // TODO: only return ipv6 addresses
                answers.append(contentsOf: hostRecords!.filter({ $0.name == question.name }))
            case .text where question.name == name:
                if let textRecord = textRecord {
                    answers.append(textRecord)
                } else {
                    abort()
                }
            default: break
            }
        }

        print(answers, [], additional)
        return (answers, [], additional)
    }

    public func resolve(withTimeout timeout: TimeInterval) {

    }

    public internal(set) var port: Int = -1

    public func stop() {

    }

    // MARK: Obtaining the DNS Hostname

    public var hostName: String?
}

extension NetService: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "NetService(domain: \(domain), type: \(type), name: \(name), port: \(port), hostName: \(hostName), addresses: \(addresses))"
    }
}


protocol NetServiceDelegate {

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
