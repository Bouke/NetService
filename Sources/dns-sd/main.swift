import struct Foundation.Data
import struct Foundation.Date
import class Foundation.DispatchQueue
import class Foundation.RunLoop

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

func printUsage() {
    print("""
        dns-sd -E                              (Enumerate recommended registration domains)
        dns-sd -F                                  (Enumerate recommended browsing domains)
        dns-sd -R <Name> <Type> <Domain> <Port> [<TXT>...]             (Register a service)
        dns-sd -B        <Type> <Domain>                     (Browse for service instances)
        dns-sd -L <Name> <Type> <Domain>                       (Resolve a service instance)
        """)
}

if CommandLine.arguments.count < 2 {
    printUsage()
    exit(0)
}

var keepRunning = true
signal(SIGINT) { _ in
    DispatchQueue.main.async {
        keepRunning = false
    }
}

switch CommandLine.arguments[1] {
case "-E":
    print("Looking for recommended registration domains:")
    let browser = NetServiceBrowser()
    let delegate = EnumerateRegistrationDomainsDelegate()
    browser.delegate = delegate
    browser.searchForRegistrationDomains()
    withExtendedLifetime([browser, delegate]) {
        while keepRunning {
            _ = RunLoop.main.run(mode: .default, before: Date.distantFuture)
        }
    }
    browser.stop()

case "-F":
    print("Looking for recommended browsing domains:")
    let browser = NetServiceBrowser()
    let delegate = EnumerateBrowsingDomainsDelegate()
    browser.delegate = delegate
    browser.searchForBrowsableDomains()
    withExtendedLifetime([browser, delegate]) {
        while keepRunning {
            _ = RunLoop.main.run(mode: .default, before: Date.distantFuture)
        }
    }
    browser.stop()

case "-R":
    let register = Array(CommandLine.arguments.dropFirst(2))
    guard register.count >= 4, let port = Int32(register[3]) else {
        printUsage()
        exit(-1)
    }
    let service = NetService(domain: register[2], type: register[1], name: register[0], port: port)
    var keyvalues = [String: Data]()
    for keyvalue in register.dropFirst(4) {
        var components = keyvalue.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        if components.count != 2 {
            print("Invalid key value pair")
            exit(-1)
        }
        keyvalues[String(components[0])] = components[1].data(using: .utf8)!
    }
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
            _ = RunLoop.main.run(mode: .default, before: Date.distantFuture)
        }
    }
    service.stop()

case "-B":
    let browse = Array(CommandLine.arguments.dropFirst(2))
    guard browse.count >= 1 else {
        printUsage()
        exit(-1)
    }
    print("Browsing for \(browse[0])")
    let browser = NetServiceBrowser()
    let delegate = BrowseServicesDelegate()
    browser.delegate = delegate
    let serviceType = browse[0]
    let domain = browse.count == 2 ? browse[1] : "local."
    browser.searchForServices(ofType: serviceType, inDomain: domain)
    withExtendedLifetime([browser, delegate]) {
        while keepRunning {
            _ = RunLoop.main.run(mode: .default, before: Date.distantFuture)
        }
    }
    browser.stop()

case "-L":
    let resolve = Array(CommandLine.arguments.dropFirst(2))
    guard resolve.count >= 2 else {
        printUsage()
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
            _ = RunLoop.main.run(mode: .default, before: Date.distantFuture)
        }
    }
    service.stop()

default:
    printUsage()
}

exit(0)
