import Foundation


public struct Message {
    public var header: Header
    public var questions: [Question]
    public var answers: [ResourceRecord]
    public var authorities: [ResourceRecord]
    public var additional: [ResourceRecord]

    public init(header: Header, questions: [Question] = [], answers: [ResourceRecord] = [], authorities: [ResourceRecord] = [], additional: [ResourceRecord] = []) {
        self.header = header
        self.questions = questions
        self.answers = answers
        self.authorities = authorities
        self.additional = additional
    }
}


public struct Header {
    public var id: UInt16
    public var response: Bool
    public var operationCode: OperationCode
    public var authoritativeAnswer: Bool
    public var truncation: Bool
    public var recursionDesired: Bool
    public var recursionAvailable: Bool
    public var returnCode: ReturnCode

    public init(id: UInt16 = 0, response: Bool, operationCode: OperationCode = .query, authoritativeAnswer: Bool = true, truncation: Bool = false, recursionDesired: Bool = false, recursionAvailable: Bool = false, returnCode: ReturnCode = .NOERROR) {
        self.id = id
        self.response = response
        self.operationCode = operationCode
        self.authoritativeAnswer = authoritativeAnswer
        self.truncation = truncation
        self.recursionDesired = recursionDesired
        self.recursionAvailable = recursionAvailable
        self.returnCode = returnCode
    }
}

extension Header: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch response {
        case false: return "DNS Request Header(id: \(id), authoritativeAnswer: \(authoritativeAnswer), truncation: \(truncation), recursionDesired: \(recursionDesired), recursionAvailable: \(recursionAvailable))"
        case true: return "DNS Response Header(id: \(id), returnCode: \(returnCode), authoritativeAnswer: \(authoritativeAnswer), truncation: \(truncation), recursionDesired: \(recursionDesired), recursionAvailable: \(recursionAvailable))"
        }
    }
}


public enum OperationCode: UInt8 {
    case query = 0
}

public enum ReturnCode: UInt8 {
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


public struct Question {
    public var name: String
    public var type: ResourceRecordType
    public var unique: Bool
    public var internetClass: UInt16

    init(name: String, type: ResourceRecordType, unique: Bool = false, internetClass: UInt16 = 1) {
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


public enum ResourceRecordType: UInt16 {
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


public protocol ResourceRecord {
    var name: String { get }
    var unique: Bool { get }
    var internetClass: UInt16 { get }
    var ttl: UInt32 { get set }

    func pack() throws -> Data
}


public struct Record {
    public var name: String
    public var type: UInt16
    public var internetClass: UInt16
    public var unique: Bool
    public var ttl: UInt32
    var data: Data

    public init(name: String, type: UInt16, internetClass: UInt16, unique: Bool, ttl: UInt32, data: Data) {
        self.name = name
        self.type = type
        self.internetClass = internetClass
        self.unique = unique
        self.ttl = ttl
        self.data = data
    }
}


public struct HostRecord<IPType: IP> {
    public var name: String
    public var unique: Bool
    public var internetClass: UInt16
    public var ttl: UInt32
    public var ip: IPType

    public init(name: String, unique: Bool = false, internetClass: UInt16 = 1, ttl: UInt32, ip: IPType) {
        self.name = name
        self.unique = unique
        self.internetClass = internetClass
        self.ttl = ttl
        self.ip = ip
    }
}


extension HostRecord: Hashable {
    public var hashValue: Int {
        return name.hashValue
    }

    public static func ==<IPType: IP> (lhs: HostRecord<IPType>, rhs: HostRecord<IPType>) -> Bool {
        return lhs.name == rhs.name
        // TODO: check equality of IP addresses
    }
}


public struct ServiceRecord {
    public var name: String
    public var unique: Bool
    public var internetClass: UInt16
    public var ttl: UInt32
    public var priority: UInt16
    public var weight: UInt16
    public var port: UInt16
    public var server: String

    public init(name: String, unique: Bool = false, internetClass: UInt16 = 1, ttl: UInt32, priority: UInt16 = 0, weight: UInt16 = 0, port: UInt16, server: String) {
        self.name = name
        self.unique = unique
        self.internetClass = internetClass
        self.ttl = ttl
        self.priority = priority
        self.weight = weight
        self.port = port
        self.server = server
    }
}


extension ServiceRecord: Hashable {
    public var hashValue: Int {
        return name.hashValue
    }

    public static func == (lhs: ServiceRecord, rhs: ServiceRecord) -> Bool {
        return lhs.name == rhs.name
    }
}


public struct TextRecord {
    public var name: String
    public var unique: Bool
    public var internetClass: UInt16
    public var ttl: UInt32
    var attributes: [String: String]
    var values: [String]

    public init(name: String, unique: Bool = false, internetClass: UInt16 = 1, ttl: UInt32, attributes: [String: String]) {
        self.name = name
        self.unique = unique
        self.internetClass = internetClass
        self.ttl = ttl
        self.attributes = attributes
        self.values = []
    }
}


public struct PointerRecord {
    public var name: String
    public var unique: Bool
    public var internetClass: UInt16
    public var ttl: UInt32
    public var destination: String

    public init(name: String, unique: Bool = false, internetClass: UInt16 = 1, ttl: UInt32, destination: String) {
        self.name = name
        self.unique = unique
        self.internetClass = internetClass
        self.ttl = ttl
        self.destination = destination
    }
}


extension PointerRecord: Hashable {
    public var hashValue: Int {
        return destination.hashValue
    }

    public static func == (lhs: PointerRecord, rhs: PointerRecord) -> Bool {
        return lhs.name == rhs.name && lhs.destination == rhs.destination
    }
}
