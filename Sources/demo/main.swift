import class Foundation.NSNumber
import class Foundation.RunLoop
import NetService
import Socket

#if os(OSX)
    import class Foundation.InputStream
    import class Foundation.OutputStream
#endif


// server
//var hapPointer = PointerRecord(name: "_hap._tcp.local", unique: false, internetClass: 1, ttl: 4500, destination: "Bridge._hap._tcp.local")
//var hapService = ServiceRecord(name: "Bridge._hap._tcp.local", unique: false, internetClass: 1, ttl: 120, priority: 0, weight: 0, port: 8000, server: "Bouke's iMac._ssh._tcp.local")
//var hapHost = HostRecord(name: "Bouke's iMac._ssh._tcp.local", unique: false, internetClass: 1, ttl: 120, ip: IPv4("10.0.1.14")!)
//var hapInfo = TextRecord(name: "Bridge._hap._tcp.local", unique: false, internetClass: 1, ttl: 120, attributes: [
//    "pv": "1.0", // state
//    "id": "11:22:33:44:55:66:77:88", // identifier
//    "c#": "1", // version
//    "s#": "1", // state
//    "sf": "1", // discoverable
//    "ff": "0", // mfi compliant
//    "md": "Bridge", // name
//    "ci": "1" // category identifier
//    ])
//
//let msg = Message(header: Header(id: 0, response: true, operationCode: .query, authoritativeAnswer: true, truncation: false, recursionDesired: false, recursionAvailable: false, returnCode: .NOERROR), questions: [], answers: [hapPointer], authorities: [], additional: [hapService, hapHost, hapInfo])

class MyBrowserDelegate: NetServiceBrowserDelegate {
    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        print("Will search: \(browser)")
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        print("Did not search: \(errorDict)")
    }

    public func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        print("Did find: \(service)")
    }

    public func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        print("Did remove: \(service)")
    }

    public func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {

    }
}

var toggle = true

class MyServiceDelegate: NetServiceDelegate {
    func netServiceWillPublish(_ sender: NetService) {
        print("\(sender) will publish")
    }

    func netServiceDidPublish(_ sender: NetService) {
        print("did publish")
        print("\(sender) did publish")
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        print("\(sender) did not publish: \(errorDict)")
    }

    func netServiceDidStop(_ sender: NetService) {
        print("\(sender) did stop")
    }

    public func netService(_ sender: NetService, didAcceptConnectionWith socket: Socket) {
        print("Did accept connection")
        print(try! socket.readString())
        try! socket.write(from: "HTTP/1.1 200 OK\r\nContent-Length: 13\r\n\r\nHello, world!")
        socket.close()
    }
}

let browser0 = NetServiceBrowser()
browser0.searchForServices(ofType: "_airplay._tcp.", inDomain: "local.")

let browser1 = NetServiceBrowser()
//browser1.searchForServices(ofType: "_airport._tcp.", inDomain: "local.")

let browserDelegate = MyBrowserDelegate()
browser0.delegate = browserDelegate
browser1.delegate = browserDelegate

let ns = NetService(domain: "local.", type: "_airplay._tcp.", name: "demo", port: 8000)
precondition(ns.setTXTRecord([
    "pv": "1.0", // state
    "id": "11:22:33:44:55:66:77:99", // identifier
    "c#": "1", // version
    "s#": "1", // state
    "sf": "1", // discoverable
    "ff": "0", // mfi compliant
    "md": "Swift", // name
    "ci": "1" // category identifier
]))
let serviceDelegate = MyServiceDelegate()
ns.delegate = serviceDelegate
ns.publish(options: [.noAutoRename, .listenForConnections])

withExtendedLifetime((browser0, browser1, browserDelegate, ns, serviceDelegate)) {
    RunLoop.main.run()
}

print("Got here!")
