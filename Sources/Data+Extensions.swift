import Foundation

// Removed in Xcode 8 beta 3
func + (lhs: Data, rhs: Data) -> Data {
    var result = lhs
    result.append(rhs)
    return result
}

// Removed in Xcode 8 beta 3
extension Data {
    init<C: Collection>(_ collection: C) where C.Iterator.Element == UInt8 {
        self = Data(bytes: Array(collection))
    }
}

extension Data {
    init?(hex: String) {
        var result = [UInt8]()
        var from = hex.characters.startIndex
        while from < hex.characters.endIndex {
            guard let to = hex.characters.index(from, offsetBy: 2, limitedBy: hex.characters.endIndex) else {
                return nil
            }
            guard let num = UInt8(hex[from..<to], radix: 16) else {
                return nil
            }
            result.append(num)
            from = to
        }
        self = Data(result)
    }
}

extension RandomAccessCollection where Iterator.Element == UInt8, Index == Int {
    var hex: String {
        return self.reduce("") { $0 + String(format:"%02x", $1) }
    }
}

extension RandomAccessCollection where Iterator.Element == UInt8, Index == Int {
    func dump() {
        var start = startIndex
        var end = startIndex
        while start < endIndex {
            _ = formIndex(&end, offsetBy: 24, limitedBy: endIndex)

            print(UInt32(distance(from: startIndex, to: start).toIntMax()).bytes.hex, terminator: ":  ")

            var byteStart = start
            for pos in 0..<24 {
                if byteStart < endIndex {
                    print(String(format:"%02x", self[byteStart]), terminator: "")
                } else {
                    print("  ", terminator: "")
                }
                if pos % 2 == 1 { print(" ", terminator: "") }
                _ = formIndex(&byteStart, offsetBy: 1, limitedBy: endIndex)
            }

            print(" :", terminator: "")

            byteStart = start
            for _ in 0..<24 {
                if byteStart < endIndex {
                    let byte = self[byteStart]
                    if (32..<127).contains(byte) {
                        print(UnicodeScalar(byte), terminator: "")
                    } else {
                        print(".", terminator: "")
                    }
                } else {
                    print(" ", terminator: "")
                }
                _ = formIndex(&byteStart, offsetBy: 1, limitedBy: endIndex)
            }

            print()
            start = end
        }
    }
}


