import Foundation
import Socket

#if os(Linux)
    import Dispatch
#endif

protocol UDPChannelDelegate: class {
    func channel(_ channel: UDPChannel, didReceive: Data) -> Data?
}

class UDPChannel {
    let socket: Socket
    let group: Socket.Address
    let queue: DispatchQueue
    weak var delegate: UDPChannelDelegate?
    
    init(group: Socket.Address, queue: DispatchQueue) throws {
        self.group = group
        self.queue = queue

        socket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
        try socket.listen(on: Int(group.port))
        try socket.join(membership: Membership(address: group)!)
        
        queue.async {
            while true {
                var buffer = Data(capacity: 1024) //todo: how big's the buffer?
                _ = try! self.socket.readDatagram(into: &buffer)
                if let response = self.delegate?.channel(self, didReceive: buffer) {
                    try! self.socket.write(from: response, to: group)
                }
            }
        }
    }
    
    func multicast(_ data: Data) {
        try! self.socket.write(from: data, to: group)
    }
}
