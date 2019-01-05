import class Foundation.NSNumber

/// The `NetServiceBrowserDelegate` protocol defines the optional methods implemented by delegates of `NetServiceBrowser` objects.
public protocol NetServiceBrowserDelegate: class {
    /// Tells the delegate the sender found a domain.
    ///
    /// The delegate uses this message to compile a list of available domains. It should wait until `moreComing` is `false` to do a bulk update of user interface elements.
    ///
    /// - Parameters:
    ///   - browser: Sender of this delegate message.
    ///   - domainString: Name of the domain found by `browser`.
    ///   - moreComing: `true` when `browser` is waiting for additional domains. `false` when there are no additional domains.
    func netServiceBrowser(_ browser: NetServiceBrowser,
                           didFindDomain domainString: String,
                           moreComing: Bool)

    /// Tells the delegate the a domain has disappeared or has become unavailable.
    ///
    /// The delegate uses this message to compile a list of unavailable domains. It should wait until `moreComing` is `false` to do a bulk update of user interface elements.
    ///
    /// - Parameters:
    ///   - browser: Sender of this delegate message.
    ///   - domainString: Name of the domain that became unavailable.
    ///   - moreComing: `true` when `browser` is waiting for additional domains. `false` when there are no additional domains.
    func netServiceBrowser(_ browser: NetServiceBrowser,
                           didRemoveDomain domainString: String,
                           moreComing: Bool)

    /// Tells the delegate the sender found a service.
    ///
    /// #### Discussion
    /// The delegate uses this message to compile a list of available services. It should wait until moreServicesComing is `false` to do a bulk update of user interface elements.
    ///
    /// #### Special Considerations
    /// If the delegate chooses to resolve `service`, it should retain `service` and set itself as that service’s delegate. The delegate should, therefore, release that service when it receives the `netServiceDidResolveAddress(_:) or `netService(_:didNotResolve:)` delegate messages of the `NetService` class.
    ///
    /// - Parameters:
    ///   - browser: Sender of this delegate message.
    ///   - service: Network service found by `browser`. The delegate can use this object to connect to and use the service.
    ///   - moreComing: `true` when `browser` is waiting for additional services. `false` when there are no additional services.
    func netServiceBrowser(_ browser: NetServiceBrowser,
                           didFind service: NetService,
                           moreComing: Bool)

    /// Tells the delegate a service has disappeared or has become unavailable.
    ///
    /// The delegate uses this message to compile a list of unavailable services. It should wait until `moreComing` is `false` to do a bulk update of user interface elements.
    ///
    /// - Parameters:
    ///   - browser: Sender of this delegate message.
    ///   - service: Network service that has become unavailable.
    ///   - moreComing: `true` when `browser` is waiting for additional services. `false` when there are no additional services.
    func netServiceBrowser(_ browser: NetServiceBrowser,
                           didRemove service: NetService,
                           moreComing: Bool)

    /// Tells the delegate that a search is commencing.
    ///
    /// This message is sent to the delegate only if the underlying network layer is ready to begin a search. The delegate can use this notification to prepare its data structures to receive data.
    ///
    /// - Parameter browser: Sender of this delegate message.
    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser)

    /// Tells the delegate that a search was not successful.
    ///
    /// - Parameters:
    ///   - browser: Sender of this delegate message.
    ///   - error: An `Error` with the reasons the search was unsuccessful. <s>Use the dictionary keys errorCode and errorDomain to retrieve the error information from the dictionary.</s>
    func netServiceBrowser(_ browser: NetServiceBrowser,
                           didNotSearch error: [String: NSNumber])

    /// Tells the delegate that a search was stopped.
    ///
    /// When `browser` receives a `stop()` message from its client, `browser` sends a `netServiceBrowserDidStopSearch:` message to its delegate. The delegate then performs any necessary cleanup.
    ///
    /// - Parameter browser: Sender of this delegate message.
    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser)
}

public extension NetServiceBrowserDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser,
                           didFindDomain domainString: String,
                           moreComing: Bool) { }

    func netServiceBrowser(_ browser: NetServiceBrowser,
                           didRemoveDomain domainString: String,
                           moreComing: Bool) { }

    func netServiceBrowser(_ browser: NetServiceBrowser,
                           didFind service: NetService,
                           moreComing: Bool) { }

    func netServiceBrowser(_ browser: NetServiceBrowser,
                           didRemove service: NetService,
                           moreComing: Bool) { }

    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) { }

    func netServiceBrowser(_ browser: NetServiceBrowser,
                           didNotSearch error: [String: NSNumber]) { }

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) { }
}
