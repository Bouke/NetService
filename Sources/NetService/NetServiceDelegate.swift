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
                    didNotPublish error: NetServiceError)

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
//    func netService(_ sender: NetService,
//                    didAcceptConnectionWith socket: Socket)
}

// MARK:- Default Implementation
public extension NetServiceDelegate {
    func netServiceWillPublish(_ sender: NetService) { }
    func netService(_ sender: NetService,
                    didNotPublish error: NetServiceError) { }
    func netServiceDidPublish(_ sender: NetService) { }
    func netServiceDidStop(_ sender: NetService) { }
//    func netService(_ sender: NetService,
//                    didAcceptConnectionWith socket: Socket) { }
}
