import Foundation

#if os(OSX)
    import Darwin
#else
    import Glibc
#endif

protocol SockAddr {
    var length: socklen_t { get }
}

extension SockAddr {

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

    mutating func withSockAddr<ReturnType>(_ body: (_ sa: UnsafeMutablePointer<sockaddr>, _ saLen: inout socklen_t) throws -> ReturnType) rethrows -> ReturnType {
        var saLen = length
        return try withUnsafeMutablePointer(to: &self) {
            try $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                try body($0, &saLen)
            }
        }
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

    mutating func withSockAddrType<AddrType, ReturnType>(_ body: (_ sax: inout AddrType) throws -> ReturnType) rethrows -> ReturnType {
        precondition(MemoryLayout<AddrType>.size <= MemoryLayout<sockaddr_storage>.size)
        // We need to create a mutable copy of `self` so that we can pass it to `withUnsafePointer(to:_:)`.
        return try withUnsafeMutablePointer(to: &self) {
            try $0.withMemoryRebound(to: AddrType.self, capacity: 1) {
                try body(&$0.pointee)
            }
        }
    }
}

extension sockaddr: SockAddr {
    var length: socklen_t {
        switch sa_family {
        case sa_family_t(PF_INET): return socklen_t(MemoryLayout<sockaddr_in>.size)
        case sa_family_t(PF_INET6): return socklen_t(MemoryLayout<sockaddr_in6>.size)
        default: fatalError("No length defined for family \(sa_family)")
        }
    }
    
    var port: UInt16 {
        mutating get {
            switch sa_family {
            case sa_family_t(AF_INET):
                return withSockAddrType { (src: inout sockaddr_in) in
                    src.sin_port.bigEndian
                }
            case sa_family_t(AF_INET6):
                return withSockAddrType { (src: inout sockaddr_in6) in
                    src.sin6_port.bigEndian
                }
            default:
                fatalError("No port defined for family \(sa_family)")
            }
        }
    }
}

extension sockaddr_in: SockAddr {
    var length: socklen_t {
        return socklen_t(MemoryLayout<sockaddr_in>.size)
    }
    
    var port: UInt16 {
        return sin_port.bigEndian
    }
}

extension sockaddr_in6: SockAddr {
    var length: socklen_t {
        return socklen_t(MemoryLayout<sockaddr_in6>.size)
    }

    var port: UInt16 {
        return sin6_port.bigEndian
    }
}
