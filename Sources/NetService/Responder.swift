import Foundation
import DNS
import Socket
#if os(Linux)
    import Dispatch
#endif


class Responder: UDPChannelDelegate {
    enum Error: Swift.Error {
        case channelSetupError(Swift.Error)
        case missingResourceRecords
    }
    
    let ipv4Group: Socket.Address = {
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr = IPv4("224.0.0.251")!.address
        addr.sin_port = (5353 as in_port_t).bigEndian
        return .ipv4(addr)
    }()
    
    let ipv6Group: Socket.Address = {
        var addr = sockaddr_in6()
        addr.sin6_family = sa_family_t(AF_INET)
        addr.sin6_addr = IPv6("FF02::FB")!.address
        addr.sin6_port = (5353 as in_port_t).bigEndian
        return .ipv6(addr)
    }()
    
    private static var _shared: Responder?
    internal static func shared() throws -> Responder {
        if let shared = _shared {
            return shared
        }
        _shared = try Responder()
        return _shared!
    }

    internal var listeners = [Listener]()
    let queue = DispatchQueue.global(qos: .userInteractive)
    let channels: [UDPChannel]
    public private(set) var publishedServices: [NetService] = []
    
    // TODO: update host records on IP address changes
    let hostname: String
    let addresses: [Socket.Address]
    let hostRecords: [ResourceRecord]
    let host6Records: [ResourceRecord]
    
    private init() throws {
        do {
            try channels = [
                UDPChannel(group: ipv4Group, queue: queue),
                // UDPChannel(group: ipv6Group, queue: queue),
            ]
        } catch {
            throw Error.channelSetupError(error)
        }
        
        let hostname = try gethostname() + "."
        precondition(hostname.hasSuffix(".local."), "host name \(hostname) should have suffix .local")
        self.hostname = hostname

        addresses = getLocalAddresses()

        hostRecords = addresses.flatMap { (address) -> HostRecord<IPv4>? in
            switch address {
            case .ipv4(let sin):
                return HostRecord<IPv4>(name: hostname, ttl: 120, ip: IPv4(address: sin.sin_addr))
            default:
                return nil
            }
        }
        host6Records = addresses.flatMap { (address) -> HostRecord<IPv6>? in
            switch address {
            case .ipv6(let sin6):
                return HostRecord<IPv6>(name: hostname, ttl: 120, ip: IPv6(address: sin6.sin6_addr))
            default:
                return nil
            }
        }
        channels.forEach { $0.delegate = self }
    }
    
    func channel(_ channel: UDPChannel, didReceive data: Data, from source: Socket.Address) {
        let message: Message
        do {
            message = try Message(unpack: data)
        } catch {
            return NSLog("Could not unpack message")
        }
        if message.header.response {
            for listener in self.listeners {
                listener.received(message: message)
            }
            return
        } else {
            var answers = [ResourceRecord]()
            var authorities = [ResourceRecord]()
            var additional = [ResourceRecord]()
            
            for question in message.questions {
                switch question.type {
                case .pointer:
                    for service in publishedServices {
                        if let pointerRecord = service.pointerRecord,
                            let serviceRecord = service.serviceRecord,
                            pointerRecord.name == question.name
                        {
                            answers.append(pointerRecord)
                            additional.append(serviceRecord)
                            additional += hostRecords
                            additional += host6Records
                            if let textRecord = service.textRecord {
                                additional.append(textRecord)
                            }
                        }
                    }
                case .service:
                    for service in publishedServices {
                        if let serviceRecord = service.serviceRecord, serviceRecord.name == question.name {
                            answers.append(serviceRecord)
                            additional += hostRecords
                            additional += host6Records
                        }
                    }
                case .host where question.name == hostname:
                    answers += hostRecords
                    additional += host6Records
                case .host6 where question.name == hostname:
                    answers += host6Records
                    additional += hostRecords
                case .text:
                    for service in publishedServices {
                        if let textRecord = service.textRecord, textRecord.name == question.name {
                            answers.append(textRecord)
                        }
                    }
                default:
                    break
                }
            }
            
            guard answers.count > 0 else {
                return
            }
            
            var response = Message(header: Header(response: true),
                                   questions: message.questions,
                                   answers: answers,
                                   authorities: authorities,
                                   additional: additional)

            // The destination UDP port in all Multicast DNS responses MUST be 5353,
            // and the destination address MUST be the mDNS IPv4 link-local
            // multicast address 224.0.0.251 or its IPv6 equivalent FF02::FB, except
            // when generating a reply to a query that explicitly requested a
            // unicast response:
            //
            //    * via the unicast-response bit,
            //    * by virtue of being a legacy query (Section 6.7), or
            //    * by virtue of being a direct unicast query.
            //
            /// @todo: implement this logic
            do {
                if source.port == 5353 {
                    try channel.multicast(response.pack())
                } else {
                    // In this case, the Multicast DNS responder MUST send a UDP response
                    // directly back to the querier, via unicast, to the query packet's
                    // source IP address and port.  This unicast response MUST be a
                    // conventional unicast response as would be generated by a conventional
                    // Unicast DNS server; for example, it MUST repeat the query ID and the
                    // question given in the query message.  In addition, the cache-flush
                    // bit described in Section 10.2, "Announcements to Flush Outdated Cache
                    // Entries", MUST NOT be set in legacy unicast responses.
                    response.header.id = message.header.id
                    
                    try channel.unicast(response.pack(), to: source)
                }
            } catch {
                NSLog("Error while replying to \(message) with response \(response): \(error)")
            }
        }
    }
    
    func publish(_ service: NetService) throws {
        guard let pointerRecord = service.pointerRecord, let serviceRecord = service.serviceRecord else {
            throw Error.missingResourceRecords
        }
        publishedServices.append(service)
        var message = Message(header: Header(response: true),
                              answers: [pointerRecord, serviceRecord],
                              additional: hostRecords)
        if let textRecord = service.textRecord {
            message.additional += [textRecord]
        }
        try multicast(message: message)
    }

    func unpublish(_ service: NetService) throws {
        guard var pointerRecord = service.pointerRecord, var serviceRecord = service.serviceRecord else {
            throw Error.missingResourceRecords
        }
        if let index = publishedServices.index(where: { $0 === service }) {
            publishedServices.remove(at: index)
            pointerRecord.ttl = 0
            serviceRecord.ttl = 0
            var message = Message(header: Header(response: true),
                                  answers: [pointerRecord, serviceRecord])
            if var textRecord = service.textRecord {
                textRecord.ttl = 0
                message.additional += [textRecord]
            }
            try multicast(message: message)
        }
    }

    func multicast(message: Message) throws {
        for channel in channels {
            try channel.multicast(message.pack())
        }
    }
}

protocol Listener: class {
    func received(message: Message)
}
