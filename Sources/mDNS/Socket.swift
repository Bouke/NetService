//import Darwin
//
////gethostbyaddr(<#T##UnsafePointer<Void>!#>, <#T##socklen_t#>, <#T##Int32#>)
////
////connect(<#T##Int32#>, <#T##UnsafePointer<sockaddr>!#>, <#T##socklen_t#>)
//
//enum SocketError: ErrorProtocol {
//    case Error
//}
//
//class SocketAddress {
//    
//}
//
//class Socket {
//    var descriptor: Int32
//    
//    init() throws {
//        descriptor = socket(PF_INET, SOCK_STREAM, 0)
//        guard descriptor != -1 else { throw SocketError.Error }
//    }
//    
//    deinit {
////        connect(descriptor, <#T##UnsafePointer<sockaddr>!#>, <#T##socklen_t#>)
//    }
//
//    func connect(ip: String) {
//    }
//    
//    func read() {}
//    func write() {}
//}
