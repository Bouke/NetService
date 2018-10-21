// Documentation © Apple, Inc.

#if os(Linux)
    import Dispatch
#endif

import Foundation
import Cifaddrs
import DNS
import Socket

let duplicateNameCheckTimeInterval = TimeInterval(3)

// TODO: check name availability before claiming the service's name

/// The `NetService` class represents a network service, either one your application publishes or is a client of. This class and the `NetServiceBrowser` class use multicast DNS to convey information about network services to and from your application. The API of `NetService` provides a convenient way to publish the services offered by your application <s>and to resolve the socket address for a service</s>.
///
/// The types of services you access using `NetService` are the same types that you access directly using BSD sockets. HTTP and FTP are two services commonly provided by systems. (For a list of common services and the ports used by those services, see the file `/etc/services`.) Applications can also define their own custom services to provide specific data to clients.
///
/// You can use the `NetService` class as either a publisher of a service or a client of a service. If your application publishes a service, your code must acquire a port and prepare a socket to communicate with clients. Once your socket is ready, you use the `NetService` class to notify clients that your service is ready. If your application is the client of a network service, you can <s>either create an `NetService` object directly (if you know the exact host and port information) or</s> use an `NetServiceBrowser` object to browse for services.
///
/// To publish a service, initialize your `NetService` object with the service name, domain, type, and port information. All of this information must be valid for the socket created by your application. Once initialized, call the `publish()` method to broadcast your service information to the network.
///
/// When connecting to a service, use the `NetServiceBrowser` class to locate the service on the network and obtain the corresponding `NetService` object. <s>Once you have the object, call the `resolve(withTimeout:)` method to verify that the service is available and ready for your application.</s> If it is, the `addresses` property provides the socket information you can use to connect to the service.
///
/// The methods of `NetService` operate asynchronously so your application is not impacted by the speed of the network. All information about a service is returned to your application through the `NetService` object’s delegate. You must provide a delegate object to respond to messages and to handle errors appropriately.
public class NetService: Listener {

    internal var fqdn: String

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

    /// A read-only array containing `Socket.Address` objects, each of which contains a socket address for the service.
    ///
    /// An array containing `Socket.Address` objects, each of which contains a socket address for the service. <s>Each `Socket.Address` object in the returned array contains an appropriate sockaddr structure that you can use to connect to the socket. The exact type of this structure depends on the service to which you are connecting.</s> If no addresses were resolved for the service, the returned array contains zero elements.
    ///
    /// It is possible for a single service to resolve to more than one address or not resolve to any addresses. A service might resolve to multiple addresses if the computer publishing the service is currently multihoming.
    public internal(set) var addresses: [Socket.Address]?

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
    public func setTXTRecord(_ recordData: [String: String]?) -> Bool {
        guard let recordData = recordData else {
            textRecord = nil
            return false
        }
        textRecord = TextRecord(name: fqdn, ttl: 120, attributes: recordData)
        return true
    }

    /// The delegate for the receiver.
    ///
    /// The delegate must conform to the `NetServiceDelegate` protocol, and is not retained.
    public weak var delegate: NetServiceDelegate?

    // MARK: Using Network Services
    var listenQueue: DispatchQueue?
    var socket4: Socket?
    var socket6: Socket?

    var responder: Responder?
    var pointerRecord: PointerRecord?
    var serviceRecord: ServiceRecord?
    var hostRecords: [ResourceRecord]?
    var textRecord: TextRecord?

    enum PublishState: Equatable {
        case stopped
        case lookingForDuplicates(Int, Timer)
        case published
        case didNotPublish(Error)

        static func == (lhs: PublishState, rhs: PublishState) -> Bool {
            switch (lhs, rhs) {
            case (.stopped, .stopped), (.published, .published): return true
            case (.lookingForDuplicates, .lookingForDuplicates): return true
            default: return false
            }
        }
    }
    var publishState: PublishState = .stopped

    /// Attempts to advertise the receiver on the network, with the given options.
    ///
    /// This method returns immediately, with success or failure indicated by the callbacks to the delegate.
    /// - Parameter options: Options for the receiver. The supported options are described in `NetService.Options`.
    public func publish(options: Options = []) {
        precondition(publishState == .stopped, "invalid state, should be .stopped")
        precondition(port >= 0, "port should be >= 0")

        do {
            responder = try Responder.shared()
        } catch {
            return publishError(error)
        }
        hostName = responder!.hostname

        // TODO: support ipv6
        // TODO: auto rename
        // TODO: support noAutoRename option

        delegate?.netServiceWillPublish(self)

        if !options.contains(.noAutoRename) {
            // check if name is taken -- allow others a few seconds to respond

            responder!.listeners.append(self)
            do {
                try responder!.multicast(message: Message(type: .query, questions: [Question(name: fqdn, type: .service)]))
            } catch {
                return publishError(error)
            }
            // TODO: remove listener

            let timer = Timer._scheduledTimer(withTimeInterval: duplicateNameCheckTimeInterval, repeats: false, block: {_ in self.publishPhaseTwo()})
            publishState = .lookingForDuplicates(1, timer)
        }

        if options.contains(.listenForConnections) {
            precondition(type.hasSuffix("._tcp."), "only listening on TCP is supported")

            listenQueue = DispatchQueue.global(qos: .userInteractive)

            do {
                socket4 = try Socket.create(family: .inet, type: .stream, proto: .tcp)
                try socket4!.listen(on: self.port)
                self.port = Int(socket4!.signature!.port)

                socket6 = try Socket.create(family: .inet6, type: .stream, proto: .tcp)
                try socket6!.listen(on: self.port)
            } catch {
                publishError(error)
            }

            listenQueue!.async { [unowned self] in
                while true {
                    do {
                        let responderSocket = try self.socket4!.acceptClientConnection()
                        self.delegate?.netService(self, didAcceptConnectionWith: responderSocket)
                    } catch {
                        self.publishError(error)
                        break
                    }
                }
            }
            listenQueue!.async { [unowned self] in
                while true {
                    do {
                        let responderSocket = try self.socket6!.acceptClientConnection()
                        self.delegate?.netService(self, didAcceptConnectionWith: responderSocket)
                    } catch {
                        self.publishError(error)
                        break
                    }
                }
            }
        }

        if options.contains(.noAutoRename) {
            publishPhaseTwo()
        }
    }

    func publishPhaseTwo() {
        precondition(port > 0, "Port not configured")

        if let index = responder!.listeners.index(where: {$0 === self }) {
            responder!.listeners.remove(at: index)
        }

        addresses = responder!.addresses.map {
            var address = $0
            address.port = UInt16(self.port)
            return address
        }
        pointerRecord = PointerRecord(name: "\(type)\(domain)", ttl: 4500, destination: fqdn)
        serviceRecord = ServiceRecord(name: fqdn, ttl: 120, port: UInt16(port), server: hostName!)
        textRecord?.name = fqdn

        // broadcast availability
        do {
            try responder!.publish(self)
        } catch {
            return publishError(error)
        }

        publishState = .published
        delegate?.netServiceDidPublish(self)
    }

    func publishError(_ error: Error) {
        if case .lookingForDuplicates(let (_, timer)) = publishState {
            timer.invalidate()
        }
        publishState = .didNotPublish(error)
        delegate?.netService(self, didNotPublish: error)
    }

    func received(message: Message) {
        guard case .lookingForDuplicates(let (number, timer)) = publishState else { return }

      if message.answers.compactMap({ $0 as? ServiceRecord }).contains(where: { $0.name == fqdn }) {
            timer.invalidate()

            fqdn = "\(name) (\(number + 1)).\(type)\(domain)"
            do {
                try responder!.multicast(message: Message(type: .query, questions: [Question(name: fqdn, type: .service)]))
            } catch {
                return publishError(error)
            }
            let timer = Timer._scheduledTimer(withTimeInterval: duplicateNameCheckTimeInterval, repeats: false, block: {_ in
                self.name = "\(self.name) (\(number + 1))"
                self.publishPhaseTwo()
            })
            publishState = .lookingForDuplicates(number + 1, timer)
        }
    }

    /// NOT IMPLEMENTED. <s>Starts a resolve process of a finite duration for the service.
    ///
    /// During the resolve period, the service sends `netServiceDidResolveAddress(_:)` to the delegate for each address it discovers that matches the service parameters. Once the timeout is hit, the service sends `netServiceDidStop(_:)` to the delegate. If no addresses resolve during the timeout period, the service sends `netService(_:didNotResolve:)` to the delegate.</s>
    ///
    /// - Parameter timeout: The maximum number of seconds to attempt a resolve. A value of 0.0 indicates no timeout and a resolve process of indefinite duration.
    public func resolve(withTimeout timeout: TimeInterval) {
        preconditionFailure("Not implemented")
    }

    /// The port on which the service is listening for connections.
    ///
    /// If the object was initialized by calling `init(domain:type:name:port:)` (whether by your code or by a browser object), then the value was set when the object was first initialized.
    ///
    /// If the object was initialized by calling `init(domain:type:name:)`, the value of this property is not valid (`-1`) until after the service has successfully been resolved (when `addresses` is `non-nil`).
    public internal(set) var port: Int = -1

    /// NOT IMPLEMENTED. <s>Starts the monitoring of TXT-record updates for the receiver.
    ///
    /// The delegate must implement `netService(_:didUpdateTXTRecord:)`, which is called when the TXT record for the receiver is updated.</s>
    func startMonitoring() {
        preconditionFailure("Not implemented")
    }

    /// Halts a currently running attempt to publish or resolve a service.
    ///
    /// The delegate will receive `netServiceDidStop(_:)` after the service stops.
    /// <s>It is safe to remove all strong references to the service immediately after calling `stop()`.</s>
    public func stop() {
        switch publishState {
        case .stopped:
            break
        case .lookingForDuplicates(let (_, timer)):
            timer.invalidate()
        case .published:
            try! responder!.unpublish(self)
        case .didNotPublish:
            break
        }
        publishState = .stopped
        delegate?.netServiceDidStop(self)
    }

    /// NOT IMPLEMENTED. <s>Stops the monitoring of TXT-record updates for the receiver.</s>
    func stopMonitoring() {
        preconditionFailure("Not implemented")
    }

    // MARK: Obtaining the DNS Hostname

    /// A string containing the DNS hostname for this service.
    ///
    /// This value is `nil` until the service has been resolved (when `addresses` is non-nil).
    public internal(set) var hostName: String?
}

extension NetService: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "NetService(domain: \(domain), type: \(type), name: \(name), port: \(port), hostName: \(String(describing: hostName))), addresses: \(String(describing: addresses)))"
    }
}

/// The `NetServiceDelegate` protocol defines the optional methods implemented by delegates of `NetService` objects.
public protocol NetServiceDelegate: class {

    // MARK: Using Network Services

    /// Notifies the delegate that the network is ready to publish the service.
    ///
    /// Publication of the service proceeds asynchronously and may still generate a call to the delegate’s `netService(_:didNotPublish:)` method if an error occurs.
    ///
    /// - Parameter sender: The service that is ready to publish.
    func netServiceWillPublish(_ sender: NetService)

    /// Notifies the delegate that a service could not be published.
    ///
    /// This method may be called long after a `netServiceWillPublish(_:)` message has been delivered to the delegate.
    ///
    /// - Parameters:
    ///   - sender: The service that could not be published.
    ///   - error: An `Error` containing information about the problem. <s>The dictionary contains the keys NSNetServicesErrorCode and NSNetServicesErrorDomain.</s>
    func netService(_ sender: NetService,
                    didNotPublish error: Error)

    /// Notifies the delegate that a service was successfully published.
    ///
    /// - Parameter sender: The service that was published.
    func netServiceDidPublish(_ sender: NetService)

    /// Notifies the delegate that the network is ready to resolve the service.
    ///
    /// Resolution of the service proceeds asynchronously and may still generate a call to the delegate’s `netService(_:didNotResolve:)` method if an error occurs.
    ///
    /// - Parameter sender: The service that the network is ready to resolve.
//    func netServiceWillResolve(_ sender: NetService)

    /// Informs the delegate that an error occurred during resolution of a given service.
    ///
    /// Clients may try to resolve again upon receiving this error. For example, a DNS rotary may yield different IP addresses on different resolution requests. A common error condition is that no addresses were resolved during the timeout period specified in `resolve(withTimeout:)`.
    ///
    /// - Parameters:
    ///   - sender: The service that did not resolve.
    ///   - error: An `Error` containing information about the problem. <s>The dictionary contains the keys errorCode and errorDomain.</s>
//    func netService(_ sender: NetService, didNotResolve error: Error)

    /// Informs the delegate that the address for a given service was resolved.
    ///
    /// The delegate can use the `addresses` method to retrieve the service’s address. If the delegate needs only one address, it can stop the resolution process using `stop()`. Otherwise, the resolution will continue until the timeout specified in `resolve(withTimeout:)` is reached.
    ///
    /// - Parameter sender: The service that was resolved.
//    func netServiceDidResolveAddress(_ sender: NetService)

    /// Notifies the delegate that the TXT record for a given service has been updated.
    ///
    /// - Parameters:
    ///   - sender: The service whose TXT record was updated.
    ///   - data: The new TXT record.
//    func netService(_ sender: NetService, didUpdateTXTRecord data: Data)

    /// Informs the delegate that a publish() or resolve(withTimeout:) request was stopped.
    ///
    /// - Parameter sender: The service that stopped.
    func netServiceDidStop(_ sender: NetService)

    // MARK: Accepting Connections

    /// Called when a client connects to a service managed by NetService.
    ///
    /// When you publish a service, if you set the `listenForConnections` flag in the service options, the service object accepts connections on behalf of your app. Later, when a client connects to that service, the service object calls this method to provide the app with a pair of streams for communicating with that client.
    ///
    /// - Parameters:
    ///   - sender: The net service object that the client connected to.
    ///   - socket: A `Socket` object for sending and receiving data to and from the client.
    func netService(_ sender: NetService,
                    didAcceptConnectionWith socket: Socket)
}
