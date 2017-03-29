#if os(OSX)
    import Darwin
#else
    import Glibc
#endif

import Foundation
import Socket

enum Membership {
    case ipv4(ip_mreq)
    case ipv6(ipv6_mreq)
    
    init(address: in_addr) {
        self = .ipv4(ip_mreq(imr_multiaddr: address,
                             imr_interface: in_addr(s_addr: UInt32(bigEndian: INADDR_ANY))))
    }

    init?(address: Socket.Address) {
        switch address {
        case .ipv4(let sin):
            self = .ipv4(ip_mreq(imr_multiaddr: sin.sin_addr,
                                 imr_interface: in_addr(s_addr: UInt32(bigEndian: INADDR_ANY))))
        case .ipv6(let sin6):
            self = .ipv6(ipv6_mreq(ipv6mr_multiaddr: sin6.sin6_addr,
                                   ipv6mr_interface: 0))
        default: return nil
        }
    }
}

extension Socket {
    func join(membership: Membership) throws {
        switch membership {
        case .ipv4(var ip_mreq):
            #if os(OSX)
                try posix(setsockopt(socketfd, IPPROTO_IP, IP_ADD_MEMBERSHIP, &ip_mreq, socklen_t(MemoryLayout<ip_mreq>.size)))
            #else
                try posix(setsockopt(socketfd, Int32(IPPROTO_IP), Int32(IP_ADD_MEMBERSHIP), &ip_mreq, socklen_t(MemoryLayout<ip_mreq>.size)))
            #endif
        case .ipv6(var ipv6_mreq):
            #if os(OSX)
                try posix(setsockopt(socketfd, IPPROTO_IP, IPV6_JOIN_GROUP, &ipv6_mreq, socklen_t(MemoryLayout<ip_mreq>.size)))
            #else
                try posix(setsockopt(socketfd, Int32(IPPROTO_IP), Int32(IPV6_JOIN_GROUP), &ipv6_mreq, socklen_t(MemoryLayout<ip_mreq>.size)))
            #endif
        }
    }

    func leave(membership: Membership) throws {
        switch membership {
        case .ipv4(var ip_mreq):
            #if os(OSX)
                try posix(setsockopt(socketfd, IPPROTO_IP, IP_DROP_MEMBERSHIP, &ip_mreq, socklen_t(MemoryLayout<ip_mreq>.size)))
            #else
                try posix(setsockopt(socketfd, Int32(IPPROTO_IP), Int32(IP_DROP_MEMBERSHIP), &ip_mreq, socklen_t(MemoryLayout<ip_mreq>.size)))
            #endif
        case .ipv6(var ipv6_mreq):
            #if os(OSX)
                try posix(setsockopt(socketfd, IPPROTO_IP, IPV6_LEAVE_GROUP, &ipv6_mreq, socklen_t(MemoryLayout<ip_mreq>.size)))
            #else
                try posix(setsockopt(socketfd, Int32(IPPROTO_IP), Int32(IPV6_LEAVE_GROUP), &ipv6_mreq, socklen_t(MemoryLayout<ip_mreq>.size)))
            #endif
        }
    }
}

extension Socket.Address: CustomStringConvertible {
    init?(_ sa: inout sockaddr) {
        switch sa.sa_family {
        case sa_family_t(AF_INET):
            self = withUnsafePointer(to: &sa) {
                $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                    .ipv4($0.pointee)
                }
            }
        case sa_family_t(AF_INET6):
            self = withUnsafePointer(to: &sa) {
                $0.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
                    .ipv6($0.pointee)
                }
            }
        default: return nil
        }
    }

    init?(_ sa: UnsafeMutablePointer<sockaddr>) {
        switch sa.pointee.sa_family {
        case sa_family_t(AF_INET):
            self = sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                .ipv4($0.pointee)
            }
        case sa_family_t(AF_INET6):
            self = sa.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
                .ipv6($0.pointee)
            }
        default: return nil
        }
    }

    public var port: UInt16 {
        get {
            switch self {
            case .ipv4(let sin):
                return sin.sin_port.bigEndian
            case .ipv6(let sin6):
                return sin6.sin6_port.bigEndian
            default: abort()
            }
        }
        set {
            switch self {
            case .ipv4(var sin):
                sin.sin_port = newValue.bigEndian
                self = .ipv4(sin)
            case .ipv6(var sin6):
                sin6.sin6_port = newValue.bigEndian
                self = .ipv6(sin6)
            default: abort()
            }
        }
    }

    var presentation: String {
        var buffer = Data(count: Int(INET6_ADDRSTRLEN))
        switch self {
        case .ipv4(var sin):
            let ptr = buffer.withUnsafeMutableBytes {
                inet_ntop(AF_INET, &sin.sin_addr, $0, socklen_t(buffer.count))
            }
            return String(cString: ptr!)
        case .ipv6(var sin6):
            let ptr = buffer.withUnsafeMutableBytes {
                inet_ntop(AF_INET6, &sin6.sin6_addr, $0, socklen_t(buffer.count))
            }
            return String(cString: ptr!)
        default: abort()
        }
    }
    
    public var description: String {
        switch self {
        case .ipv4(_):
            return "\(presentation):\(port)"
        case .ipv6(_):
            return "[\(presentation)]:\(port)"
        default: abort()
        }
    }
}
