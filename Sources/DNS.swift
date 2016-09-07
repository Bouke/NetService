import Foundation

enum EncodeError: Swift.Error {
    case unicodeEncodingNotSupported
}


func unpackName(_ data: Data, _ position: inout Data.Index) -> String {
    var components = [String]()
    while true {
        let step = data[position]
        if step & 0xc0 == 0xc0 {
            var pointer = data.index(data.startIndex, offsetBy: Int(UInt16(bytes: data[position..<position+2]) ^ 0xc000))
            components += unpackName(data, &pointer).components(separatedBy: ".")
            position += 2
            break
        }

        let start = data.index(position, offsetBy: 1)
        let end = data.index(start, offsetBy: Int(step))
        if step > 0 {
            for byte in data[start..<end] {
                precondition((0x20..<0xff).contains(byte))
            }
            components.append(String(bytes: data[start..<end], encoding: .utf8)!)
        } else {
            position = end
            break
        }
        position = end
    }
    return components.joined(separator: ".")
}


func unpack<T: Integer>(_ data: Data, _ position: inout Data.Index) -> T {
    let size = MemoryLayout<T>.size
    defer { position += size }
    return T(bytes: data[position..<position+size])
}


typealias RecordCommonFields = (name: String, type: ResourceRecordType?, unique: Bool, internetClass: UInt16, ttl: UInt32)

func unpackRecordCommonFields(_ data: Data, _ position: inout Data.Index) -> RecordCommonFields {
    return (unpackName(data, &position),
            ResourceRecordType(rawValue: unpack(data, &position)),
            data[position] & 0x80 == 0x80,
            unpack(data, &position),
            unpack(data, &position))
}


func unpackRecord(_ data: Data, _ position: inout Data.Index) -> ResourceRecord {
    let common = unpackRecordCommonFields(data, &position)
    switch common.type {
    case .host?: return HostRecord<IPv4>(unpack: data, position: &position, common: common)
    case .host6?: return HostRecord<IPv6>(unpack: data, position: &position, common: common)
    case .service?: return ServiceRecord(unpack: data, position: &position, common: common)
    case .text?: return TextRecord(unpack: data, position: &position, common: common)
    case .pointer?: return PointerRecord(unpack: data, position: &position, common: common)
    default: return Record(unpack: data, position: &position, common: common)
    }
}


func encodeName(_ name: String) throws -> [UInt8] {
    if name.utf8.reduce(false, { $0 || $1 & 128 == 128 }) {
        throw EncodeError.unicodeEncodingNotSupported
    }
    var bytes: [UInt8] = []
    for label in name.components(separatedBy: ".") {
        let codes = Array(label.utf8)
        bytes += [UInt8(codes.count)] + codes
    }
    bytes.append(0)
    return bytes
}


extension Message {
    func pack() -> [UInt8] {
        var bytes: [UInt8] = []

        let flags: UInt16 = (header.response ? 1 : 0) << 15 | UInt16(header.operationCode.rawValue) << 11 | (header.authoritativeAnswer ? 1 : 0) << 10 | (header.truncation ? 1 : 0) << 9 | (header.recursionDesired ? 1 : 0) << 8 | (header.recursionAvailable ? 1 : 0) << 7 | UInt16(header.returnCode.rawValue)

        // header
        bytes += header.id.bytes
        bytes += flags.bytes
        bytes += UInt16(questions.count).bytes
        bytes += UInt16(answers.count).bytes
        bytes += UInt16(authorities.count).bytes
        bytes += UInt16(additional.count).bytes

        // questions
        for question in questions {
            bytes += try! encodeName(question.name)
            bytes += question.type.rawValue.bytes
            bytes += question.internetClass.bytes
        }

        return bytes
    }

    init(unpackTCP bytes: Data) {
        precondition(bytes.count >= 2)
        let size = Int(UInt16(bytes: bytes[0..<2]))

        // strip size bytes (tcp only?)
        var bytes = Data(bytes[2..<2+size]) // copy? :(
        precondition(bytes.count == Int(size))

        self.init(unpack: bytes)
    }

    init(unpack bytes: Data) {
        let flags = UInt16(bytes: bytes[2..<4])

        header = Header(id: UInt16(bytes: bytes[0..<2]),
                        response: flags >> 15 & 1 == 1,
                        operationCode: OperationCode(rawValue: UInt8(flags >> 11 & 0x7))!,
                        authoritativeAnswer: flags >> 10 & 0x1 == 0x1,
                        truncation: flags >> 9 & 0x1 == 0x1,
                        recursionDesired: flags >> 8 & 0x1 == 0x1,
                        recursionAvailable: flags >> 7 & 0x1 == 0x1,
                        returnCode: ReturnCode(rawValue: UInt8(flags & 0x7))!)

        var position = bytes.index(bytes.startIndex, offsetBy: 12)

        questions = (0..<UInt16(bytes: bytes[4..<6])).map { _ in Question(unpack: bytes, position: &position) }
        answers = (0..<UInt16(bytes: bytes[6..<8])).map { _ in unpackRecord(bytes, &position) }
        authorities = (0..<UInt16(bytes: bytes[8..<10])).map { _ in unpackRecord(bytes, &position) }
        additional = (0..<UInt16(bytes: bytes[10..<12])).map { _ in unpackRecord(bytes, &position) }
    }

    func tcp() -> [UInt8] {
        let payload = self.pack()
        return UInt16(payload.count).bytes + payload
    }
}

extension Record {
    init(unpack data: Data, position: inout Data.Index, common: RecordCommonFields) {
        (name, type, unique, internetClass, ttl) = common
        let size = Int(unpack(data, &position) as UInt16)
        self.data = Data(data[position..<position+size])
        position += size
    }
}

extension HostRecord {
    init(unpack data: Data, position: inout Data.Index, common: RecordCommonFields) {
        (name, _, unique, internetClass, ttl) = common
        let size = Int(unpack(data, &position) as UInt16)
        ip = IPType(Data(data[position..<position+size]))
        position += size
    }
}

extension ServiceRecord {
    init(unpack data: Data, position: inout Data.Index, common: RecordCommonFields) {
        (name, _, unique, internetClass, ttl) = common
        _ = unpack(data, &position) as UInt16
        priority = unpack(data, &position)
        weight = unpack(data, &position)
        port = unpack(data, &position)
        server = unpackName(data, &position)
    }
}

extension TextRecord {
    init(unpack data: Data, position: inout Data.Index, common: RecordCommonFields) {
        (name, _, unique, internetClass, ttl) = common
        let endIndex = position + Int(unpack(data, &position) as UInt16)

        var attrs = [String: String]()
        while position < endIndex {
            let size = Int(unpack(data, &position) as UInt8)
            guard size > 0 else { break }
            var attr = String(bytes: data[position..<position+size], encoding: .utf8)!.characters.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: true).map { String($0) }
            attrs[attr[0]] = attr[1]
            position += size
        }
        self.attributes = attrs
    }
}

extension PointerRecord {
    init(unpack data: Data, position: inout Data.Index, common: RecordCommonFields) {
        (name, _, unique, internetClass, ttl) = common
        position += 2
        destination = unpackName(data, &position)
    }
}
