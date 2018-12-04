import struct Foundation.Data
import class Foundation.RunLoop
import NetService

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif


// import Foundation
// import NetService

class MyDelegate: NetServiceDelegate {
    func netServiceWillPublish(_ sender: NetService) {
        print("netServiceWillPublish")
    }
    func netService(_ sender: NetService,
                    didNotPublish error: Error) {
        print("didNotPublish \(error)")
    }
    func netServiceDidPublish(_ sender: NetService) {
        print("netServiceDidPublish")
    }
    func netServiceDidStop(_ sender: NetService) {
        print("netServiceDidStop")
    }
//    func netService(_ sender: NetService,
//                    didAcceptConnectionWith socket: Socket) {
//        print("didAcceptConnectionWith")
//    }
}

 let delegate = MyDelegate()
let service = NetService(domain: "local.", type: "_hap._tcp.", name: "Zithoek1", port: 8001)
service.delegate = delegate

var attributes = [
    "ff": "0",
    "ci": "2",
    "sh": "Bouke",
    "md": "Bridge",
    "s#": "1",
    "c#": "1",
    "sf": "0",
    "pv": "1.0",
    "id": "7F:43:D1:53:4A:DA",
]
service.setTXTRecord(NetService.data(fromTXTRecord: attributes))
service.publish(options: [.listenForConnections])

import struct Foundation.Date

print("5 sec runloop...")
RunLoop.main.run(until: Date.init(timeIntervalSinceNow: 5))

service.stop()

//attributes["ff"] = "1"
//service.setTXTRecord(NetService.data(fromTXTRecord: attributes))

print("indefinite runloop...")
withExtendedLifetime((service, delegate)) {
    RunLoop.main.run()
}
