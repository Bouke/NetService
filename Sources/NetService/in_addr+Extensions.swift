import Foundation

/// Undefined for LE
func htonl(_ value: UInt32) -> UInt32 {
    return value.byteSwapped
}
let ntohl = htonl

extension Integer {
    init(bytes: [UInt8]) {
        precondition(bytes.count == MemoryLayout<Self>.size, "incorrect number of bytes")
        self = bytes.reversed().withUnsafeBufferPointer() {
            $0.baseAddress!.withMemoryRebound(to: Self.self, capacity: 1) {
                return $0.pointee
            }
        }
    }
    
    init<S: Sequence>(bytes: S) where S.Iterator.Element == UInt8 {
        self.init(bytes: Array(bytes))
    }
}

extension UnsignedInteger {
    // returns little endian; use .bigEndian.bytes for BE.
    var bytes: Data {
        var copy = self
        return withUnsafePointer(to: &copy) {
            Data(Data(bytes: $0, count: MemoryLayout<Self>.size).reversed())
        }
    }
}

extension in_addr: CustomStringConvertible {
    public init?(_ presentation: String) {
        var target = in_addr()
        guard inet_pton(AF_INET, presentation, &target) == 1 else {
            return nil
        }
        self = target
    }
    
    /// network order
    public init?(networkBytes bytes: Data) {
        guard bytes.count == MemoryLayout<UInt32>.size else {
            return nil
        }
        self = in_addr(s_addr: UInt32(bytes: bytes.reversed()))
    }
    
    /// host order
    public init(_ address: UInt32) {
        self = in_addr(s_addr: htonl(address))
    }
    
    public var description: String {
        var output = Data(count: Int(INET_ADDRSTRLEN))
        var copy = self
        guard let p = output.withUnsafeMutableBytes({
            inet_ntop(AF_INET, &copy, $0, socklen_t(INET_ADDRSTRLEN))
        }) else {
            return "Invalid IPv4 address"
        }
        return String(cString: p)
    }
}
