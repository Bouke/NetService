import struct Foundation.Data
import struct Foundation.Date
import class Foundation.DispatchQueue
import class Foundation.RunLoop
import var Basic.stdoutStream
import class Utility.ArgumentParser

#if USE_FOUNDATION
    import Foundation
#else
    import NetService
#endif

#if os(macOS)
    import Darwin
#elseif os(Linux)
    import Dispatch
    import Glibc
#endif

let parser = ArgumentParser(commandName: "dns-sd", usage: "", overview: "", seeAlso: "")
let enumerateRegistrationDomains = parser.add(option: "-E", kind: Bool.self,
                                              usage: "                             (Enumerate recommended registration domains)")
let enumerateBrowsingDomains = parser.add(option: "-F", kind: Bool.self,
                                          usage: "                                 (Enumerate recommended browsing domains)")
let register = parser.add(option: "-R", kind: [String].self,
                          usage: "<Name> <Type> <Domain> <Port> [<TXT>...]             (Register a service)")
let browse = parser.add(option: "-B", kind: [String].self,
                        usage: "       <Type> <Domain>                     (Browse for service instances)")
let resolve = parser.add(option: "-L", kind: [String].self,
                         usage: "<Name> <Type> <Domain>                       (Resolve a service instance)")

guard let result = try? parser.parse(Array(CommandLine.arguments.dropFirst())) else {
    parser.printUsage(on: stdoutStream)
    exit(-1)
}

var keepRunning = true
signal(SIGINT) { _ in
    DispatchQueue.main.async {
        keepRunning = false
    }
}

if result.get(enumerateRegistrationDomains) != nil {
    print("Looking for recommended registration domains:")
    let browser = NetServiceBrowser()
    let delegate = EnumerateRegistrationDomainsDelegate()
    browser.delegate = delegate
    browser.searchForRegistrationDomains()
    withExtendedLifetime([browser, delegate]) {
        while keepRunning {
            _ = RunLoop.main.run(mode: .defaultRunLoopMode, before: Date.distantFuture)
        }
    }
    browser.stop()
}

if result.get(enumerateBrowsingDomains) != nil {
    print("Looking for recommended browsing domains:")
    let browser = NetServiceBrowser()
    let delegate = EnumerateBrowsingDomainsDelegate()
    browser.delegate = delegate
    browser.searchForBrowsableDomains()
    withExtendedLifetime([browser, delegate]) {
        while keepRunning {
            _ = RunLoop.main.run(mode: .defaultRunLoopMode, before: Date.distantFuture)
        }
    }
    browser.stop()
}

if let register = result.get(register) {
    guard register.count >= 4, let port = Int32(register[3]) else {
        parser.printUsage(on: stdoutStream)
        exit(-1)
    }
    let service = NetService(domain: register[2], type: register[1], name: register[0], port: port)
    let keyvalues: [String: Data] = Dictionary(items: register.dropFirst(4).map {
        let (key, value) = $0.split(around: "=")
        return (key, value!.data(using: .utf8)!)
    })
    let txtRecord = NetService.data(fromTXTRecord: keyvalues)
    guard service.setTXTRecord(txtRecord) else {
        print("Failed to set text record")
        exit(-1)
    }
    let delegate = RegisterServiceDelegate()
    service.delegate = delegate
    service.publish()
    withExtendedLifetime([service, delegate]) {
        while keepRunning {
            _ = RunLoop.main.run(mode: .defaultRunLoopMode, before: Date.distantFuture)
        }
    }
    service.stop()
}

if let browse = result.get(browse) {
    print("Browsing for \(browse[0])")
    let browser = NetServiceBrowser()
    let delegate = BrowseServicesDelegate()
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

if let resolve = result.get(resolve) {
    guard resolve.count >= 2 else {
        parser.printUsage(on: stdoutStream)
        exit(-1)
    }
    let domain = resolve.count == 3 ? resolve[2] : "local."
    print("Lookup \(resolve[0]).\(resolve[1]).\(domain)")
    let service = NetService(domain: domain, type: resolve[1], name: resolve[0])
    let delegate = ResolveServiceDelegate()
    service.delegate = delegate
    service.resolve(withTimeout: 5)
    withExtendedLifetime([service, delegate]) {
        while keepRunning {
            _ = RunLoop.main.run(mode: .defaultRunLoopMode, before: Date.distantFuture)
        }
    }
    service.stop()
}
