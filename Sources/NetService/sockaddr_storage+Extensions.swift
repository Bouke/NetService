import Foundation

#if os(OSX)
    import Darwin
#else
    import Glibc
#endif

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
            return name.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<CChar>) -> String in
                try! posix(getnameinfo(sa, saLen, bytes, socklen_t(NI_MAXHOST), nil, 0, NI_NUMERICHOST))
                return String(cString: bytes)
            }
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


extension sockaddr_storage {

    /// Calls a closure with traditional BSD Sockets address parameters.
    ///
    /// This is used to call BSD Sockets routines like `connect`, which accept their
    /// address as an `sa` and `saLen` pair.  For example:
    ///
    ///     let ss: sockaddr_storage = …
    ///     let connectResult = ss.withSockAddr { (sa, saLen) in
    ///         connect(fd, sa, saLen)
    ///     }
    ///
    /// - parameter body: A closure to call with `self` referenced appropriately for calling
    ///   BSD Sockets APIs that take an address.
    ///
    /// - throws: Any error thrown by `body`.
    ///
    /// - returns: Any result returned by `body`.

    func withSockAddr<ReturnType>(_ body: (_ sa: UnsafePointer<sockaddr>, _ saLen: socklen_t) throws -> ReturnType) rethrows -> ReturnType {
        // We need to create a mutable copy of `self` so that we can pass it to `withUnsafePointer(to:_:)`.
        var ss = self
        let ss_len = self.ss_family == sa_family_t(PF_INET) ? MemoryLayout<sockaddr_in>.size : MemoryLayout<sockaddr_in6>.size
        return try withUnsafePointer(to: &ss) {
            try $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                try body($0, socklen_t(ss_len))
            }
        }
    }

    /// Calls a closure such that it can return an address based on traditional BSD Sockets parameters.
    ///
    /// This is used to call BSD Sockets routines like `accept`, which return a value (the file
    /// descriptor) and an address via memory pointed to by `sa` and `saLen` parameters.  For example:
    ///
    ///     let (acceptResult, peerAddr) = sockaddr_storage.fromSockAddr { (_ sa: UnsafeMutablePointer<sockaddr>, _ saLen: inout socklen_t) in
    ///         return accept(fd, sa, &saLen)
    ///     }
    ///
    /// - parameter body: A closure to call with parameters appropriate for calling BSD Sockets APIs
    ///   that return an address.
    ///
    /// - throws: Any error thrown by `body`.
    ///
    /// - returns: A tuple consistent of the result returned by `body` and an address set up by
    ///   `body` via its `sa` and `saLen` parameters.

    static func fromSockAddr<ReturnType>(_ body: (_ sa: UnsafeMutablePointer<sockaddr>, _ saLen: inout socklen_t) throws -> ReturnType) rethrows -> (ReturnType, sockaddr_storage) {
        // We need a mutable `sockaddr_storage` so that we can pass it to `withUnsafePointer(to:_:)`.
        var ss = sockaddr_storage()
        // Similarly, we need a mutable copy of our length for the benefit of `saLen`.
        var saLen = socklen_t(MemoryLayout<sockaddr_storage>.size)
        let result = try withUnsafeMutablePointer(to: &ss) {
            try $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                try body($0, &saLen)
            }
        }
        return (result, ss)
    }

    /// Calls a closure with an address parameter of a user-specified type.
    ///
    /// This makes it easy to access the fields of an address as the appropriate type.  For example:
    ///
    ///     let sin: sockaddr_storage = … initialise with an AF_INET address …
    ///     sin.withSockAddrType { (sin: inout sockaddr_in) in
    ///         print(sin.sin_len)
    ///         print(UInt16(bigEndian: sin.sin_port))
    ///     }
    ///
    /// In this case the closure returns void, but there may be other circumstances where it's useful
    /// to have a return type.
    ///
    /// - note: `body` takes an inout parameter for the sake of folks who need to take
    ///   a pointer to elements of that parameter.  We ignore any changes that the `body`
    ///   might make to this value.  Without this affordance, the following code would not
    ///   work:
    ///
    ///         let sus: sockaddr_storage = … initialise with an AF_UNIX address …
    ///         sus.withSockAddrType { (sun: inout sockaddr_un) in
    ///             print(sun.sun_len)
    ///             print(String(cString: &sun.sun_path.0))
    ///         }
    ///
    /// - parameter body: A closure to call with `self` referenced via an arbitrary type.
    ///   Careful with that axe, Eugene.
    ///
    /// - throws: Any error thrown by `body`.
    ///
    /// - returns: Any result returned by `body`.
    ///
    /// - precondition: `AddrType` must not be larger than `sockaddr_storage`.

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

    /// Calls a closure such that it can return an address via a user-specified type.
    ///
    /// This is useful if you want to create an address from a specific sockaddr_xxx
    /// type that you initialise piecemeal.  For example:
    ///
    ///     let (_, sin) = sockaddr_storage.fromSockAddr { (sin: inout sockaddr_in) in
    ///         sin.sin_family = sa_family_t(AF_INET)
    ///         sin.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    ///         sin.sin_port = (12345 as in_port_t).bigEndian
    ///     }
    ///
    /// In this case the closure returns void, but there may be other circumstances where it's useful
    /// to have a return type.
    ///
    /// - parameter body: A closure to call with parameters appropriate for returning an address.
    ///
    /// - throws: Any error thrown by `body`.
    ///
    /// - returns: A tuple consistent of the result returned by `body` and an address set
    ///   up by `body` via the `sax` inout parameter.
    ///
    /// - precondition: `AddrType` must not be larger than `sockaddr_storage`.

    static func fromSockAddr<AddrType, ReturnType>(_ body: (_ sax: inout AddrType) throws -> ReturnType) rethrows -> (ReturnType, sockaddr_storage) {
        precondition(MemoryLayout<AddrType>.size <= MemoryLayout<sockaddr_storage>.size)
        // We need a mutable `sockaddr_storage` so that we can pass it to `withUnsafePointer(to:_:)`.
        var ss = sockaddr_storage()
        ss.ss_len = __uint8_t(MemoryLayout<AddrType>.size)
        let result = try withUnsafeMutablePointer(to: &ss) {
            try $0.withMemoryRebound(to: AddrType.self, capacity: 1) {
                try body(&$0.pointee)
            }
        }
        return (result, ss)
    }
}
