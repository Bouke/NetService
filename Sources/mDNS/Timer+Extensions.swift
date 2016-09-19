import Foundation

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
