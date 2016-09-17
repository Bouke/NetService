import Foundation

// doesn't work, hangs on line 23 :'(


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
    public convenience init(timeInterval interval: TimeInterval, repeats: Bool, block: @escaping (Timer) -> Swift.Void) {
        let target = TimerTarget(block: block)
        self.init(timeInterval: interval, target: target, selector: #selector(TimerTarget.fire), userInfo: nil, repeats: repeats)
    }
}
