import Darwin
import Foundation

/// object wrapping traffic from/to port 5353
fileprivate var sharedInstance = try! Responder()

public class Responder {
    public static let shared: Responder = sharedInstance

    var socket: CFSocket

    var runLoopSource: CFRunLoopSource
    public func start() {
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, CFRunLoopMode.defaultMode)
    }

    func stop() {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, CFRunLoopMode.defaultMode)
    }


    fileprivate init() throws {
        let fd = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno)!)
        }

        // allow reuse
        var yes: UInt32 = 1
        try posix(setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &yes, socklen_t(MemoryLayout<UInt32>.size)))

        // bind to all ipv4 interfaces
        var ipv4 = sockaddr_in()
        ipv4.sin_family = sa_family_t(AF_INET)
        ipv4.sin_addr = in_addr(s_addr: UInt32(bigEndian: INADDR_ANY))
        ipv4.sin_port = UInt16(bigEndian: 5353)
        try ipv4.withSockAddr {
            try posix(bind(fd, $0, $1))
        }

        // subscribe to mDNS multicast
        var mreq = ip_mreq(imr_multiaddr: in_addr(s_addr: UInt32(bigEndian: INADDR_ALLMDNS_GROUP)),
                           imr_interface: in_addr(s_addr: UInt32(bigEndian: INADDR_ANY)))
        try posix(setsockopt(fd, IPPROTO_IP, IP_ADD_MEMBERSHIP, &mreq, socklen_t(MemoryLayout<ip_mreq>.size)))

        socket = CFSocketCreateWithNative(kCFAllocatorDefault, fd, CFSocketCallBackType.dataCallBack.rawValue, { (socket, callbackType, addressData, data, info) in

            let address: sockaddr_storage
            let family = CFDataGetBytePtr(addressData!).withMemoryRebound(to: sockaddr.self, capacity: 1) {
                return $0.pointee.sa_family
            }
            switch family {
            case sa_family_t(AF_INET):
                (_, address) = sockaddr_storage.fromSockAddr { (sin: inout sockaddr_in) in
                    sin.sin_family = sa_family_t(AF_INET)
                    sin.sin_addr = CFDataGetBytePtr(addressData!).withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                        $0.pointee.sin_addr
                    }
                }
            case sa_family_t(AF_INET6):
                (_, address) = sockaddr_storage.fromSockAddr { (sin: inout sockaddr_in6) in
                    sin.sin6_family = sa_family_t(AF_INET6)
                    sin.sin6_addr = CFDataGetBytePtr(addressData!).withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
                        $0.pointee.sin6_addr
                    }
                }
            default:
                return
            }
        }, nil)

        runLoopSource = CFSocketCreateRunLoopSource(nil, socket, 0)
    }
}

extension sockaddr_storage: CustomDebugStringConvertible {
    public var debugDescription: String {
        return withSockAddr { (sa, saLen) in
            var name = Data(count: Int(NI_MAXHOST))
            name.withUnsafeMutableBytes {
                try! posix(getnameinfo(sa, saLen, $0, socklen_t(NI_MAXHOST), nil, 0, NI_NUMERICHOST))
            }
            return String(data: name, encoding: .ascii)!
        }
    }
}

extension sockaddr_in {
    func withSockAddr<ReturnType>(_ body: (_ sa: UnsafePointer<sockaddr>, _ saLen: socklen_t) throws -> ReturnType) rethrows -> ReturnType {
        // We need to create a mutable copy of `self` so that we can pass it to `withUnsafePointer(to:_:)`.
        var ss = self
        return try withUnsafePointer(to: &ss) {
            try $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                try body($0, socklen_t(MemoryLayout<sockaddr>.size))
            }
        }
    }
}
