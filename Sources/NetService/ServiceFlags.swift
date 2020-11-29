import CoreFoundation
import Cdns_sd

struct ServiceFlags: OptionSet {
    public let rawValue: DNSServiceFlags
    init(rawValue: DNSServiceFlags) {
        self.rawValue = rawValue
    }

    public static let moreComing = ServiceFlags(rawValue: DNSServiceFlags(kDNSServiceFlagsMoreComing))
    public static let add = ServiceFlags(rawValue: DNSServiceFlags(kDNSServiceFlagsAdd))
    public static let browseDomains = ServiceFlags(rawValue: DNSServiceFlags(kDNSServiceFlagsBrowseDomains))
    public static let registrationDomains = ServiceFlags(rawValue: DNSServiceFlags(kDNSServiceFlagsRegistrationDomains))
}
