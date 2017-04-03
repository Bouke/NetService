import Foundation
import DNS
import Socket

// TODO: track TTL of records
public class NetServiceBrowser: Listener {
    var responder: Responder
    var services = [String]()

    // MARK: Creating Network Service Browsers

    public init() {
        do {
            responder = try Responder.shared()
        } catch {
            fatalError("Could not get shared Responder: \(error)")
        }
        responder.listeners.append(self)
    }

    deinit {
        if let index = responder.listeners.index(where: { $0 === self }) {
            responder.listeners.remove(at: index)
        }
    }

    // MARK: Configuring Network Service Browsers

    public weak var delegate: NetServiceBrowserDelegate?

    // MARK: Using Network Service Browsers

    var currentSearch: (type: String, domain: String)?

    public func searchForServices(ofType type: String, inDomain domain: String) {
        assert(domain == "local.", "only local. domain is supported")
        assert(type.hasSuffix("."), "type label(s) should end with a period")
        delegate?.netServiceBrowserWillSearch(self)

        currentSearch = (type, domain)
        let query = Message(header: Header(response: false), questions: [Question(name: "\(type).\(domain)", type: .pointer)])
        do {
            try responder.multicast(message: query)
        } catch {
            delegate?.netServiceBrowser(self, didNotSearch: [String(describing: error): -1])
        }
    }

    func received(message: Message) {
        guard let (type, domain) = currentSearch else {
            return
        }

        let newPointers = message.answers
            .flatMap { $0 as? PointerRecord }
            .filter { !self.services.contains($0.destination) }
            .filter { $0.name == "\(type)\(domain)" }

        for pointer in newPointers {
            let service = NetService(domain: domain, type: type, name: pointer.destination.replacingOccurrences(of: ".\(type)\(domain)", with: ""))
            guard let serviceRecord = message.additional.flatMap({ $0 as? ServiceRecord }).first(where: { $0.name == pointer.destination }) else {
                continue
            }

            service.port = Int(serviceRecord.port)
            service.hostName = serviceRecord.server

            service.addresses = message.additional
                .flatMap { $0 as? HostRecord<IPv4> }
                .filter { $0.name == serviceRecord.server }
                .map { hostRecord in
                    var sin = sockaddr_in()
                    sin.sin_family = sa_family_t(AF_INET)
                    sin.sin_addr = hostRecord.ip.address
                    sin.sin_port = serviceRecord.port
                    return Socket.Address.ipv4(sin)
                }
            service.addresses! += message.additional
                .flatMap { $0 as? HostRecord<IPv6> }
                .filter { $0.name == serviceRecord.server }
                .map { hostRecord in
                    var sin6 = sockaddr_in6()
                    sin6.sin6_family = sa_family_t(AF_INET6)
                    sin6.sin6_addr = hostRecord.ip.address
                    sin6.sin6_port = serviceRecord.port
                    return Socket.Address.ipv6(sin6)
                }

            self.services.append(pointer.destination)
            self.delegate?.netServiceBrowser(self, didFind: service, moreComing: false)
        }
    }
}

public protocol NetServiceBrowserDelegate: class {
    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser)

    func netServiceBrowser(_ browser: NetServiceBrowser,
                           didNotSearch errorDict: [String : NSNumber])

    func netServiceBrowser(_ browser: NetServiceBrowser,
                           didFind service: NetService,
                           moreComing: Bool)

    func netServiceBrowser(_ browser: NetServiceBrowser,
                           didRemove service: NetService,
                           moreComing: Bool)

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser)
}

