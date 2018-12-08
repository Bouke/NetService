import struct Foundation.Date
import class Foundation.DateFormatter
import class Foundation.NSNumber
import NetService

class BaseDelegate {
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

    func starting() {
        print("DATE: ---\(date())---")
        print("\(time())  ...STARTING...")
    }

    //MARK:- NetServiceBrowserDelegate

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        print("Did not search: \(errorDict)")
    }

    //MARK:- NetServiceDelegate

    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
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
