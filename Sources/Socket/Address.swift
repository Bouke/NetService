#if os(OSX)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif

import struct Foundation.Data

public enum Address: CustomDebugStringConvertible {
    case v4(sockaddr_in)
    case v6(sockaddr_in6)
    
    public init?(_ sa: inout sockaddr) {
        switch sa.sa_family {
        case sa_family_t(AF_INET):
            self = withUnsafePointer(to: &sa) {
                $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { Address.v4($0.pointee) }
            }
        case sa_family_t(AF_INET6):
            self = withUnsafePointer(to: &sa) {
                $0.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { Address.v6($0.pointee) }
            }
        default: return nil
        }
    }
    
    public init?(_ sa: UnsafeMutablePointer<sockaddr>) {
        switch sa.pointee.sa_family {
        case sa_family_t(AF_INET):
            self = sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                Address.v4($0.pointee)
            }
        case sa_family_t(AF_INET6):
            self = sa.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
                Address.v6($0.pointee)
            }
        default: return nil
        }
    }
    
    public var port: UInt16 {
        get {
            switch self {
            case .v4(let sin):
                return sin.sin_port.bigEndian
            case .v6(let sin6):
                return sin6.sin6_port.bigEndian
            }
        }
        set {
            switch self {
            case .v4(var sin):
                sin.sin_port = newValue.bigEndian
                self = .v4(sin)
            case .v6(var sin6):
                sin6.sin6_port = newValue.bigEndian
                self = .v6(sin6)
            }
        }
    }
    
    public var presentation: String {
        var buffer = Data(count: Int(INET6_ADDRSTRLEN))
        switch self {
        case .v4(var sin):
            let ptr = buffer.withUnsafeMutableBytes {
                inet_ntop(AF_INET, &sin.sin_addr, $0, socklen_t(buffer.count))
            }
            return String(cString: ptr!)
        case .v6(var sin6):
            let ptr = buffer.withUnsafeMutableBytes {
                inet_ntop(AF_INET6, &sin6.sin6_addr, $0, socklen_t(buffer.count))
            }
            return String(cString: ptr!)
        }
    }
    
    public var debugDescription: String {
        switch self {
        case .v4(_):
            return "\(presentation):\(port)"
        case .v6(_):
            return "[\(presentation)]:\(port)"
        }
    }
}
