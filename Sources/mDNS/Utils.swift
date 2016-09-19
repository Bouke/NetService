import Foundation
import Cifaddrs

func posix(_ block: @autoclosure () -> Int32) throws {
    guard block() == 0 else {
        throw POSIXError(POSIXErrorCode(rawValue: errno)!)
    }
}

func getifaddrs() -> AnySequence<UnsafeMutablePointer<ifaddrs>> {
    var addrs: UnsafeMutablePointer<ifaddrs>?
    try! posix(getifaddrs(&addrs))
    guard let first = addrs else { return AnySequence([]) }
    return AnySequence(sequence(first: first, next: { $0.pointee.ifa_next }))
}

func gethostname() throws -> String {
    var output = Data(count: 255)
    return try output.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<CChar>) -> String in
        try posix(gethostname(bytes, 255))
        return String(cString: bytes)
    }
}

