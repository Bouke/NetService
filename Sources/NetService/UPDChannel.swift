import Foundation
import Socket

#if os(Linux)
    import Dispatch
#endif

protocol UDPChannelDelegate: class {
    func channel(_ channel: UDPChannel, didReceive: Data, from: Socket.Address)
}

class UDPChannel {
    enum Error: Swift.Error {
        case couldNotCreateSocket(Swift.Error)
        case couldNotListen(Swift.Error)
        case couldNotJoin(Swift.Error)
    }

    let socket: Socket
    let group: Socket.Address
    let queue: DispatchQueue
    weak var delegate: UDPChannelDelegate?

    init(group: Socket.Address, queue: DispatchQueue) throws {
        self.group = group
        self.queue = queue

        do {
            switch group {
            case .ipv4: socket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
            case .ipv6: socket = try Socket.create(family: .inet6, type: .datagram, proto: .udp)
            default: abort()
            }
        } catch {
            throw Error.couldNotCreateSocket(error)
        }
        do {
            try socket.listen(on: Int(group.port))
        } catch {
            throw Error.couldNotListen(error)
        }
        do {
            try socket.join(membership: Membership(address: group)!)
        } catch {
            throw Error.couldNotJoin(error)
        }

        queue.async {
            while true {
                var buffer = Data(capacity: 1024) //todo: how big's the buffer?
                let address: Socket.Address?
                do {
                    (_, address) = try self.socket.readDatagram(into: &buffer)
                } catch {
                    fatalError("Could not read from socket: \(error)")
                }
                if let address = address {
                    self.delegate?.channel(self, didReceive: buffer, from: address)
                }
            }
        }
    }

    func multicast(_ data: Data) throws {
        try self.socket.write(from: data, to: group)
    }

    func unicast(_ data: Data, to destination: Socket.Address) throws {
        try self.socket.write(from: data, to: destination)
    }
}
