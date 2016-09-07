import Darwin
import Foundation

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

let query = Message(header: Header(id: 0, response: false, operationCode: .query, authoritativeAnswer: false, truncation: false, recursionDesired: false, recursionAvailable: false, returnCode: .NOERROR),
                    questions: [Question(name: "_ssh._tcp.local", type: .reverseLookup, unique: false, internetClass: 1)],
                    answers: [],
                    authorities: [],
                    additional: [])

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

let msg = query.pack()
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

struct Service {
    let name: String
    var port: UInt16
    var hostname: String
    var ttl: UInt32
}

// @todo refactor IPvX into single generic IP struct
enum IP {
    case v4(IPv4)
    case v6(IPv6)
}

// @todo use CFSocketCreate instead (for creating the CFSocket)
//CFSocketCallBack
let connection = CFSocketCreateWithNative(kCFAllocatorDefault, socketfd, CFSocketCallBackType.dataCallBack.rawValue, { (s, callbackType, address, data, info) in
    let data = (Unmanaged<CFData>.fromOpaque(data!).takeUnretainedValue() as Data)
    let message = Message(unpack: data)
    print(message.header)
    for question in message.questions {
        print("  ? Question:   \(question)")
    }
    var newServices = [String: Service]()
    for answer in message.answers {
        if case .reverseLookup(let name) = answer.data {
            newServices[name] = Service(name: name, port: 0, hostname: "", ttl: answer.ttl)
        }
        print("  ! Answer:     \(answer)")
    }
    for authority in message.authorities {
        print("  # Authority:  \(authority)")
    }
    for additional in message.additional {
        if case .service(_, _, let port, let hostname) = additional.data {
            newServices[additional.name]!.port = port
            newServices[additional.name]!.hostname = hostname
        }
        print("  … Additional: \(additional)")
    }

    print(newServices)
    print()
}, nil)

let source = CFSocketCreateRunLoopSource(nil, connection, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, CFRunLoopMode.defaultMode)

var dest = sockaddr_in()
dest.sin_family = sa_family_t(AF_INET)
dest.sin_addr = group_addr
dest.sin_port = htons(5353)

let dest2 = withUnsafePointer(to: &dest) {
    $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<sockaddr_in>.size) {
        CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, $0, MemoryLayout<sockaddr_in>.size, kCFAllocatorDefault)
    }
}
let msg2 = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, msg, msg.count, kCFAllocatorDefault)

precondition(CFSocketSendData(connection, dest2, msg2, 2) == .success)

CFRunLoopRun()
