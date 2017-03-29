import Foundation
import DNS
import Socket
#if os(Linux)
    import Dispatch
#endif


class Client {
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
    let socket: Socket

    private init() throws {
        socket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
        try socket.listen(on: 5353)
        try socket.join(membership: Membership(address: in_addr("224.0.0.251")!))

        var ipv4Group = sockaddr_in()
        ipv4Group.sin_family = sa_family_t(AF_INET)
        ipv4Group.sin_addr = IPv4("224.0.0.251")!.address
        ipv4Group.sin_port = (5353 as in_port_t).bigEndian
        
        queue.async {
            while true {
                var buffer = Data(capacity: 1024) //todo: how big's the buffer?
                _ = try! self.socket.readDatagram(into: &buffer)
                let response = self.received(buffer: buffer, onSocket: self.socket)
                if let response = response {
                    print("Sending response: \(response)")
                    try! self.socket.write(from: Data(bytes: response.pack()), to: .ipv4(ipv4Group))
                }
            }
        }
    }
    
    func received(buffer: Data, onSocket socket: Socket) -> Message? {
        let message = Message(unpack: buffer)
       
        print("Got message: \(message)")
        
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
            
            return Message(header: Header(response: true), answers: answers, authorities: authorities, additional: additional)
        }
    }

    internal func multicast(message: Message) {
        var ipv4Group = sockaddr_in()
        ipv4Group.sin_family = sa_family_t(AF_INET)
        ipv4Group.sin_addr = IPv4("224.0.0.251")!.address
        ipv4Group.sin_port = (5353 as in_port_t).bigEndian
        try! socket.write(from: Data(bytes: message.pack()), to: .ipv4(ipv4Group))
    }
}

protocol Listener: class {
    func received(message: Message)
}

protocol Responder: class {
    func respond(toMessage: Message) -> (answers: [ResourceRecord], authorities: [ResourceRecord], additional: [ResourceRecord])?
}
