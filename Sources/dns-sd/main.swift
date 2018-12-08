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
let register = parser.add(option: "-R", kind: [String].self,
                          usage: "<Name> <Type> <Domain> <Port> [<TXT>...]             (Register a service)")
let browse = parser.add(option: "-B", kind: [String].self,
                        usage: "       <Type> <Domain>                     (Browse for service instances)")
let result = try parser.parse(Array(CommandLine.arguments.dropFirst()))

class Delegate: NetServiceBrowserDelegate, NetServiceDelegate {
    let timeFormatter = DateFormatter()
    let dateFormatter = DateFormatter()

    init() {
        timeFormatter.dateFormat = "HH:mm:ss.sss"
        dateFormatter.dateStyle = .full
    }

    func time() -> String {
        return timeFormatter.string(from: Date())
    }

    func date() -> String {
        return dateFormatter.string(from: Date())
    }

    //MARK:- NetServiceBrowserDelegate

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
        print("DATE: ---\(date())---")
        print("\(time())  ...STARTING...")
        print("Timestamp     A/R    Flags  if Domain               Service Type         Instance Name")
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        print("Did not search: \(errorDict)")
    }

    //MARK:- NetServiceDelegate

    func netServiceWillPublish(_ sender: NetService) {
        print("DATE: ---\(date())---")
        print("\(time())  ...STARTING...")
    }

    func netServiceDidPublish(_ sender: NetService) {
        print("\(time())  Got a reply for service \(sender.name).\(sender.type).\(sender.domain): Name now registered and active")
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        print("DNSService call failed \(errorDict)")
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
    let delegate = Delegate()
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

if let register = result.get(register) {
    guard register.count >= 4, let port = Int32(register[3]) else { // key=value...
        print("Usage: dns-sd -R <Name> <Type> <Domain> <Port> [<TXT>...]")
        exit(-1)
    }
    let service = NetService(domain: register[2], type: register[1], name: register[0], port: port)
    let keyvalues : [String: String] = Dictionary(items: register.dropFirst(4).map { $0.split(around: "=") })
    let txtRecord = NetService.data(fromTXTRecord: keyvalues)
    guard service.setTXTRecord(txtRecord) else {
        print("Failed to set text record")
        exit(-1)
    }
    let delegate = Delegate()
    service.delegate = delegate
    service.publish()
    withExtendedLifetime([service, delegate]) {
        while keepRunning {
            _ = RunLoop.main.run(mode: .defaultRunLoopMode, before: Date.distantFuture)
        }
    }
    service.stop()
}
