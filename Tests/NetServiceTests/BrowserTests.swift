import NetService
import class XCTest.XCTestCase

class BrowserTests: XCTestCase {
    static var allTests: [(String, (BrowserTests) -> () throws -> Void)] {
        return [
            ("testBrowse", testBrowse)
        ]
    }

    func testBrowse() {
        let browser = NetServiceBrowser()
        browser.searchForServices(ofType: "_ssh._tcp.", inDomain: "local.")
        browser.stop()
    }
}
