import Foundation
func posix(_ block: @autoclosure () -> Int32) throws {
    guard block() == 0 else {
        throw POSIXError(POSIXErrorCode(rawValue: errno)!)
    }
}
