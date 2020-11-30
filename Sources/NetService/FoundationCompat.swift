import CoreFoundation

#if !os(Linux) || compiler(>=5.3)
internal let kCFSocketReadCallBack = CFSocketCallBackType.readCallBack.rawValue
#endif

#if os(Linux) && !compiler(>=5.0)
import class Foundation.RunLoop
import struct Foundation.RunLoopMode

extension RunLoop {
    public typealias Mode = RunLoopMode
}

extension RunLoopMode {
    static var `default`: RunLoopMode {
        return RunLoopMode.defaultRunLoopMode
    }
}
#endif

#if os(Linux)
extension CFRunLoopMode {
    static var commonModes: CFRunLoopMode {
        return kCFRunLoopCommonModes
    }
}
#endif
