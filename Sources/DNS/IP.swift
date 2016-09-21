import Foundation

// TODO: replace by sockaddr_storage


/// Undefined for LE
func htonl(_ value: UInt32) -> UInt32 {
    return value.byteSwapped
}
let ntohl = htonl

public protocol IP: CustomDebugStringConvertible {
    init?(networkBytes: Data)
    init?(_ presentation: String)
    var presentation: String { get }

    /// network-byte-order bytes
    var bytes: Data { get }
}

extension IP {
    public var debugDescription: String {
        return presentation
    }
}

public func createIP<C: Collection>(networkBytes bytes: C) -> IP? where C.Iterator.Element == UInt8 {
    switch bytes.count {
    case 4: return IPv4(networkBytes: Data(bytes))
    case 16: return IPv6(networkBytes: Data(bytes))
    default: return nil
    }
}

public struct IPv4: IP {
    /// IPv4 address in network-byte-order
    public let address: in_addr

    public init(address: in_addr) {
        self.address = address
    }

    public init?(_ presentation: String) {
        var address = in_addr()
        guard inet_pton(AF_INET, presentation, &address) == 1 else {
            return nil
        }
        self.address = address
    }

    /// network order
    public init?(networkBytes bytes: Data) {
        guard bytes.count == MemoryLayout<UInt32>.size else {
            return nil
        }
        self.address = in_addr(s_addr: UInt32(bytes: bytes.reversed()))
    }

    /// host order
    public init(_ address: UInt32) {
        self.address = in_addr(s_addr: htonl(address))
    }

    public var presentation: String {
        var output = Data(count: Int(INET_ADDRSTRLEN))
        var address = self.address
        guard let p = output.withUnsafeMutableBytes({
            inet_ntop(AF_INET, &address, $0, socklen_t(INET_ADDRSTRLEN))
        }) else {
            return "Invalid IPv4 address"
        }
        return String(cString: p)
    }

    public var bytes: Data {
        return htonl(address.s_addr).bytes
    }
}

extension IPv4: Equatable, Hashable {
    public static func == (lhs: IPv4, rhs: IPv4) -> Bool {
        return lhs.address.s_addr == rhs.address.s_addr
    }

    public var hashValue: Int {
        return Int(address.s_addr)
    }
}

extension IPv4: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: UInt32) {
        self.init(value)
    }
}


public struct IPv6: IP {
    public let address: in6_addr

    public init(address: in6_addr) {
        self.address = address
    }

    public init?(_ presentation: String) {
        var address = in6_addr()
        guard inet_pton(AF_INET6, presentation, &address) == 1 else {
            return nil
        }
        self.address = address
    }

    public init?(networkBytes bytes: Data) {
        guard bytes.count == MemoryLayout<in6_addr>.size else {
            return nil
        }
        address = bytes.withUnsafeBytes { (p1: UnsafePointer<UInt8>) -> in6_addr in
            p1.withMemoryRebound(to: in6_addr.self, capacity: 1) { $0.pointee }
        }
    }

    public var presentation: String {
        var output = Data(count: Int(INET6_ADDRSTRLEN))
        var address = self.address
        guard let p = output.withUnsafeMutableBytes({
            inet_ntop(AF_INET6, &address, $0, socklen_t(INET6_ADDRSTRLEN))
        }) else {
            return "Invalid IPv6 address"
        }
        return String(cString: p)
    }

    public var bytes: Data {
        #if os(OSX)
            return
                htonl(address.__u6_addr.__u6_addr32.0).bytes +
                htonl(address.__u6_addr.__u6_addr32.1).bytes +
                htonl(address.__u6_addr.__u6_addr32.2).bytes +
                htonl(address.__u6_addr.__u6_addr32.3).bytes
        #else
            return
                htonl(address.__in6_u.__u6_addr32.0).bytes +
                htonl(address.__in6_u.__u6_addr32.1).bytes +
                htonl(address.__in6_u.__u6_addr32.2).bytes +
                htonl(address.__in6_u.__u6_addr32.3).bytes
        #endif
    }
}

extension IPv6: Equatable, Hashable {
    public static func == (lhs: IPv6, rhs: IPv6) -> Bool {
        return lhs.presentation == rhs.presentation
    }

    public var hashValue: Int {
        return presentation.hashValue
    }
}
