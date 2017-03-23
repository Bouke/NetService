import XCTest
@testable import DNS

class DNSTests: XCTestCase {
    static var allTests : [(String, (DNSTests) -> () throws -> Void)] {
        return [
            ("testPointerRecord", testPointerRecord)
        ]
    }

    func testPointerRecord() {
        let pointer0 = PointerRecord(name: "_hap._tcp.local.", ttl: 120, destination: "Swift._hap._tcp.local.")
        let packed0 = try! pointer0.pack()

        let pointer1 = PointerRecord(name: "_hap._tcp.local", ttl: 120, destination: "Swift._hap._tcp.local")
        let packed1 = try! pointer1.pack()

        XCTAssertEqual(packed0.hex, packed1.hex)

        var position = packed0.startIndex
        let rcf = unpackRecordCommonFields(packed0, &position)
        let pointer0copy = PointerRecord(unpack: packed0, position: &position, common: rcf)

        XCTAssertEqual(pointer0, pointer0copy)
    }
}
