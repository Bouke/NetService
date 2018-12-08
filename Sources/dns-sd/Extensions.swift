extension String {
    func leftPadding(toLength: Int, withPad character: Character) -> String {
        let newLength = self.count
        if newLength < toLength {
            return String(repeatElement(character, count: toLength - newLength)) + self
        } else {
            return String(self[index(self.startIndex, offsetBy: newLength - toLength)...])
        }
    }
}
