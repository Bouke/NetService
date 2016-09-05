import Darwin
import Foundation

class MyDelegate: NSObject, StreamDelegate {
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch (aStream, eventCode) {
        case (let stream as InputStream, Stream.Event.hasBytesAvailable):
            var buffer = Data(count: 1024)
            buffer.count = buffer.withUnsafeMutableBytes {
                stream.read($0, maxLength: 1024)
            }
            print()
            buffer.dump()
//            print(Message(unpack: buffer))
        case (_, Stream.Event.errorOccurred):
            print(aStream.streamError)
            print("errorOccurred")
        case (_, Stream.Event.endEncountered):
            print("endOccurred")
        default:
            print(aStream, eventCode)
        }
    }
}

func ntohs(_ value: CUnsignedShort) -> CUnsignedShort {
    return (value << 8) + (value >> 8);
}
let htons = ntohs

let query = Message(header: Header(id: 0x1B, response: false, operationCode: .query, authoritativeAnswer: false, truncation: false, recursionDesired: true, recursionAvailable: false, returnCode: .NOERROR), questions: [Question(name: "apple.com", type: .text, internetClass: 1)], answers: [], authorities: [], additional: [])

let INADDR_ANY = in_addr(s_addr: 0)

//var my_addr = sockaddr_in()
//my_addr.sin_family = sa_family_t(AF_INET)
//my_addr.sin_addr.s_addr = INADDR_ANY.s_addr

//let host = "::1"
//let port = "53"

let socketfd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
precondition(socketfd != 0)
var yes: UInt32 = 1

// allow reuse
precondition(setsockopt(socketfd, SOL_SOCKET, SO_REUSEPORT, &yes, socklen_t(MemoryLayout<UInt32>.size)) == 0)

// setup socket using bsd calls. Then convert to Input/Output Stream and use run loops.

var addr2 = sockaddr_in()
addr2.sin_family = sa_family_t(AF_INET)
addr2.sin_port = htons(5353)
addr2.sin_addr = INADDR_ANY
//inet_pton(AF_INET, "10.0.1.1", &addr2.sin_addr)

let msg = query.pack()
let addr3 = withUnsafePointer(to: &addr2) {
    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        $0
    }
}

let (readStream, writeStream) = { () -> (InputStream, OutputStream) in
    var reads: Unmanaged<CFReadStream>? = nil
    var writes: Unmanaged<CFWriteStream>? = nil
    CFStreamCreatePairWithSocket(kCFAllocatorDefault, socketfd, &reads, &writes)
    return (reads!.takeRetainedValue() as InputStream, writes!.takeRetainedValue() as OutputStream)
}()

precondition(connect(socketfd, addr3, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0)
//precondition(bind(socketfd, addr3, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0)

// request kernel to join multicast group
var group_addr = in_addr()
precondition(inet_pton(AF_INET, "224.0.0.251", &group_addr) == 1)
var mreq = ip_mreq(imr_multiaddr: group_addr, imr_interface: INADDR_ANY)
precondition(setsockopt(socketfd, IPPROTO_IP, IP_ADD_MEMBERSHIP, &mreq, socklen_t(MemoryLayout<ip_mreq>.size)) == 0)

let myDelegate = MyDelegate()
readStream.open()
readStream.delegate = myDelegate
readStream.schedule(in: .main, forMode: .defaultRunLoopMode)

//writeStream.send

writeStream.open()
print("write", writeStream.write(msg, maxLength: msg.count))

withExtendedLifetime((myDelegate, readStream)) {
    RunLoop.main.run()
    print(myDelegate)
}

//var info = addrinfo()
//info.ai_protocol = IPPROTO_UDP
//var result: UnsafeMutablePointer<addrinfo>? = nil
//if(getaddrinfo(host, port, &info, &result) != 0) {
//    abort()
//}
//var res = result
//while res != nil {
//    if res?.pointee.ai_family == AF_INET {
//        var buffer = UnsafeMutablePointer<CChar>.allocate(capacity: Int(INET_ADDRSTRLEN))
//        var sa = res!.pointee.ai_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
//            return $0.pointee
//        }
//        if inet_ntop(res!.pointee.ai_family,
//                     &sa.sin_addr, buffer, UInt32(INET_ADDRSTRLEN)) != nil {
//            let ipAddress = String(validatingUTF8: buffer)
//            print("IPv4 \(ipAddress) for host \(host):\(port)")
//        }
//    } else if res!.pointee.ai_family == AF_INET6 {
//        var buffer = UnsafeMutablePointer<Int8>.allocate(capacity: Int(INET6_ADDRSTRLEN))
//        var sa = res!.pointee.ai_addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
//            return $0.pointee
//        }
//        if inet_ntop(res!.pointee.ai_family,
//                     &sa.sin6_addr, buffer, UInt32(INET6_ADDRSTRLEN)) != nil {
//            let ipAddress = String(validatingUTF8: buffer)
//            print("IPv6 \(ipAddress) for host \(host):\(port)")
//        }
//    }
//    res = res!.pointee.ai_next
//}
//
//freeaddrinfo(result)

//print(info)
//print(result?.pointee.ai_addr)

// tcp
//
//import Foundation
//
//var input: InputStream?
//var output: OutputStream?
//
//Stream.getStreamsToHost(withName: "10.0.1.1", port: 53, inputStream: &input, outputStream: &output)
//
//input!.open()
//output!.open()
//
//var writeBuffer = query.tcp()
//Data(bytes: query.tcp()).dump()
//assert(output!.write(&writeBuffer, maxLength: writeBuffer.count) == writeBuffer.count)
//
//usleep(30_000)
//while input!.hasBytesAvailable {
//    var readBuffer = Data(count: 1024)
//    readBuffer.count = readBuffer.withUnsafeMutableBytes { bytes in
//        input!.read(bytes, maxLength: readBuffer.count)
//    }
//    readBuffer.dump()
//    print(Message(unpack: readBuffer))
//}
