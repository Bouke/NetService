import Darwin

func ntohs(_ value: CUnsignedShort) -> CUnsignedShort {
    return (value << 8) + (value >> 8);
}
let htons = ntohs

let query = Message(header: Header(id: 0x1B, response: false, operationCode: .query, authoritativeAnswer: false, truncation: false, recursionDesired: true, recursionAvailable: false, returnCode: .NOERROR), questions: [Question(name: "apple.com", type: .nameServer, internetClass: 1)], answers: [], authorities: [], additional: [])

let INADDR_ANY = in_addr(s_addr: 0)

//var my_addr = sockaddr_in()
//my_addr.sin_family = sa_family_t(AF_INET)
//my_addr.sin_addr.s_addr = INADDR_ANY.s_addr

let destination = "10.0.1.1"

let socketfd = socket(AF_INET, SOCK_DGRAM, 0)
if(socketfd == 0) {
    abort()
}

var dest_addr = sockaddr_in()
dest_addr.sin_family = sa_family_t(AF_INET)
dest_addr.sin_port = htons(53)
dest_addr.sin_addr.s_addr = destination.withCString { inet_addr($0) }

import Foundation

//var data = Data(try encodeName("apple.com"))
//var position = data.startIndex
//print(decodeName(data, position: &position))
//print(position)

// try 2

//var info = addrinfo()
//getaddrinfo(0, "5353", <#T##UnsafePointer<addrinfo>!#>, <#T##UnsafeMutablePointer<UnsafeMutablePointer<addrinfo>?>!#>)




//query.pack().withUnsafeBufferPointer { p1 in
//    sendto(socketfd, p1.baseAddress, p1.endIndex, 0, UnsafePointer(&dest_addr), socklen_t(sizeof(sockaddr_in)))
//}


//let port = atoi

//print(query.pack())

//let socket = ActiveSocketIPv4()!
//
//socket.connect(address: "localhost:1337") {
//    $0.write("Ring, ring!\r\n")
//}

//print(socket.read())
//print(socket.read())

import Foundation

var input: InputStream?
var output: OutputStream?

Stream.getStreamsToHost(withName: "10.0.1.1", port: 53, inputStream: &input, outputStream: &output)
//
input!.open()
output!.open()
//
////input.÷
//
//
//
////[0000]   00 24 82 F1 01 00 00 01   00 00 00 00 00 00 0E 67   .$...... .......g
////[0010]   6F 6F 6F 6F 6F 6F 6F 6F   6F 6F 67 6C 65 03 63 6F   oooooooo oogle.co
////[0020]   6D 00 00 01 00 01                                   m.....
//
////var writeBuffer = Array("Hello\n".utf8)
var writeBuffer = query.tcp()
Data(bytes: query.tcp()).dump()
assert(output!.write(&writeBuffer, maxLength: writeBuffer.count) == writeBuffer.count)
////
////print(query.tcp())
////
////
//sleep(1)
usleep(20_000)
while input!.hasBytesAvailable {
    var readBuffer = Data(count: 1024)
    readBuffer.count = readBuffer.withUnsafeMutableBytes { bytes in
        input!.read(bytes, maxLength: readBuffer.count)
    }
    readBuffer.dump()
    print(Message(unpack: readBuffer))
}
