import struct Foundation.Date
import class Foundation.DateFormatter
import class Foundation.DispatchQueue
import class Foundation.NSNumber
import class Foundation.RunLoop
import NetService
import Utility

#if os(macOS)
    import Darwin
#elseif os(Linux)
    import Dispatch
    import Glibc
#endif

let parser = ArgumentParser(commandName: "dns-sd", usage: "", overview: "", seeAlso: "")
let browse = parser.add(option: "-B", kind: [String].self)
let result = try parser.parse(Array(CommandLine.arguments.dropFirst()))

class BrowserDelegate: NetServiceBrowserDelegate {
    let timeFormatter: DateFormatter

    init() {
        timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss.sss"
    }

    func time() -> String {
        return timeFormatter.string(from: Date())
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        print(time() +
            "  Add        ?   ? " +
            service.domain.padding(toLength: 21, withPad: " ", startingAt: 0) +
            service.type.padding(toLength: 21, withPad: " ", startingAt: 0) +
            service.name)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        print(time() +
            "  Remove     ?   ? " +
            service.domain.padding(toLength: 21, withPad: " ", startingAt: 0) +
            service.type.padding(toLength: 21, withPad: " ", startingAt: 0) +
            service.name)
    }

    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        print("\(time())  ...STARTING...")
        print("Timestamp     A/R    Flags  if Domain               Service Type         Instance Name")
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        print("Did not search: \(errorDict)")
    }
}

var keepRunning = true
signal(SIGINT) { _ in
    DispatchQueue.main.async {
        keepRunning = false
    }
}

if let browse = result.get(browse) {
    print("Browsing for \(browse[0])")
    let browser = NetServiceBrowser()
    let delegate = BrowserDelegate()
    browser.delegate = delegate
    let serviceType = browse[0]
    let domain = browse.count == 2 ? browse[1] : "local."
    browser.searchForServices(ofType: serviceType, inDomain: domain)
    withExtendedLifetime([browser, delegate]) {
        while keepRunning {
            _ = RunLoop.main.run(mode: .defaultRunLoopMode, before: Date.distantFuture)
        }
    }
    browser.stop()
}

