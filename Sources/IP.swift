import Foundation


protocol IP {
    init(_ address: Data)
}

struct IPv4: IP {
    let address: UInt32

    init(_ address: Data) {
        self.address = UInt32(bytes: address)
    }
}

extension IPv4: CustomDebugStringConvertible {
    var debugDescription: String {
        return "\(address >> 24 & 0xff).\(address >> 16 & 0xff).\(address >> 8 & 0xff).\(address & 0xff)"
    }
}


struct IPv6: IP {
    let address: Data

    init(_ address: Data) {
        self.address = address
    }
}

extension IPv6: CustomDebugStringConvertible {
    var debugDescription: String {
        return (0..<8)
            .map { address[$0*2..<$0*2+2].hex }
            .joined(separator: ":")
    }
}
