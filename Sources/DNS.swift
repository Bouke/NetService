import Foundation

enum Error: Swift.Error {
    case unicodeEncodingNotSupported
}

enum OperationCode: UInt8 {
    case query = 0
}

enum ReturnCode: UInt8 {
    case NOERROR = 0
    case FORMERR = 1
    case SERVFAIL = 0x2
    case NXDOMAIN = 0x3
    case NOTIMP = 0x4
    case REFUSED = 0x5
    case YXDOMAIN = 0x6
    case YXRRSET = 0x7
    case NXRRSET = 0x8
    case NOTAUTH = 0x9
    case NOTZONE = 0xA
}

struct Header {
    let id: UInt16
    let response: Bool
    let operationCode: OperationCode
    let authoritativeAnswer: Bool
    let truncation: Bool
    let recursionDesired: Bool
    let recursionAvailable: Bool
    let returnCode: ReturnCode
}

struct Question {
    let name: String
    let type: ResourceRecordType
    let internetClass: UInt16

    init(name: String, type: ResourceRecordType, internetClass: UInt16) {
        self.name = name
        self.type = type
        self.internetClass = internetClass
    }

    init(unpack data: Data, position: inout Data.Index) {
        name = decodeName(data, position: &position)
        type = ResourceRecordType(rawValue: UInt16(bytes: data[position..<position+2]))!
        internetClass = UInt16(bytes: data[position+2..<position+4])
        position += 4
    }
}

enum ResourceRecordType: UInt16 {
    case host = 0x0001
    case nameServer = 0x0002
    case alias = 0x0005
    case startOfAuthority = 0x0006
    case wellKnownSource = 0x000b
    case reverseLookup = 0x000c
    case mailExchange = 0x000f
    case text = 0x0010
    case host6 = 0x001c
    case service = 0x0021
    case incrementalZoneTransfer = 0x00fb
    case standardZoneTransfer = 0x00fc
    case all = 0x00ff
}

enum ResourceRecordData {
    case host(IPv4)
    case host6(IPv6)
    case text(String)
    case other(ResourceRecordType, Data)
}

struct IPv4 {
    let address: UInt32

    init(_ address: UInt32) {
        self.address = address
    }
}

extension IPv4: CustomDebugStringConvertible {
    var debugDescription: String {
        return "\(address >> 24 & 0xff).\(address >> 16 & 0xff).\(address >> 8 & 0xff).\(address & 0xff)"
    }
}


struct IPv6 {
    let address: Data

    init(_ address: Data) {
        self.address = address
    }
}

extension IPv6: CustomDebugStringConvertible {
    var debugDescription: String {
        return (0..<8)
            .map { address[$0*2..<$0*2+2].hex }
            .joined(separator: ":")
    }
}


struct ResourceRecord {
    let name: String
    let internetClass: UInt16
    let ttl: UInt32
    let data: ResourceRecordData
}

extension ResourceRecord {
    init(unpack data: Data, position: inout Data.Index) {
        if data[position] & 0xc0 == 0xc0 {
            var pointer = data.index(data.startIndex, offsetBy: Int(UInt16(bytes: data[position..<position+2]) ^ 0xc000))
            name = decodeName(data, position: &pointer)
            position += 2
        } else {
            name = decodeName(data, position: &position)
        }
        let type = ResourceRecordType(rawValue: UInt16(bytes: data[position..<position+2]))!
        internetClass = UInt16(bytes: data[position+2..<position+4])
        ttl = UInt32(bytes: data[position+4..<position+8])
        let size = Int(UInt16(bytes: data[position+8..<position+10]))
        let rdata = Data(data[position+10..<position+10+size])
        switch type {
        case .host: self.data = .host(IPv4(UInt32(bytes: rdata)))
        case .host6: self.data = .host6(IPv6(rdata))
        case .text: self.data = .text(String(bytes: rdata[1..<rdata.endIndex], encoding: .ascii)!)
        default: self.data = .other(type, rdata)
        }

        position += 10 + size
    }
}

struct Message {
    let header: Header
    let questions: [Question]
    let answers: [ResourceRecord]
    let authorities: [ResourceRecord]
    let additional: [ResourceRecord]
}

func encodeName(_ name: String) throws -> [UInt8] {
    if name.utf8.reduce(false, { $0 || $1 & 128 == 128 }) {
        throw Error.unicodeEncodingNotSupported
    }
    var bytes: [UInt8] = []
    for label in name.components(separatedBy: ".") {
        let codes = Array(label.utf8)
        bytes += [UInt8(codes.count)] + codes
    }
    bytes.append(0)
    return bytes
}

func decodeName(_ data: Data, position: inout Data.Index) -> String {
    var components = [String]()
    while position < data.endIndex {
        let step = data[position]
        let start = data.index(position, offsetBy: 1)
        let end = data.index(start, offsetBy: Int(step))
        if step > 0 {
            components.append(String(bytes: data[start..<end], encoding: .ascii)!)
        } else {
            position = end
            break
        }
        position = end
    }
    return components.joined(separator: ".")
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
        answers = (0..<UInt16(bytes: bytes[6..<8])).map { _ in ResourceRecord(unpack: bytes, position: &position) }
        authorities = (0..<UInt16(bytes: bytes[8..<10])).map { _ in ResourceRecord(unpack: bytes, position: &position) }
        additional = (0..<UInt16(bytes: bytes[10..<12])).map { _ in ResourceRecord(unpack: bytes, position: &position) }
    }

    func tcp() -> [UInt8] {
        let payload = self.pack()
        return UInt16(payload.count).bytes + payload
    }
}
