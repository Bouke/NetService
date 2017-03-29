import Foundation
import Socket

#if os(Linux)
    import Dispatch
#endif

protocol UDPChannelDelegate: class {
    func channel(_ channel: UDPChannel, didReceive: Data, from: Socket.Address?) -> Data?
}

class UDPChannel {
    let socket: Socket
    let group: Socket.Address
    let queue: DispatchQueue
    weak var delegate: UDPChannelDelegate?
    
    init(group: Socket.Address, queue: DispatchQueue) throws {
        self.group = group
        self.queue = queue

        switch group {
        case .ipv4: socket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
        case .ipv6: socket = try Socket.create(family: .inet6, type: .datagram, proto: .udp)
        default: abort()
        }
        try socket.listen(on: Int(group.port))
        try socket.join(membership: Membership(address: group)!)
        
        queue.async {
            while true {
                var buffer = Data(capacity: 1024) //todo: how big's the buffer?
                let (_, address) = try! self.socket.readDatagram(into: &buffer)
                if let response = self.delegate?.channel(self, didReceive: buffer, from: address) {
                    try! self.socket.write(from: response, to: group)
                }
            }
        }
    }
    
    func multicast(_ data: Data) {
        try! self.socket.write(from: data, to: group)
    }
}
