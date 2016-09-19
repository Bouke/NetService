import Darwin
import Foundation

public class UDPChannel {
    var received: ((_ address: SockAddr, _ data: Data, _ socket: CFSocket) -> ())?

    var socket4: CFSocket!
    var socket6: CFSocket!

    var runLoopSource4: CFRunLoopSource!
    var runLoopSource6: CFRunLoopSource!

    public func schedule(in aRunLoop: RunLoop, forMode mode: RunLoopMode) {
        CFRunLoopAddSource(aRunLoop.getCFRunLoop(), runLoopSource4, CFRunLoopMode(mode.rawValue as CFString))
        CFRunLoopAddSource(aRunLoop.getCFRunLoop(), runLoopSource6, CFRunLoopMode(mode.rawValue as CFString))
    }

    public func remove(from aRunLoop: RunLoop, forMode mode: RunLoopMode) {
        CFRunLoopRemoveSource(aRunLoop.getCFRunLoop(), runLoopSource4, CFRunLoopMode(mode.rawValue as CFString))
        CFRunLoopRemoveSource(aRunLoop.getCFRunLoop(), runLoopSource6, CFRunLoopMode(mode.rawValue as CFString))
    }

    init() throws {
        var yes: UInt32 = 1

        let fd4 = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd4 >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno)!)
        }

        var context = CFSocketContext()
        context.info = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        // allow reuse
        try posix(setsockopt(fd4, SOL_SOCKET, SO_REUSEPORT, &yes, socklen_t(MemoryLayout<UInt32>.size)))

        // bind to IPv4 interface
        let (_, ipv4) = sockaddr_storage.fromSockAddr { (sin: inout sockaddr_in) in
            sin.sin_family = sa_family_t(AF_INET)
            sin.sin_addr = in_addr(s_addr: UInt32(bigEndian: INADDR_ANY))
            sin.sin_port = (5353 as in_port_t).bigEndian
        }
        try ipv4.withSockAddr {
            try posix(bind(fd4, $0, $1))
        }

        // subscribe to IPv4 mDNS multicast
        var mreq4 = ip_mreq(imr_multiaddr: in_addr(s_addr: UInt32(bigEndian: INADDR_ALLMDNS_GROUP)),
                            imr_interface: in_addr(s_addr: UInt32(bigEndian: INADDR_ANY)))
        try posix(setsockopt(fd4, IPPROTO_IP, IP_ADD_MEMBERSHIP, &mreq4, socklen_t(MemoryLayout<ip_mreq>.size)))

        socket4 = CFSocketCreateWithNative(kCFAllocatorDefault, fd4, CFSocketCallBackType.dataCallBack.rawValue, { (socket, callbackType, address, data, info) in
            let address = UnsafeRawPointer(CFDataGetBytePtr(address!)!).bindMemory(to: sockaddr_in.self, capacity: 1).pointee
            let data = (Unmanaged<CFData>.fromOpaque(data!).takeUnretainedValue() as Data)
            let _self = Unmanaged<UDPChannel>.fromOpaque(info!).takeUnretainedValue()
            _self.received?(address, data, socket!)
        }, &context)

        runLoopSource4 = CFSocketCreateRunLoopSource(nil, socket4, 0)




        let fd6 = Darwin.socket(AF_INET6, SOCK_DGRAM, IPPROTO_UDP)
        guard fd6 >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno)!)
        }

        // allow reuse
        try posix(setsockopt(fd6, SOL_SOCKET, SO_REUSEPORT, &yes, socklen_t(MemoryLayout<UInt32>.size)))

        // bind to IPv6 interface
        let (_, ipv6) = sockaddr_storage.fromSockAddr { (sin: inout sockaddr_in6) in
            sin.sin6_family = sa_family_t(AF_INET6)
            sin.sin6_addr = in6addr_any
            sin.sin6_port = (5353 as in_port_t).bigEndian
        }
        try ipv6.withSockAddr {
            try posix(bind(fd6, $0, $1))
        }

        // subscribe to IPv6 mDNS multicast
        let group6 = IPv6("FF02::FB")!
        var mreq6 = ipv6_mreq(ipv6mr_multiaddr: group6.address, ipv6mr_interface: 1)
        try posix(setsockopt(fd6, IPPROTO_IPV6, IPV6_JOIN_GROUP, &mreq6, socklen_t(MemoryLayout<ipv6_mreq>.size)))

        socket6 = CFSocketCreateWithNative(kCFAllocatorDefault, fd6, CFSocketCallBackType.dataCallBack.rawValue, { (socket, callbackType, address, data, info) in
            let address = UnsafeRawPointer(CFDataGetBytePtr(address!)!).bindMemory(to: sockaddr_in6.self, capacity: 1).pointee
            let data = (Unmanaged<CFData>.fromOpaque(data!).takeUnretainedValue() as Data)
            let _self = Unmanaged<UDPChannel>.fromOpaque(info!).takeUnretainedValue()
            _self.received?(address, data, socket!)
        }, nil)

        runLoopSource6 = CFSocketCreateRunLoopSource(nil, socket6, 0)
    }

    internal func multicast(data: Data) {
        let (_, ipv4Group) = sockaddr_storage.fromSockAddr { (sin: inout sockaddr_in) in
            sin.sin_family = sa_family_t(AF_INET)
            sin.sin_addr = in_addr(s_addr: UInt32(bigEndian: INADDR_ALLMDNS_GROUP))
            sin.sin_port = (5353 as in_port_t).bigEndian
        }
        unicast(to: ipv4Group, data: data, socket: socket4)

        //todo send to ipv6 group as well
    }

    internal func unicast<AddrType>(to address: AddrType, data: Data, socket: CFSocket) where AddrType: SockAddr {
        address.withSockAddr { (sa, saLen) in
            sa.withMemoryRebound(to: UInt8.self, capacity: Int(saLen)) {
                let address = CFDataCreateWithBytesNoCopy(nil, $0, Int(saLen), kCFAllocatorNull)
                precondition(CFSocketSendData(socket, address, data as CFData!, 2) == .success)
            }
        }
    }
}

protocol SockAddr { }

extension SockAddr {
    mutating func withMutableSockAddr<ReturnType>(_ body: (_ sa: UnsafeMutablePointer<sockaddr>, _ saLen: inout socklen_t) throws -> ReturnType) rethrows -> ReturnType {
        // We need to create a mutable copy of `self` so that we can pass it to `withUnsafePointer(to:_:)`.
        var saLen = socklen_t(MemoryLayout<sockaddr>.size)
        return try withUnsafeMutablePointer(to: &self) {
            try $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                try body($0, &saLen)
            }
        }
    }

    func withSockAddr<ReturnType>(_ body: (_ sa: UnsafePointer<sockaddr>, _ saLen: socklen_t) throws -> ReturnType) rethrows -> ReturnType {
        // We need to create a mutable copy of `self` so that we can pass it to `withUnsafePointer(to:_:)`.
        var ss = self
        return try withUnsafePointer(to: &ss) {
            try $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                try body($0, socklen_t(MemoryLayout<sockaddr>.size))
            }
        }
    }

    func withSockAddrType<AddrType, ReturnType>(_ body: (_ sax: inout AddrType) throws -> ReturnType) rethrows -> ReturnType {
        precondition(MemoryLayout<AddrType>.size <= MemoryLayout<sockaddr_storage>.size)
        // We need to create a mutable copy of `self` so that we can pass it to `withUnsafePointer(to:_:)`.
        var ss = self
        return try withUnsafeMutablePointer(to: &ss) {
            try $0.withMemoryRebound(to: AddrType.self, capacity: 1) {
                try body(&$0.pointee)
            }
        }
    }

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

extension sockaddr_storage: SockAddr, CustomDebugStringConvertible {
    init?(fromSockAddr sock: sockaddr) {
        switch sock.sa_family {
        case sa_family_t(AF_INET):
            self = sock.withSockAddrType { (src: inout sockaddr_in) in
                sockaddr_storage.fromSockAddr { (dst: inout sockaddr_in) in
                    dst.sin_family = src.sin_family
                    dst.sin_addr = src.sin_addr
                }.1
            }
        case sa_family_t(AF_INET6):
            self = sock.withSockAddrType { (src: inout sockaddr_in6) in
                sockaddr_storage.fromSockAddr { (dst: inout sockaddr_in6) in
                    dst.sin6_family = src.sin6_family
                    dst.sin6_addr = src.sin6_addr
                }.1
            }
        default: return nil
        }
    }

    var port: UInt16? {
        switch ss_family {
        case sa_family_t(AF_INET):
            return withSockAddrType { (src: inout sockaddr_in) in
                src.sin_port.bigEndian
            }
        case sa_family_t(AF_INET6):
            return withSockAddrType { (src: inout sockaddr_in6) in
                src.sin6_port.bigEndian
            }
        default:
            return nil
        }
    }
}

extension sockaddr: SockAddr, CustomDebugStringConvertible { }
extension sockaddr_in: SockAddr, CustomDebugStringConvertible { }
extension sockaddr_in6: SockAddr, CustomDebugStringConvertible { }
