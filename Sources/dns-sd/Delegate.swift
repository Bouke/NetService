import struct Foundation.Data
import struct Foundation.Date
import class Foundation.DateFormatter
import class Foundation.NSNumber

#if os(macOS)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif

#if USE_FOUNDATION
    import Foundation
    class _BaseDelegate: NSObject { }
#else
    import NetService
    class _BaseDelegate { init() { } }
#endif

class BaseDelegate: _BaseDelegate {
    let timeFormatter = DateFormatter()
    let dateFormatter = DateFormatter()

    override init() {
        timeFormatter.dateFormat = "HH:mm:ss.sss"
        dateFormatter.dateStyle = .full
    }

    func time() -> String {
        return timeFormatter.string(from: Date())
    }

    func date() -> String {
        return dateFormatter.string(from: Date())
    }

    func starting() {
        print("DATE: ---\(date())---")
        print("\(time())  ...STARTING...")
    }

    // MARK: - NetServiceBrowserDelegate

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        print("Did not search: \(errorDict)")
    }

    // MARK: - NetServiceDelegate

    func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        print("DNSService call failed \(errorDict)")
    }
}

class EnumerateRegistrationDomainsDelegate: BaseDelegate, NetServiceBrowserDelegate {
    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        starting()
        print("Timestamp     Recommended Registration domain")
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFindDomain domainString: String, moreComing: Bool) {
        print(time() + "  " +
            "Added                     " +
            domainString.leftPadding(toLength: 11, withPad: " "))
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemoveDomain domainString: String, moreComing: Bool) {
        print(time() + "  " +
            "Removed                   " +
            domainString.leftPadding(toLength: 11, withPad: " "))
    }
}

class EnumerateBrowsingDomainsDelegate: BaseDelegate, NetServiceBrowserDelegate {
    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        starting()
        print("Timestamp     Recommended Browsing domain")
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFindDomain domainString: String, moreComing: Bool) {
        print(time() + "  " +
            "Added                     " +
            domainString.leftPadding(toLength: 11, withPad: " "))
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemoveDomain domainString: String, moreComing: Bool) {
        print(time() + "  " +
            "Removed                   " +
            domainString.leftPadding(toLength: 11, withPad: " "))
    }
}

class BrowseServicesDelegate: BaseDelegate, NetServiceBrowserDelegate {
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
        starting()
        print("Timestamp     A/R    Flags  if Domain               Service Type         Instance Name")
    }
}

class RegisterServiceDelegate: BaseDelegate, NetServiceDelegate {
    func netServiceWillPublish(_ sender: NetService) {
        starting()
    }

    func netServiceDidPublish(_ sender: NetService) {
        print("\(time())  Got a reply for service \(sender.name).\(sender.type).\(sender.domain): Name now registered and active")
    }
}

class ResolveServiceDelegate: BaseDelegate, NetServiceDelegate {
    func netServiceWillResolve(_ sender: NetService) {
        starting()
    }
    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        print("DNSService call failed \(errorDict)")
    }
    func netServiceDidResolveAddress(_ sender: NetService) {
        let addresses = sender.addresses.map(presentation)?.joined(separator: ", ") ?? "N/A"
        print("\(time()) \(sender.name) can be reached at \(addresses) (interface ?)")
        if let txtRecord = sender.txtRecordData() {
            let txtDictionary = NetService.dictionary(fromTXTRecord: txtRecord).map {
                ($0, String(data: $1, encoding: .utf8)!)
            }
            print(" \(Dictionary(uniqueKeysWithValues: txtDictionary))")
        }
    }
    func presentation(_ addresses: [Data]) -> [String] {
        var p = [String]()
        for memory in addresses {
            var ss = sockaddr_storage()
            _ = memory.withUnsafeBytes {
                memcpy(&ss, $0.baseAddress!, memory.count)
            }
            let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: Int(NI_MAXHOST))

            let sa_len: Int
            switch ss.ss_family {
            case sa_family_t(AF_INET): sa_len = MemoryLayout<sockaddr_in>.size
            case sa_family_t(AF_INET6): sa_len = MemoryLayout<sockaddr_in6>.size
            default: continue
            }

            _ = withUnsafePointer(to: &ss) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    getnameinfo($0, socklen_t(sa_len), buffer, socklen_t(NI_MAXHOST), nil, 0, NI_NUMERICHOST)
                }
            }
            p.append(String(cString: buffer))
        }
        return p
    }
}
