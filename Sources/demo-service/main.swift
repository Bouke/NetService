import struct Foundation.Data
import NetService

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif


// import Foundation
// import NetService

// class MyDelegate: NetServiceDelegate {
//     func netServiceWillPublish(_ sender: NetService) {
//         print("netServiceWillPublish")
//     }
//     func netService(_ sender: NetService,
//                     didNotPublish error: Error) {
//         print("didNotPublish \(error)")
//     }
//     func netServiceDidPublish(_ sender: NetService) {
//         print("netServiceDidPublish")
//     }
//     func netServiceDidStop(_ sender: NetService) {
//         print("netServiceDidStop")
//     }
//     // func netService(_ sender: NetService,
//     //                 didAcceptConnectionWith socket: Socket) {
//     //     print("didAcceptConnectionWith")
//     // }
// }

// let delegate = MyDelegate()
let service = NetService(domain: "local.", type: "_hap._tcp.", name: "Zithoek1", port: 8001)

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
func rdata(_ attrs: [String: String]) -> Data {
    return attrs.reduce(Data()) {
        let attr = "\($1.key)=\($1.value)".utf8
        return $0 + Data([UInt8(attr.count)]) + Data(attr)
    }
}

service.setTXTRecord(rdata(attributes))
// service.delegate = delegate
service.publish(options: [.listenForConnections])
sleep(5)
print("updating...")
attributes["ff"] = "1"
service.setTXTRecord(rdata(attributes))
sleep(60)


// withExtendedLifetime((service, delegate)) {
    // RunLoop.main.run()
// }
