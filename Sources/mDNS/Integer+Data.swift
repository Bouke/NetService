import Foundation

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
