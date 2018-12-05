import CoreFoundation
import Cdns_sd

#if !os(Linux)
    internal let kCFSocketReadCallBack = CFSocketCallBackType.readCallBack.rawValue
    internal let kCFRunLoopCommonModes = CFRunLoopMode.commonModes
#endif

struct ServiceFlags: OptionSet {
    public let rawValue: DNSServiceFlags
    init(rawValue: DNSServiceFlags) {
        self.rawValue = rawValue
    }

    public static let moreComing = ServiceFlags(rawValue: DNSServiceFlags(kDNSServiceFlagsMoreComing))
    public static let add = ServiceFlags(rawValue: DNSServiceFlags(kDNSServiceFlagsAdd))
}
