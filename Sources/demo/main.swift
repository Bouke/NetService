import Darwin
import Foundation
import mDNS

func posix(_ block: @autoclosure () -> Int32) throws {
    guard block() == 0 else {
        throw POSIXError(POSIXErrorCode(rawValue: errno)!)
    }
}

func ntohs(_ value: CUnsignedShort) -> CUnsignedShort {
    return (value << 8) + (value >> 8);
}
let htons = ntohs

// all services: _services._dns-sd._udp.local

//let query = Message(header: Header(id: 0, response: false, operationCode: .query, authoritativeAnswer: false, truncation: false, recursionDesired: false, recursionAvailable: false, returnCode: .NOERROR),
//                    questions: [Question(name: "_airport._tcp.local", type: .pointer, unique: false, internetClass: 1)],
//                    answers: [],
//                    authorities: [],
//                    additional: [])

let INADDR_ANY = in_addr(s_addr: 0)

let socketfd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
precondition(socketfd != 0)
var yes: UInt32 = 1

// allow reuse
try posix(setsockopt(socketfd, SOL_SOCKET, SO_REUSEPORT, &yes, socklen_t(MemoryLayout<UInt32>.size)))

var addr2 = sockaddr_in()
addr2.sin_family = sa_family_t(AF_INET)
addr2.sin_port = htons(5353)
addr2.sin_addr = INADDR_ANY

let addr3 = withUnsafePointer(to: &addr2) {
    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        $0
    }
}

try posix(bind(socketfd, addr3, socklen_t(MemoryLayout<sockaddr_in>.size)))

// request kernel to join multicast group
var group_addr = in_addr()
precondition(inet_pton(AF_INET, "224.0.0.251", &group_addr) == 1)
var mreq = ip_mreq(imr_multiaddr: group_addr, imr_interface: INADDR_ANY)
try posix(setsockopt(socketfd, IPPROTO_IP, IP_ADD_MEMBERSHIP, &mreq, socklen_t(MemoryLayout<ip_mreq>.size)))

//var no: UInt32 = 0
//try posix(setsockopt(socketfd, IPPROTO_IP, IP_MULTICAST_LOOP, &no, socklen_t(MemoryLayout<UInt32>.size)))
//
//var answer = 0
//var len = socklen_t(MemoryLayout<Int>.size)
//try posix(getsockopt(socketfd, IPPROTO_IP, IP_MULTICAST_LOOP, &answer, &len))
//print(answer, len)
//exit(0)

var connection: CFSocket!

// server
var hapPointer = PointerRecord(name: "_hap._tcp.local", unique: false, internetClass: 1, ttl: 4500, destination: "Bridge._hap._tcp.local")
var hapService = ServiceRecord(name: "Bridge._hap._tcp.local", unique: false, internetClass: 1, ttl: 120, priority: 0, weight: 0, port: 8000, server: "Bouke's iMac._ssh._tcp.local")
var hapHost = HostRecord(name: "Bouke's iMac._ssh._tcp.local", unique: false, internetClass: 1, ttl: 120, ip: IPv4("10.0.1.14")!)
var hapInfo = TextRecord(name: "Bridge._hap._tcp.local", unique: false, internetClass: 1, ttl: 120, attributes: [
    "pv": "1.0", // state
    "id": "11:22:33:44:55:66:77:88", // identifier
    "c#": "1", // version
    "s#": "1", // state
    "sf": "1", // discoverable
    "ff": "0", // mfi compliant
    "md": "Bridge", // name
    "ci": "1" // category identifier
    ])

//delete
//hapPointer.ttl = 0


let msg = Message(header: Header(id: 0, response: true, operationCode: .query, authoritativeAnswer: true, truncation: false, recursionDesired: false, recursionAvailable: false, returnCode: .NOERROR), questions: [], answers: [hapPointer], authorities: [], additional: [hapService, hapHost, hapInfo])
let msg2 = try msg.pack()
let msg3 = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, msg2, msg2.count, kCFAllocatorDefault)

var dest = sockaddr_in()
dest.sin_family = sa_family_t(AF_INET)
dest.sin_addr = group_addr
dest.sin_port = htons(5353)

let dest2 = withUnsafePointer(to: &dest) {
    $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<sockaddr_in>.size) {
        CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, $0, MemoryLayout<sockaddr_in>.size, kCFAllocatorDefault)
    }
}

func broadcastService() {
    // notify availability
    precondition(CFSocketSendData(connection, dest2, msg3, 2) == .success)
}




// browser
// todo: discover local IP -> put in HostRecord
// todo: discover local hostname -> put in ServiceRecord + HostRecord
var pointers = Set<PointerRecord>()
var services = Set<ServiceRecord>()

//func cast<T>(_ a: Data) -> T {
//    var a = a
//    return a.withUnsafeMutableBytes {
//        $0.withMemoryRebound(to: T.self, capacity: 1) {
//            $0.pointee
//        }
//    }
//}

func createIP(data: CFData) -> IP? {
    let generic = CFDataGetBytePtr(data).withMemoryRebound(to: sockaddr.self, capacity: 1) {
        return $0.pointee
    }
    switch generic.sa_family {
    case sa_family_t(AF_INET):
        return CFDataGetBytePtr(data).withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
            IPv4(address: $0.pointee.sin_addr)
        }
    case sa_family_t(AF_INET6):
        return CFDataGetBytePtr(data).withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
            IPv6(address: $0.pointee.sin6_addr)
        }
    default:
        return nil
    }
}

// @todo use CFSocketCreate instead (for creating the CFSocket)
//CFSocketCallBack
connection = CFSocketCreateWithNative(kCFAllocatorDefault, socketfd, CFSocketCallBackType.dataCallBack.rawValue, { (s, callbackType, address, data, info) in
    let address = createIP(data: address!)
    print(address)

    let data = (Unmanaged<CFData>.fromOpaque(data!).takeUnretainedValue() as Data)
    let message = Message(unpack: data)

    // server
    print(message.header)
    for question in message.questions {
        print("  ? Question:   \(question)")
        if question.type == .pointer && question.name == hapPointer.name {
            DispatchQueue.main.async {
                broadcastService()
            }
        }
    }


    // browser
    var newPointers = Set<PointerRecord>()
    var newServices = Set<ServiceRecord>()
    for answer in message.answers {
        if let answer = answer as? ServiceRecord {
            newServices.insert(answer)
        }
        if let answer = answer as? PointerRecord {
            newPointers.insert(answer)
        }
        print("  ! Answer:     \(answer)")
    }
    for authority in message.authorities {
        print("  # Authority:  \(authority)")
    }
    for additional in message.additional {
        if let additional = additional as? ServiceRecord {
            newServices.insert(additional)
        }
        if let additional = additional as? PointerRecord {
            newPointers.insert(additional)
        }
        print("  … Additional: \(additional)")
    }


//    print("Added: ", newServices.subtract(services))
//    print("Added: ", newPointers.subtract(pointers))
    services = newServices.union(services) // overwrite ttl
    pointers = newPointers.union(pointers)
//    print("Services: ", services)
//    print("Pointers: ", pointers)
}, nil)

let source = CFSocketCreateRunLoopSource(nil, connection, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, CFRunLoopMode.defaultMode)


let timer = DispatchSource.makeTimerSource()
timer.scheduleRepeating(deadline: DispatchTime.now(), interval: 5)
timer.setEventHandler {
    print()
    print("Services:")
    for var service in services {
        if service.ttl > 1 {
            service.ttl -= 5
            services.update(with: service)
            print("  * \(service.name)   TTL: \(service.ttl)")
        } else {
            services.remove(service)
        }
    }
}
timer.resume()

broadcastService()

RunLoop.main.run()


