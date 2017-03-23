import XCTest
@testable import DNS

class IPTests: XCTestCase {
    static var allTests : [(String, (IPTests) -> () throws -> Void)] {
        return [
            ("testIPv4Valid", testIPv4Valid),
            ("testIPv4Invalid", testIPv4Invalid),
            ("testIPv4Predefined", testIPv4Predefined),
            ("testIPv4Bytes", testIPv4Bytes),
            ("testIPv4Literal", testIPv4Literal),
            ("testIPv4Equality", testIPv4Equality),
            ("testIPv6Valid", testIPv6Valid),
            ("testIPv6Invalid", testIPv6Invalid),
            ("testIPv6Predefined", testIPv6Predefined),
            ("testIPv6Bytes", testIPv6Bytes)
        ]
    }

    func testIPv4Valid() {
        XCTAssertEqual(IPv4("0.0.0.0")?.presentation, "0.0.0.0")
        XCTAssertEqual(IPv4("127.0.0.1")?.presentation, "127.0.0.1")
        XCTAssertEqual(IPv4("1.2.3.4")?.presentation, "1.2.3.4")
        XCTAssertEqual(IPv4("255.255.255.255")?.presentation, "255.255.255.255")
    }

    func testIPv4Invalid() {
        XCTAssertNil(IPv4("127.0.0.-1"))
        XCTAssertNil(IPv4("256.0.0.1"))
    }

    func testIPv4Predefined() {
        XCTAssertEqual(IPv4(INADDR_ANY), IPv4("0.0.0.0"))
        XCTAssertEqual(IPv4(INADDR_BROADCAST), IPv4("255.255.255.255"))
        XCTAssertEqual(IPv4(INADDR_LOOPBACK), IPv4("127.0.0.1"))
        XCTAssertEqual(IPv4(INADDR_NONE), IPv4("255.255.255.255"))
        XCTAssertEqual(IPv4(INADDR_UNSPEC_GROUP), IPv4("224.0.0.0"))
        XCTAssertEqual(IPv4(INADDR_ALLHOSTS_GROUP), IPv4("224.0.0.1"))
        XCTAssertEqual(IPv4(INADDR_ALLRTRS_GROUP), IPv4("224.0.0.2"))
        #if os(OSX)
            XCTAssertEqual(IPv4(INADDR_ALLRPTS_GROUP), IPv4("224.0.0.22"))
            XCTAssertEqual(IPv4(INADDR_CARP_GROUP), IPv4("224.0.0.18"))
            XCTAssertEqual(IPv4(INADDR_PFSYNC_GROUP), IPv4("224.0.0.240"))
            XCTAssertEqual(IPv4(INADDR_ALLMDNS_GROUP), IPv4("224.0.0.251"))
        #endif
        XCTAssertEqual(IPv4(INADDR_MAX_LOCAL_GROUP), IPv4("224.0.0.255"))
    }

    func testIPv4Bytes() {
        XCTAssertEqual(IPv4(networkBytes: Data(hex: "e00000fb")!), IPv4("224.0.0.251"))
        XCTAssertEqual(IPv4("224.0.0.251")!.bytes.hex, "e00000fb")
        XCTAssertEqual(IPv4(networkBytes: IPv4("224.0.0.251")!.bytes), IPv4("224.0.0.251"))
    }

    func testIPv4Literal() {
        XCTAssertEqual(0, IPv4(integerLiteral: INADDR_ANY))
        XCTAssertEqual(0xffffffff, IPv4(integerLiteral: INADDR_BROADCAST))
    }

    func testIPv4Equality() {
        XCTAssertEqual(IPv4("0.0.0.0"), IPv4("0.0.0.0"))
        XCTAssertEqual(IPv4("127.0.0.1"), IPv4("127.0.0.1"))
    }

    func testIPv6Valid() {
        XCTAssertEqual(IPv6("::")?.presentation, "::")
        XCTAssertEqual(IPv6("::1")?.presentation, "::1")
        XCTAssertEqual(IPv6("ff01::1")?.presentation, "ff01::1")
        XCTAssertEqual(IPv6("ff02::1")?.presentation, "ff02::1")
        XCTAssertEqual(IPv6("ff02::2")?.presentation, "ff02::2")
    }

    func testIPv6Invalid() {
        XCTAssertNil(IPv6("127.0.0.1"))
        XCTAssertNil(IPv6("abcde::1"))
        XCTAssertNil(IPv6("g::1"))
        XCTAssertNil(IPv6("a::bb::a"))
    }

    func testIPv6Predefined() {
        XCTAssertEqual(IPv6(address: in6addr_any), IPv6("::"))
        XCTAssertEqual(IPv6(address: in6addr_loopback), IPv6("::1"))
        #if os(OSX)
            XCTAssertEqual(IPv6(address: in6addr_nodelocal_allnodes), IPv6("ff01::1"))
            XCTAssertEqual(IPv6(address: in6addr_linklocal_allnodes), IPv6("ff02::1"))
            XCTAssertEqual(IPv6(address: in6addr_linklocal_allrouters), IPv6("ff02::2"))
        #endif
   }

    func testIPv6Bytes() {
        XCTAssertEqual(IPv6(networkBytes: Data(hex: "ff010000000000000000000000000001")!), IPv6("ff01::1"))
        XCTAssertEqual(IPv6("ff01::1")!.bytes.hex, "ff010000000000000000000000000001")
        XCTAssertEqual(IPv6(networkBytes: IPv6("ff01::1")!.bytes), IPv6("ff01::1"))
    }
}
