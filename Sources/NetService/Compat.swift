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

    extension CFReadStream {
        func bridge() -> InputStream {
            return self as InputStream
        }
    }

    extension CFWriteStream {
        func bridge() -> OutputStream {
            return self as OutputStream
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

    extension CFReadStream {
        func bridge() -> InputStream {
            return InputStream(stream: self)
        }
    }

    extension CFWriteStream {
        func bridge() -> OutputStream {
            return OutputStream(stream: self)
        }
    }

    // InputStream is an abstract class representing the base functionality of a read stream.
    // Subclassers are required to implement these methods.
    open class InputStream: Stream {

        private var _stream: CFReadStream!

        // reads up to length bytes into the supplied buffer, which must be at least of size len. Returns the actual number of bytes read.
        open func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
            return CFReadStreamRead(_stream, buffer, CFIndex(len._bridgeToObjectiveC()))
        }

        // returns in O(1) a pointer to the buffer in 'buffer' and by reference in 'len' how many bytes are available. This buffer is only valid until the next stream operation. Subclassers may return NO for this if it is not appropriate for the stream type. This may return NO if the buffer is not available.
        open func getBuffer(_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, length len: UnsafeMutablePointer<Int>) -> Bool {
            abort()
        }

        // returns YES if the stream has bytes available or if it impossible to tell without actually doing the read.
        open var hasBytesAvailable: Bool {
            return CFReadStreamHasBytesAvailable(_stream)
        }

        init(stream: CFReadStream) {
            _stream = stream
        }

        open override func open() {
            CFReadStreamOpen(_stream)
        }

        open override func close() {
            CFReadStreamClose(_stream)
        }

        open override var streamStatus: Status {
            return Stream.Status(rawValue: UInt(CFReadStreamGetStatus(_stream)))!
        }
    }

    // OutputStream is an abstract class representing the base functionality of a write stream.
    // Subclassers are required to implement these methods.
    // Currently this is left as named OutputStream due to conflicts with the standard library's text streaming target protocol named OutputStream (which ideally should be renamed)
    open class OutputStream : Stream {

        private  var _stream: CFWriteStream!

        // writes the bytes from the specified buffer to the stream up to len bytes. Returns the number of bytes actually written.
        open func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
            return  CFWriteStreamWrite(_stream, buffer, len)
        }

        // returns YES if the stream can be written to or if it is impossible to tell without actually doing the write.
        open var hasSpaceAvailable: Bool {
            return CFWriteStreamCanAcceptBytes(_stream)
        }

        init(stream: CFWriteStream) {
            _stream = stream
        }

        open override func open() {
            CFWriteStreamOpen(_stream)
        }

        open override func close() {
            CFWriteStreamClose(_stream)
        }

        open override var streamStatus: Status {
            return Stream.Status(rawValue: UInt(CFWriteStreamGetStatus(_stream)))!
        }

        open class func outputStreamToMemory() -> Self {
            abort()
        }

        open override func property(forKey key: PropertyKey) -> AnyObject? {
            abort()
        }

        open  override func setProperty(_ property: AnyObject?, forKey key: PropertyKey) -> Bool {
            abort()
        }
    }
#endif
