import Foundation


struct Message {
    let header: Header
    let questions: [Question]
    let answers: [ResourceRecord]
    let authorities: [ResourceRecord]
    let additional: [ResourceRecord]
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

extension Header: CustomDebugStringConvertible {
    var debugDescription: String {
        switch response {
        case false: return "DNS Request Header(id: \(id), authoritativeAnswer: \(authoritativeAnswer), truncation: \(truncation), recursionDesired: \(recursionDesired), recursionAvailable: \(recursionAvailable))"
        case true: return "DNS Response Header(id: \(id), returnCode: \(returnCode), authoritativeAnswer: \(authoritativeAnswer), truncation: \(truncation), recursionDesired: \(recursionDesired), recursionAvailable: \(recursionAvailable))"
        }
    }
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


struct Question {
    let name: String
    let type: ResourceRecordType
    let unique: Bool
    let internetClass: UInt16

    init(name: String, type: ResourceRecordType, unique: Bool = false, internetClass: UInt16) {
        self.name = name
        self.type = type
        self.unique = unique
        self.internetClass = internetClass
    }

    init(unpack data: Data, position: inout Data.Index) {
        name = unpackName(data, &position)
        type = ResourceRecordType(rawValue: UInt16(bytes: data[position..<position+2]))!
        unique = data[position+2] & 0x80 == 0x80
        internetClass = UInt16(bytes: data[position+2..<position+4]) & 0x7fff
        position += 4
    }
}


enum ResourceRecordType: UInt16 {
    case host = 0x0001
    case nameServer = 0x0002
    case alias = 0x0005
    case startOfAuthority = 0x0006
    case wellKnownSource = 0x000b
    case pointer = 0x000c
    case mailExchange = 0x000f
    case text = 0x0010
    case host6 = 0x001c
    case service = 0x0021
    case incrementalZoneTransfer = 0x00fb
    case standardZoneTransfer = 0x00fc
    case all = 0x00ff
}


protocol ResourceRecord {
    var name: String { get }
    var unique: Bool { get }
    var internetClass: UInt16 { get }
    var ttl: UInt32 { get set }
}


struct Record: ResourceRecord {
    let name: String
    let type: ResourceRecordType?
    let unique: Bool
    let internetClass: UInt16
    var ttl: UInt32
    var data: Data
}


struct HostRecord<IPType: IP>: ResourceRecord {
    let name: String
    let unique: Bool
    let internetClass: UInt16
    var ttl: UInt32
    let ip: IPType
}


struct ServiceRecord: ResourceRecord {
    let name: String
    let unique: Bool
    let internetClass: UInt16
    var ttl: UInt32
    let priority: UInt16
    let weight: UInt16
    let port: UInt16
    let server: String
}


extension ServiceRecord: Hashable {
    var hashValue: Int {
        return name.hashValue
    }

    static func == (lhs: ServiceRecord, rhs: ServiceRecord) -> Bool {
        return lhs.name == rhs.name
    }
}


struct TextRecord: ResourceRecord {
    let name: String
    let unique: Bool
    let internetClass: UInt16
    var ttl: UInt32
    var attributes: [String: String]
}


struct PointerRecord: ResourceRecord {
    let name: String
    let unique: Bool
    let internetClass: UInt16
    var ttl: UInt32
    let destination: String
}
