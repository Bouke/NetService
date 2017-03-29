import Foundation
import DNS
import Socket
#if os(Linux)
    import Dispatch
#endif


class Client: UDPChannelDelegate {
    let ipv4Group: Socket.Address = {
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr = IPv4("224.0.0.251")!.address
        addr.sin_port = (5353 as in_port_t).bigEndian
        return .ipv4(addr)
    }()
    
    private static var _shared: Client?
    internal static func shared() throws -> Client {
        if let shared = _shared {
            return shared
        }
        _shared = try Client()
        return _shared!
    }

    internal var listeners = [Listener]()
    internal var responders = [Responder]()
    let queue = DispatchQueue.global(qos: .userInteractive)
    let channel: UDPChannel

    private init() throws {
        channel = try UDPChannel(group: ipv4Group, queue: queue)
        channel.delegate = self
    }
    
    func channel(_ channel: UDPChannel, didReceive data: Data) -> Data? {
        let message = Message(unpack: data)
       
        if message.header.response {
            for listener in self.listeners {
                listener.received(message: message)
            }
            return nil
        } else {
            var answers = [ResourceRecord]()
            var authorities = [ResourceRecord]()
            var additional = [ResourceRecord]()
            
            for responder in self.responders {
                guard let response = responder.respond(toMessage: message) else {
                    continue
                }
                answers += response.answers
                authorities += response.authorities
                additional += response.additional
            }
            
            guard answers.count > 0 else {
                return nil
            }
            
            let message = Message(header: Header(response: true), answers: answers, authorities: authorities, additional: additional)
            return try! Data(bytes: message.pack())
        }
    }
    
    func multicast(message: Message) {
        try! channel.multicast(Data(bytes: message.pack()))
    }
}

protocol Listener: class {
    func received(message: Message)
}

protocol Responder: class {
    func respond(toMessage: Message) -> (answers: [ResourceRecord], authorities: [ResourceRecord], additional: [ResourceRecord])?
}
