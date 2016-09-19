import Foundation
import DNS


class Client {
    private static var _shared: Client?
    internal static func shared() throws -> Client {
        if let shared = _shared {
            return shared
        }
        _shared = try Client()
        return _shared!
    }

    private var channel: UDPChannel
    internal var listeners = [Listener]()
    internal var responders = [Responder]()

    private init() throws {
        channel = try UDPChannel()
        channel.schedule(in: .main, forMode: .defaultRunLoopMode)
        channel.received = { (address, data, socket) in
            let message = Message(unpack: data)

            if message.header.response {
                for listener in self.listeners {
                    listener.received(message: message)
                }
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
                    return
                }

                let response = Message(header: Header(response: true), answers: answers, authorities: authorities, additional: additional)
                self.multicast(message: response)
            }
        }
    }

    internal func multicast(message: Message) {
        self.channel.multicast(data: Data(try! message.pack()))
    }
}

protocol Listener: class {
    func received(message: Message)
}

protocol Responder: class {
    func respond(toMessage: Message) -> (answers: [ResourceRecord], authorities: [ResourceRecord], additional: [ResourceRecord])?
}
