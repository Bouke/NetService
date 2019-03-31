#if os(Linux) && swift(<5.0)
extension RunLoop.Mode {
    var `default`: RunLoop.Mode {
        get {
            return RunLoop.Mode.defaultRunLoopMode
        }
    }
}
#endif
