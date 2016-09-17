import Foundation

public class NetServiceBrowser {
    internal var client: UDPMulticastClient

    var services = [String: NetService]()
    var pointerRecords = Set<PointerRecord>()

//    var reaper: Timer?
    var reaper: DispatchSourceTimer

    // MARK: Creating Network Service Browsers

    public init() {
        client = try! UDPMulticastClient()

        // TODO: move this to a Timer (which has different API on SwiftFoundation)
        reaper = DispatchSource.makeTimerSource()
        reaper.scheduleRepeating(deadline: DispatchTime.now(), interval: 5)
        reaper.setEventHandler(handler: reap)
        reaper.resume()

        schedule(in: .current, forMode: .defaultRunLoopMode)
    }

    // MARK: Configuring Network Service Browsers

    public var delegate: NetServiceBrowserDelegate?

    // MARK: Using Network Service Browsers

    public func searchForServices(ofType: String, inDomain: String) {
        let suffix = "\(ofType).\(inDomain)"

        client.received = { (address, data, socket) in
            let message = Message(unpack: data)
            guard message.header.response else { return }

            var seenPointerRecords = Set<PointerRecord>()

            for record in message.answers {
                if let record = record as? PointerRecord, record.name.hasSuffix(suffix) {
                    seenPointerRecords.insert(record)
                }
            }

            let newPointerRecords = seenPointerRecords.subtracting(self.pointerRecords)
            for record in newPointerRecords {
                let service = NetService(domain: inDomain, type: ofType, name: record.destination)
                self.services[record.destination] = service
                self.delegate?.netServiceBrowser(self, didFind: service, moreComing: false)
            }

            self.pointerRecords = seenPointerRecords.union(self.pointerRecords) // overwrite ttl
        }

        let query = Message(header: Header(id: 0, response: false, operationCode: .query, authoritativeAnswer: true, truncation: false, recursionDesired: false, recursionAvailable: false, returnCode: .NOERROR), questions: [Question(name: suffix, type: .pointer, internetClass: 1)], answers: [], authorities: [], additional: [])

        Data(try! query.pack()).dump()
        client.multicast(data: Data(try! query.pack()))
    }

    func reap() {
        // TODO: set expiry time on records instead of ttl?
        for var record in pointerRecords {
            if record.ttl > 5 {
                record.ttl -= 5
                pointerRecords.update(with: record)
            } else {
                if let service = services[record.destination] {
                    delegate?.netServiceBrowser(self, didRemove: service, moreComing: false)
                    services[record.destination] = nil
                }
                pointerRecords.remove(record)
            }
        }
        print(pointerRecords)
    }

    public func stop() {
        delegate?.netServiceBrowserDidStopSearch(self)
    }

    // MARK: Managing Run Loops

    public func schedule(in aRunLoop: RunLoop, forMode mode: RunLoopMode) {
        client.schedule(in: aRunLoop, forMode: mode)

//        reaper = Timer(timeInterval: 5, target: self, selector: #selector("reap"), userInfo: nil, repeats: true)
//        aRunLoop.add(reaper!, forMode: mode)
    }

    public func remove(from aRunLoop: RunLoop, forMode mode: RunLoopMode) {
        client.remove(from: aRunLoop, forMode: mode)
//        reaper?.invalidate()
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

