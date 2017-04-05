extension RandomAccessCollection where Iterator.Element == UInt8, Index == Int {
    var hex: String {
        return self.reduce("") { $0 + String(format:"%02x", $1) }
    }
}
