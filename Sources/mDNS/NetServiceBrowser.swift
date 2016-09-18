import Foundation

// TODO: track TTL of records
public class NetServiceBrowser {
    internal var client: UDPMulticastClient

    var services = [String]()

    // MARK: Creating Network Service Browsers

    public init() {
        client = try! UDPMulticastClient()
        schedule(in: .current, forMode: .defaultRunLoopMode)
    }

    // MARK: Configuring Network Service Browsers

    public var delegate: NetServiceBrowserDelegate?

    // MARK: Using Network Service Browsers

    public func searchForServices(ofType type: String, inDomain domain: String) {
        let suffix = "\(type).\(domain)"

        let query = Message(header: Header(response: false), questions: [Question(name: suffix, type: .pointer)])
        client.multicast(data: Data(try! query.pack()))

        client.received = { (address, data, socket) in
            let message = Message(unpack: data)
            guard message.header.response else { return }

            let newPointers = message.answers
                .flatMap { $0 as? PointerRecord }
                .filter { !self.services.contains($0.destination) }

            for pointer in newPointers {
                let service = NetService(domain: domain, type: type, name: pointer.destination)
                guard let serviceRecord = message.additional.flatMap({ $0 as? ServiceRecord }).first(where: { $0.name == pointer.destination }) else {
                    continue
                }

                service.port = Int(serviceRecord.port)
                service.hostName = serviceRecord.server

                service.addresses = message.additional
                    .flatMap { $0 as? HostRecord<IPv4> }
                    .filter { $0.name == serviceRecord.server }
                    .map { hostRecord in
                        sockaddr_storage.fromSockAddr { (sin: inout sockaddr_in) in
                            sin.sin_family = sa_family_t(AF_INET)
                            sin.sin_addr = hostRecord.ip.address
                            sin.sin_port = serviceRecord.port
                        }.1
                    }
                service.addresses! += message.additional
                    .flatMap { $0 as? HostRecord<IPv6> }
                    .filter { $0.name == serviceRecord.server }
                    .map { hostRecord in
                    sockaddr_storage.fromSockAddr { (sin: inout sockaddr_in6) in
                        sin.sin6_family = sa_family_t(AF_INET6)
                        sin.sin6_addr = hostRecord.ip.address
                        sin.sin6_port = serviceRecord.port
                    }.1
                }

                self.services.append(pointer.destination)
                self.delegate?.netServiceBrowser(self, didFind: service, moreComing: false)
            }
        }
    }

    // MARK: Managing Run Loops

    public func schedule(in aRunLoop: RunLoop, forMode mode: RunLoopMode) {
        client.schedule(in: aRunLoop, forMode: mode)
    }

    public func remove(from aRunLoop: RunLoop, forMode mode: RunLoopMode) {
        client.remove(from: aRunLoop, forMode: mode)
    }
}

public protocol NetServiceBrowserDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser,
                           didFind service: NetService,
                           moreComing: Bool)

    func netServiceBrowser(_ browser: NetServiceBrowser,
                           didRemove service: NetService,
                           moreComing: Bool)

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser)
}

