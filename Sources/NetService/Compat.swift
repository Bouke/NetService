import Foundation

extension Data {
    func bridge() -> CFData {
        return withUnsafeBytes {
            CFDataCreate(nil, $0, count)
        }
    }
}

extension CFData {
    func bridge() -> Data {
        return Data(bytes: CFDataGetBytePtr(self), count: CFDataGetLength(self))
    }
}

#if os(OSX)
    // needed on OS X 10.11 El Capitan
    @objc
    class TimerTarget: NSObject {
        var block: ((Timer) -> Void)

        init(block: @escaping ((Timer) -> Void)) {
            self.block = block
        }

        @objc
        func fire(_ timer: Timer) {
            block(timer)
        }
    }

    extension Timer {
        public convenience init(fire date: Date, interval: TimeInterval, repeats: Bool, block: @escaping (Timer) -> Swift.Void) {
            let target = TimerTarget(block: block)
            self.init(fireAt: date, interval: interval, target: target, selector: #selector(TimerTarget.fire(_:)), userInfo: nil, repeats: repeats)
        }

        public convenience init(timeInterval interval: TimeInterval, repeats: Bool, block: @escaping (Timer) -> Swift.Void) {
            let target = TimerTarget(block: block)
            self.init(timeInterval: interval, target: target, selector: #selector(TimerTarget.fire), userInfo: nil, repeats: repeats)
        }

        class func _scheduledTimer(withTimeInterval interval: TimeInterval, repeats: Bool, block: @escaping (Timer) -> Swift.Void) -> Timer {
            let target = TimerTarget(block: block)
            return scheduledTimer(timeInterval: interval, target: target, selector: #selector(TimerTarget.fire), userInfo: nil, repeats: repeats)
        }
    }
#else
    import CoreFoundation

    // shadow method
    extension Timer {
        class func _scheduledTimer(withTimeInterval interval: TimeInterval, repeats: Bool, block: @escaping (Timer) -> Swift.Void) -> Timer {
            return scheduledTimer(withTimeInterval: interval, repeats: repeats, block: block)
        }
    }

    public struct CFRunLoopMode : RawRepresentable {
        public var rawValue: CFString

        public init(rawValue: CFString) {
            self.rawValue = rawValue
        }

        public init(_ rawValue: CFString) {
            self.rawValue = rawValue
        }

        public static let defaultMode = CFRunLoopMode(kCFRunLoopDefaultMode)
        public static let commonModes = CFRunLoopMode(kCFRunLoopCommonModes)
    }

    public func CFRunLoopAddSource(_ rl: CFRunLoop, _ source: CFRunLoopSource, _ mode: CFRunLoopMode) {
        CFRunLoopAddSource(rl, source, mode.rawValue)
    }

    public func CFRunLoopRemoveSource(_ rl: CFRunLoop, _ source: CFRunLoopSource, _ mode: CFRunLoopMode) {
        CFRunLoopRemoveSource(rl, source, mode.rawValue)
    }

    extension POSIXError {
        init(code: POSIXError.Code) {
            _nsError = NSError(domain: NSPOSIXErrorDomain, code: code.rawValue, userInfo: nil)
        }
    }
#endif
