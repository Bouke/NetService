// Documentation © Apple, Inc.

import CoreFoundation

import struct Foundation.Data
import class Foundation.InputStream
import class Foundation.OutputStream
import class Foundation.NSNumber
import class Foundation.RunLoop
#if os(Linux) && !compiler(>=5.0)
import struct Foundation.RunLoopMode
#endif
import struct Foundation.TimeInterval

import Cdns_sd

private let _registerCallback: DNSServiceRegisterReply = { (_, flags, errorCode, name, _, _, context) in
    let service: NetService = Unmanaged.fromOpaque(context!).takeUnretainedValue()
    guard errorCode == kDNSServiceErr_NoError else {
        service.didNotPublish(error: Int(errorCode))
        return
    }
    let name = String(cString: name!)
    let flags = ServiceFlags(rawValue: flags)
    #if os(Linux)
        // Avahi targets an older version of dns_sd and doesn't pass in flags,
        // see also: https://github.com/lathiat/avahi/issues/207.
        service.didPublish(name: name)
    #else
        if flags.contains(.add) {
            service.didPublish(name: name)
        }
    #endif
}

private let _resolveReply: DNSServiceResolveReply = { _, _, _, errorCode, _, hosttarget, port, txtLen, txtRecord, context in
    let service: NetService = Unmanaged.fromOpaque(context!).takeUnretainedValue()
    guard errorCode == kDNSServiceErr_NoError else {
        service.didNotResolve(error: Int(errorCode))
        return
    }
    let hosttarget = String(cString: hosttarget!)
    let port = UInt16(bigEndian: port)
    let textRecord = txtRecord.map { Data(bytes: $0, count: Int(txtLen)) }
    service.didResolveAddress(
        host: hosttarget,
        port: port,
        textRecord: textRecord)
}

private let _processResult: CFSocketCallBack = { (_, _, _, _, info) in
    let service: NetService = Unmanaged.fromOpaque(info!).takeUnretainedValue()
    service.processResult()
}

public class NetService {
    private var fqdn: String

    private var serviceRef: DNSServiceRef?
    private var records: [DNSRecordRef] = []
    private var textRecord: Data?
    private var socket: CFSocket?
    private var source: CFRunLoopSource?

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
        precondition(port >= -1 && port <= 65535, "Port should be in the range 0-65535")

        self.domain = domain
        self.type = type
        self.name = name
        self.port = Int(port)
        fqdn = "\(name).\(type)\(domain)"
    }

    // MARK: Configuring Network Services

    /// Returns an NSData object representing a TXT record formed from a given dictionary.
    ///
    /// - Parameters:
    ///   - txtDictionary: A dictionary containing a TXT record.
    ///
    /// - Return Value:
    ///   An NSData object representing TXT data formed from txtDictionary. Fails an assertion if txtDictionary cannot be represented as an NSData object.
    public class func data(fromTXTRecord txtDictionary: [String: Data]) -> Data {
        return txtDictionary.reduce(Data()) {
            let attr = "\($1.key)=".utf8 + $1.value
            return $0 + Data([UInt8(attr.count)]) + Data(attr)
        }
    }

    /// Returns a dictionary representing a TXT record given as an NSData object.
    ///
    /// - Parameters:
    ///   - txtData: A data object encoding a TXT record.
    ///
    /// - Return Value:
    /// A dictionary representing txtData. The dictionary’s keys are NSString objects using UTF8 encoding. The values associated with all the dictionary’s keys are NSData objects that encapsulate strings or data.
    ///
    /// Fails an assertion if txtData cannot be represented as an NSDictionary object.
    public class func dictionary(fromTXTRecord txtData: Data) -> [String: Data] {
        var txtDictionary: [String: Data] = [:]
        var position = 0
        while position < txtData.count {
            let size = Int(txtData[position])
            position += 1
            if position + size >= txtData.count { break }
            guard let label = String(bytes: txtData[position..<position+size], encoding: .utf8) else { break }
            position += size
            let parts = label.split(separator: "=", maxSplits: 1)
            assert(parts.count == 2, "Only key=value parts are supported")
            txtDictionary[String(parts[0])] = parts[1].data(using: .utf8)
        }
        return txtDictionary
    }

    /// A read-only array containing `NSData` objects, each of which contains a socket address for the service.
    ///
    /// An array containing `Socket.Address` objects, each of which contains a socket address for the service. <s>Each `NSData` object in the returned array contains an appropriate sockaddr structure that you can use to connect to the socket. The exact type of this structure depends on the service to which you are connecting.</s> If no addresses were resolved for the service, the returned array contains zero elements.
    ///
    /// It is possible for a single service to resolve to more than one address or not resolve to any addresses. A service might resolve to multiple addresses if the computer publishing the service is currently multihoming.
    public internal(set) var addresses: [Data]?

    /// A string containing the domain for this service.
    ///
    /// This can be an explicit domain name or it can contain the generic local domain name, `"local."` (note the trailing period, which indicates an absolute name).
    ///
    /// This property’s value is set when the object is first initialized, whether by your code or by a browser object. See `init(domain:type:name:)` for more information.
    public var domain: String

    /// Specifies whether to also publish, resolve, or monitor this service over peer-to-peer Bluetooth and Wi-Fi, if available. `false` by default.
    ///
    /// This property must be set before calling `publish()` or `publish(options:)`, `resolve(withTimeout:)`, or `startMonitoring()` in order to take effect.
    ///
    /// Not implemented.
    public var includesPeerToPeer: Bool {
        get { NSUnimplemented() }
        // swiftlint:disable:next unused_setter_value
        set { NSUnimplemented() }
    }

    /// Creates a pair of input and output streams for the receiver and returns a Boolean value that indicates whether they were retrieved successfully.
    ///
    /// - Parameters:
    ///   - inputStream: Upon return, the input stream for the receiver. Pass NULL if you do not need this stream.
    ///   - outputStream: Upon return, the output stream for the receiver. Pass NULL if you do not need this stream.
    ///
    /// - Return Value:
    /// true if the streams are created successfully, otherwise `false`.
    ///
    /// - Discussion:
    /// After this method is called, no delegate callbacks are called by the receiver.
    ///
    /// - Note:
    /// If automatic reference counting is not used, the input and output streams returned through the parameters are <s>retained</s>, which means that you are responsible for releasing them to avoid memory leaks.
    func getInputStream(_ inputStream: UnsafeMutablePointer<InputStream?>?, outputStream: UnsafeMutablePointer<OutputStream?>?) -> Bool {
        NSUnimplemented()
    }

    /// A string containing the name of this service.
    ///
    /// This value is set when the object is first initialized, whether by your code or by a browser object. See `init(domain:type:name:)` for more information.
    public var name: String

    /// The type of the published service.
    ///
    /// This value is set when the object is first initialized, whether by your code or by a browser object. See `init(domain:type:name:)` for more information.
    public var type: String

    /// Returns the TXT record for the receiver.
    public func txtRecordData() -> Data? {
        return textRecord
    }

    /// Sets the TXT record for the receiver, and returns a Boolean value that indicates whether the operation was successful.
    ///
    /// - Parameters:
    ///   - recordData: The TXT record for the receiver.
    ///
    /// - Return Value:
    /// `true` if `recordData` is successfully set as the TXT record, otherwise `false`.
    public func setTXTRecord(_ recordData: Data?) -> Bool {
        textRecord = recordData
        if let serviceRef = serviceRef {
            let record = textRecord ?? Data([0])
            let error = record.withUnsafeBytes { txtRecordPtr in
                DNSServiceUpdateRecord(serviceRef, nil, 0, UInt16(record.count), txtRecordPtr.baseAddress!, 0)
            }
            guard error == 0 else {
                return false
            }
        }
        return true
    }

    /// The delegate for the receiver.
    ///
    /// The delegate must conform to the `NetServiceDelegate` protocol, and is not retained.
    public weak var delegate: NetServiceDelegate?

    // MARK: Managing Run Loops

    /// Adds the service to the specified run loop.
    ///
    /// - Parameters:
    ///   - aRunLoop: The run loop to which to add the receiver.
    ///   - mode: The run loop mode to which to add the receiver. Possible values for mode are discussed in the "Constants" section of RunLoop.
    ///
    /// You can use this method in conjunction with remove(from:forMode:) to transfer a service to a different run loop. You should not attempt to run a service on multiple run loops.
    ///
    /// Not implemented.
    public func schedule(in aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {
        NSUnimplemented()
    }

    /// Removes the service from the given run loop for a given mode.
    ///
    /// - Parameters
    ///   - aRunLoop: The run loop from which to remove the receiver.
    ///   - mode: The run loop mode from which to remove the receiver. Possible values for mode are discussed in the "Constants" section of RunLoop.
    ///
    /// You can use this method in conjunction with schedule(in:forMode:) to transfer the service to a different run loop. Although it is possible to remove an NSNetService object completely from any run loop and then attempt actions on it, it is an error to do so.
    ///
    /// Not implemented.
    public func remove(from aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {
        NSUnimplemented()
    }

    // MARK: Using Network Services

    /// Attempts to advertise the receiver’s on the network.
    ///
    /// This method returns immediately, with success or failure indicated by the callbacks to the delegate. This is equivalent to calling `publish(options:)` with the default options (`0`).
    public func publish() {
        publish(options: [])
    }

    /// Attempts to advertise the receiver on the network, with the given options.
    ///
    /// - Parameters:
    ///   - serviceOptions: Options for the receiver. The supported options are described in NetService.Options.
    ///
    /// - Discussion:
    /// This method returns immediately, with success or failure indicated by the callbacks to the delegate.
    public func publish(options: Options) {
        guard serviceRef == nil else {
            return didNotPublish(error: ErrorCode.activityInProgress.rawValue)
        }

        guard port > 0 || options.contains(.listenForConnections) else {
            return didNotPublish(error: ErrorCode.badArgumentError.rawValue)
        }

        if options.contains(.noAutoRename) || options.contains(.listenForConnections) {
            NSUnimplemented("")
        }

        delegate?.netServiceWillPublish(self)

        // TODO: map flags

        let regtype = self.type
        let record = textRecord ?? Data([0])

        let error = record.withUnsafeBytes { txtRecordPtr in
            DNSServiceRegister(&serviceRef, 0, 0, name, regtype, nil, nil, UInt16(port).bigEndian, UInt16(record.count), txtRecordPtr.baseAddress!, _registerCallback, Unmanaged.passUnretained(self).toOpaque())
        }
        guard error == 0 else {
            didNotPublish(error: Int(error))
            return
        }
        start()
    }

    /// Starts a resolve process for the service.
    ///
    /// - Deprecated:
    /// Use resolve(withTimeout:) instead.
    ///
    /// Discussion
    /// Attempts to determine at least one address for the service. This method returns immediately, with success or failure indicated by the callbacks to the delegate.
    ///
    /// In OS X v10.4, this method calls `resolve(withTimeout:)` with a timeout value of 5.
    @available(*, deprecated)
    public func resolve() {
        resolve(withTimeout: 5)
    }

    /// Starts a resolve process of a finite duration for the service.
    ///
    /// - Parameters:
    ///   - timeout: The maximum number of seconds to attempt a resolve. A value of 0.0 indicates no timeout and a resolve process of indefinite duration.
    ///
    /// - Discussion:
    /// During the resolve period, the service sends `netServiceDidResolveAddress(_:)` to the delegate for each address it discovers that matches the service parameters. Once the timeout is hit, the service sends `netServiceDidStop(_:)` to the delegate. If no addresses resolve during the timeout period, the service sends `netService(_:didNotResolve:)` to the delegate.
    ///
    /// TODO: implement timeout!
    public func resolve(withTimeout timeout: TimeInterval) {
        guard serviceRef == nil else {
            return didNotResolve(error: ErrorCode.activityInProgress.rawValue)
        }

        delegate?.netServiceWillResolve(self)

        let error = DNSServiceResolve(&serviceRef, 0, 0, name, type, domain, _resolveReply, Unmanaged.passUnretained(self).toOpaque())
        guard error == 0 else {
            didNotResolve(error: Int(error))
            return
        }
        start()
    }

    func start() {
        let fd = DNSServiceRefSockFD(serviceRef)
        let info = Unmanaged.passUnretained(self).toOpaque()

        var context = CFSocketContext(version: 0, info: info, retain: nil, release: nil, copyDescription: nil)

        socket = CFSocketCreateWithNative(nil, fd, CFOptionFlags(kCFSocketReadCallBack), _processResult, &context)

        // Don't close the underlying socket on invalidate, as it is owned by dns_sd.
        var socketFlags = CFSocketGetSocketFlags(socket)
        socketFlags &= ~CFOptionFlags(kCFSocketCloseOnInvalidate)
        CFSocketSetSocketFlags(socket, socketFlags)

        source = CFSocketCreateRunLoopSource(nil, socket, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, CFRunLoopMode.commonModes)
    }

    /// The port on which the service is listening for connections.
    ///
    /// If the object was initialized by calling `init(domain:type:name:port:)` (whether by your code or by a browser object), then the value was set when the object was first initialized.
    ///
    /// If the object was initialized by calling `init(domain:type:name:)`, the value of this property is not valid (`-1`) until after the service has successfully been resolved (when `addresses` is `non-nil`).
    public internal(set) var port: Int = -1

    /// Starts the monitoring of TXT-record updates for the receiver.
    ///
    /// - Discussion:
    /// The delegate must implement `netService(_:didUpdateTXTRecord:)`, which is called when the TXT record for the receiver is updated.
    public func startMonitoring() {
        NSUnimplemented()
    }

    public func stop() {
        assert(serviceRef != nil, "Service already stopped")
        CFRunLoopSourceInvalidate(source)
        CFSocketInvalidate(socket)
        DNSServiceRefDeallocate(serviceRef)
        delegate?.netServiceDidStop(self)
    }

    /// Stops the monitoring of TXT-record updates for the receiver.
    public func stopMonitoring() {
        NSUnimplemented()
    }

    // MARK: Using Network Services

    /// A string containing the DNS hostname for this service.
    ///
    /// - Discussion:
    /// This value is `nil` until the service has been resolved (when `addresses` is non-nil).
    public internal(set) var hostName: String?

    // MARK: Constants

    /// NSNetServices Errors
    ///
    /// If an error occurs, the delegate error-handling methods return a dictionary with the following keys.

    /// This key identifies the error that occurred during the most recent operation.
    public static let errorCode = "NSNetServicesErrorCode"

    /// This key identifies the originator of the error, which is either the `NSNetService` object or the mach network layer. For most errors, you should not need the value provided by this key.
    public static let errorDomain = "NSNetServicesErrorDomain"

    /// These constants identify errors that can occur when accessing net services.
    public enum ErrorCode: Int {
        /// An unknown error occurred.
        case unknownError = -72000

        /// The service could not be published because the name is already in use. The name could be in use locally or on another system.
        case collisionError = -72001

        /// The service could not be found on the network.
        case notFoundError = -72002

        /// The net service cannot process the request at this time. No additional information about the network state is known.
        case activityInProgress = -72003

        /// An invalid argument was used when creating the `NSNetService` object.
        case badArgumentError = -72004

        /// The client canceled the action.
        case cancelledError = -72005

        /// The net service was improperly configured.
        case invalidError = -72006

        /// The net service has timed out.
        case timeoutError = -72007
    }

    /// These constants specify options for a network service.
    public struct Options: OptionSet {
        public let rawValue: Int
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// Specifies that the network service should not rename itself in the event of a name collision.
        ///
        /// Not implemented.
        public static let noAutoRename = Options(rawValue: 1)

        /// Specifies that a TCP listener should be started for both IPv4 and IPv6 on the port specified by this service. If the listening port can't be opened, the service calls its delegate’s `netService(_:didNotPublish:)` method to report the error.
        ///
        /// The listener supports only TCP connections. <s>If the service’s type does not end with _tcp, publication fails with badArgumentError.</s>
        ///
        /// Whenever a client connects to the listening socket, the service calls its delegate’s `netService(_:didAcceptConnectionWith:outputStream:)` method with a `Socket` object.
        ///
        /// Not implemented.
        public static let listenForConnections = Options(rawValue: 2)
    }

    // MARK: - Internal

    fileprivate func didPublish(name: String) {
        self.name = name
        delegate?.netServiceDidPublish(self)
    }

    fileprivate func didNotPublish(error: Int) {
        delegate?.netService(self, didNotPublish: [
            NetService.errorDomain: NSNumber(value: 10),
            NetService.errorCode: NSNumber(value: error)
        ])
    }

    fileprivate func didNotResolve(error: Int) {
        delegate?.netService(self, didNotResolve: [
            NetService.errorDomain: NSNumber(value: 10),
            NetService.errorCode: NSNumber(value: error)
        ])
    }

    fileprivate func didResolveAddress(host: String, port: UInt16, textRecord: Data?) {
        self.hostName = host
        self.port = Int(port)
        self.textRecord = textRecord

        // resolve hostname
        var res: UnsafeMutablePointer<addrinfo>?
        let error = getaddrinfo(host, "\(port)", nil, &res)
        guard error == 0 else {
            didNotResolve(error: -1)
            return
        }
        defer {
            freeaddrinfo(res)
        }
        var addresses = [Data]()
        for addr in sequence(first: res!, next: { $0.pointee.ai_next }) {
            addresses.append(Data(bytes: addr.pointee.ai_addr, count: Int(addr.pointee.ai_addrlen)))
        }
        self.addresses = addresses
        delegate?.netServiceDidResolveAddress(self)
    }

    fileprivate func processResult() {
        DNSServiceProcessResult(serviceRef)
    }
}
