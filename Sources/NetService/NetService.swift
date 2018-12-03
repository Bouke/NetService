import CoreFoundation

import struct Foundation.Data
import Cdns_sd

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

#if !os(Linux)
    internal let kCFSocketReadCallBack = CFSocketCallBackType.readCallBack.rawValue
    internal let kCFRunLoopCommonModes = CFRunLoopMode.commonModes
#endif

struct ServiceFlags: OptionSet {
    public let rawValue: DNSServiceFlags
    init(rawValue: DNSServiceFlags) {
        self.rawValue = rawValue
    }

    public static let add = ServiceFlags(rawValue: DNSServiceFlags(kDNSServiceFlagsAdd))
}

/// Undefined for LE
func htonl(_ value: UInt32) -> UInt32 {
    return value.byteSwapped
}
let ntohl = htonl
func htons(_ value: UInt16) -> UInt16 {
    return value.byteSwapped
}
let ntohs = htons

let _registerCallback: DNSServiceRegisterReply = { (sdRef, flags, errorCode, name, regtype, domain, context) in
    let service: NetService = Unmanaged.fromOpaque(context!).takeUnretainedValue()
    guard errorCode == kDNSServiceErr_NoError else {
        service.didNotPublish(error: NetServiceError.Unmapped(errorCode))
        return
    }
    let name = String(cString: name!)
    let flags = ServiceFlags(rawValue: flags)
    print(flags) // huh? 2 on macOS / 0 on Linux
    if flags.contains(.add) {
        service.didPublish(name: name)
    }
}

let _processResult: CFSocketCallBack = { (s, type, address, data, info) in
    let service: NetService = Unmanaged.fromOpaque(info!).takeUnretainedValue()
    service.processResult()
}


public class NetService {
    internal var fqdn: String

    private var socket: CFSocket? = nil
    private var source: CFRunLoopSource? = nil

    /// These constants specify options for a network service.
    public struct Options: OptionSet {
        public let rawValue: Int
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// Specifies that the network service should not rename itself in the event of a name collision.
        public static let noAutoRename = Options(rawValue: 1)

        /// Specifies that a TCP listener should be started for both IPv4 and IPv6 on the port specified by this service. If the listening port can't be opened, the service calls its delegate’s `netService(_:didNotPublish:)` method to report the error.
        ///
        /// The listener supports only TCP connections. <s>If the service’s type does not end with _tcp, publication fails with badArgumentError.</s>
        ///
        /// Whenever a client connects to the listening socket, the service calls its delegate’s `netService(_:didAcceptConnectionWith:outputStream:)` method with a `Socket` object.
        public static let listenForConnections = Options(rawValue: 2)
    }

    // MARK: Creating Network Services

    /// Returns the receiver, initialized as a network service of a given `type` and sets the initial host information.
    ///
    /// <s>This method is the appropriate initializer to use to resolve a service—to publish a service, use `init(domain:type:name:port:)`.
    ///
    /// If you know the values for `domain`, `type`, and `name` of the service you wish to connect to, you can create an `NetService` object using this initializer and call `resolve(withTimeout:)` on the result.</s>
    ///
    /// You cannot use this initializer to publish a service. This initializer passes an invalid port number to the designated initializer, which prevents the service from being registered. Calling `publish()` on an `NetService` object initialized with this method generates a call to your delegate’s `netService(_:didNotPublish:)` method with an badArgumentError error.
    ///
    /// - Parameters:
    ///   - domain: The domain for the service. <s>To resolve in the default domains, pass in an empty string `("")`.</s> To limit resolution to the local domain, use `"local."`.
    ///     If you are creating this object to resolve a service whose information your app stored previously, you should set this to the domain in which the service was originally discovered.
    ///     You can also use a NSNetServiceBrowser object to obtain a list of possible domains in which you can discover and resolve services.
    ///   - type: The network service type.
    ///     `type` must contain both the service type and transport layer information. To ensure that the mDNS responder searches for services, as opposed to hosts, prefix both the service name and transport layer name with an underscore character (`"_"`). For example, to search for an HTTP service on TCP, you would use the type string `"_http._tcp."`. Note that the period character at the end of the string, which indicates that the domain name is an absolute name, is required.
    ///   - name: The name of the service to resolve.
    public convenience init(domain: String, type: String, name: String) {
        self.init(domain: domain, type: type, name: name, port: -1)
    }

    /// Initializes the receiver for publishing a network service of type `type` at the socket location specified by `domain`, `name`, and `port`.
    ///
    ///
    /// You use this method to create a service that you wish to publish on the network. Although you can also use this method to create a service you wish to resolve on the network, it is generally more appropriate to use the `init(domain:type:name:)` method instead.
    ///
    /// When publishing a service, you must provide valid arguments in order to advertise your service correctly. If the host computer has access to multiple registration domains, you must create separate `NetService` objects for each domain. If you attempt to publish in a domain for which you do not have registration authority, your request may be denied.
    ///
    /// <s>It is acceptable to use an empty string for the domain argument when publishing or browsing a service, but do not rely on this for resolution.</s>
    ///
    /// This method is the designated initializer.
    ///
    /// - Parameters:
    ///   - domain: The domain for the service. <s>To use the default registration domains, pass in an empty string (`""`).</s> To limit registration to the local domain, use `"local."`.
    ///     <s>You can also use a NSNetServiceBrowser object to obtain a list of possible domains in which you can publish your service.</s>
    ///   - type: The network service type.
    ///     `type` must contain both the service type and transport layer information. To ensure that the mDNS responder searches for services, as opposed to hosts, prefix both the service name and transport layer name with an underscore character (`"_"`). For example, to search for an HTTP service on TCP, you would use the type string `"_http._tcp."`. Note that the period character at the end of the string, which indicates that the domain name is an absolute name, is required.
    ///   - name: The name by which the service is identified to the network. The name must be unique. <s>If you pass the empty string (`""`), the system automatically advertises your service using the computer name as the service name.</s>
    ///   - port: The port on which the service is published.
    ///     If you specify the `NetService.Option.listenForConnections` flag, you may pass zero (0), in which case the service automatically allocates an arbitrary (ephemeral) port for your service. When the delegate’s `netServiceDidPublish(_:)` is called, you can determine the actual port chosen by calling the service object’s `NetService` method or accessing the corresponding property.
    ///     If your app is listening for connections on its own, the value of port must be a port number acquired by your application for the service.
    public init(domain: String, type: String, name: String, port: Int32) {
        precondition(domain == "local.", "only local. domain is supported")
        precondition(type.hasSuffix("."), "type label(s) should end with a period")
        precondition(port >= -1 && port <= 65535, "Port should be in the range 0-65535")

        self.domain = domain
        self.type = type
        self.name = name
        self.port = Int(port)
        fqdn = "\(name).\(type)\(domain)"
    }

    // MARK: Configuring Network Services

    public class func data(fromTXTRecord txtDictionary: [String : Data]) -> Data {
        return txtDictionary.reduce(Data()) {
            let attr = "\($1.key)=".utf8 + $1.value
            return $0 + Data([UInt8(attr.count)]) + Data(attr)
        }
    }

    // EXTRA!
    public class func data(fromTXTRecord txtDictionary: [String : String]) -> Data {
        return txtDictionary.reduce(Data()) {
            let attr = "\($1.key)=\($1.value)".utf8
            return $0 + Data([UInt8(attr.count)]) + Data(attr)
        }
    }

    /// A read-only array containing `Socket.Address` objects, each of which contains a socket address for the service.
    ///
    /// An array containing `Socket.Address` objects, each of which contains a socket address for the service. <s>Each `Socket.Address` object in the returned array contains an appropriate sockaddr structure that you can use to connect to the socket. The exact type of this structure depends on the service to which you are connecting.</s> If no addresses were resolved for the service, the returned array contains zero elements.
    ///
    /// It is possible for a single service to resolve to more than one address or not resolve to any addresses. A service might resolve to multiple addresses if the computer publishing the service is currently multihoming.
//    public internal(set) var addresses: [Socket.Address]?

    /// A string containing the domain for this service.
    ///
    /// This can be an explicit domain name or it can contain the generic local domain name, `"local."` (note the trailing period, which indicates an absolute name).
    ///
    /// This property’s value is set when the object is first initialized, whether by your code or by a browser object. See `init(domain:type:name:)` for more information.
    public var domain: String

    /// A string containing the name of this service.
    ///
    /// This value is set when the object is first initialized, whether by your code or by a browser object. See `init(domain:type:name:)` for more information.
    public var name: String

    /// The type of the published service.
    ///
    /// This value is set when the object is first initialized, whether by your code or by a browser object. See `init(domain:type:name:)` for more information.
    public var type: String

    /// Sets the TXT record for the receiver, and returns a Boolean value that indicates whether the operation was successful.
    ///
    /// NOTE: Differs from Cocoa implementation (uses Data instead)
    public func setTXTRecord(_ recordData: Data?) -> Bool {
        textRecord = recordData

        if let serviceRef = serviceRef {
            var record = textRecord ?? Data([0])
            let error = record.withUnsafeBytes { txtRecordPtr in
                DNSServiceUpdateRecord(serviceRef, nil, 0, UInt16(record.count), txtRecordPtr, 0)
            }
            guard error == 0 else {
                return false
            }
        }

        return true
    }

    internal var serviceRef: DNSServiceRef? = nil
    internal var records: [DNSRecordRef] = []

    /// The delegate for the receiver.
    ///
    /// The delegate must conform to the `NetServiceDelegate` protocol, and is not retained.
    public weak var delegate: NetServiceDelegate?

    // MARK: Using Network Services
    var textRecord: Data? = nil

    public func publish(options: Options = []) {
        assert(serviceRef == nil, "Service already published")

        // TODO: map flags

        let flags: DNSServiceFlags = 0
        let interfaceIndex = kDNSServiceInterfaceIndexAny
        let regtype = self.type
        let domain: String? = nil
        let host: String? = nil
        var record = textRecord ?? Data([0])

        let error = record.withUnsafeBytes { txtRecordPtr in
            DNSServiceRegister(&serviceRef, flags, UInt32(interfaceIndex), name, regtype, domain, host, htons(UInt16(port)), UInt16(record.count), txtRecordPtr, _registerCallback, Unmanaged.passUnretained(self).toOpaque())
        }

        guard error == 0 else {
            delegate?.netService(self, didNotPublish: NetServiceError.Unmapped(error))
            return
        }

        let fd = DNSServiceRefSockFD(serviceRef)
        let info = Unmanaged.passUnretained(self).toOpaque()

        var context = CFSocketContext(version: 0, info: info, retain: nil, release: nil, copyDescription: nil)

        socket = CFSocketCreateWithNative(nil, fd, CFOptionFlags(kCFSocketReadCallBack), _processResult, &context)
        source = CFSocketCreateRunLoopSource(nil, socket, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes)
    }

    fileprivate func didPublish(name: String) {
        self.name = name
        delegate?.netServiceDidPublish(self)
    }

    fileprivate func didNotPublish(error: NetServiceError) {
        delegate?.netService(self, didNotPublish: error)
    }

    fileprivate func processResult() {
        DNSServiceProcessResult(serviceRef)
    }

    /// The port on which the service is listening for connections.
    ///
    /// If the object was initialized by calling `init(domain:type:name:port:)` (whether by your code or by a browser object), then the value was set when the object was first initialized.
    ///
    /// If the object was initialized by calling `init(domain:type:name:)`, the value of this property is not valid (`-1`) until after the service has successfully been resolved (when `addresses` is `non-nil`).
    public internal(set) var port: Int = -1
}
