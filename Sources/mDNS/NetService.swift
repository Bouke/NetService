import Foundation

public class NetService {
    var domain: String
    var type: String
    var name: String

    var client: UDPMulticastClient?

    // MARK: Creating Network Services

    public init(domain: String, type: String, name: String) {
        self.domain = domain
        self.type = type
        self.name = name
    }

    // MARK: Configuring Network Services

    public internal(set) var addresses: [sockaddr_storage]?

    // MARK: Using Network Services

    func publish() {
        client = try! UDPMulticastClient()
        client!.received = { (address, data, socket) in
            
        }
    }

    func resolve(withTimeout timeout: TimeInterval) {

    }

    var port: Int = -1

    func stop() {

    }

    // MARK: Obtaining the DNS Hostname

    var hostName: String?
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
