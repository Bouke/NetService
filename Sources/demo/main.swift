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

class MyDelegate: mDNS.NetServiceBrowserDelegate {
    public func netServiceBrowser(_ browser: mDNS.NetServiceBrowser, didFind service: mDNS.NetService, moreComing: Bool) {
        print("Did find: \(service)")
    }

    public func netServiceBrowser(_ browser: mDNS.NetServiceBrowser, didRemove service: mDNS.NetService, moreComing: Bool) {
        print("Did remove: \(service)")
    }

    public func netServiceBrowserDidStopSearch(_ browser: mDNS.NetServiceBrowser) {

    }
}

let browser = mDNS.NetServiceBrowser()
browser.searchForServices(ofType: "_ssh._tcp", inDomain: "local")

let delegate = MyDelegate()
browser.delegate = delegate
withExtendedLifetime((browser, delegate)) {
    RunLoop.main.run()
}
