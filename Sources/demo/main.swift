import Foundation
import mDNS


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

class MyBrowserDelegate: mDNS.NetServiceBrowserDelegate {
    public func netServiceBrowser(_ browser: mDNS.NetServiceBrowser, didFind service: mDNS.NetService, moreComing: Bool) {
        print("Did find: \(service)")
    }

    public func netServiceBrowser(_ browser: mDNS.NetServiceBrowser, didRemove service: mDNS.NetService, moreComing: Bool) {
        print("Did remove: \(service)")
    }

    public func netServiceBrowserDidStopSearch(_ browser: mDNS.NetServiceBrowser) {

    }
}

let browser0 = mDNS.NetServiceBrowser()
//browser0.searchForServices(ofType: "_airplay._tcp", inDomain: "local")

let browser1 = mDNS.NetServiceBrowser()
//browser1.searchForServices(ofType: "_adisk._tcp", inDomain: "local")

let browserDelegate = MyBrowserDelegate()
browser0.delegate = browserDelegate
browser1.delegate = browserDelegate

let ns = mDNS.NetService(domain: "local", type: "_airplay._tcp", name: "MacBook._airplay._tcp.local", port: 8000)
precondition(ns.setTXTRecord([
    "pv": "1.0", // state
    "id": "11:22:33:44:55:66:77:88", // identifier
    "c#": "1", // version
    "s#": "1", // state
    "sf": "1", // discoverable
    "ff": "0", // mfi compliant
    "md": "Bridge", // name
    "ci": "1" // category identifier
]))
ns.publish()

withExtendedLifetime((browser0, browser1, browserDelegate, ns)) {
    RunLoop.main.run()
}
