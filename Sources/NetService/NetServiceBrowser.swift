// Documentation © Apple, Inc.

import Foundation
import DNS
import Socket

// TODO: track TTL of records


/// The NSNetServiceBrowser class defines an interface for finding published services on a network using multicast DNS. An instance of NSNetServiceBrowser is known as a network service browser.
/// 
/// Services can range from standard services, such as HTTP and FTP, to custom services defined by other applications. You can use a network service browser in your code to obtain the list of accessible domains and then to obtain an `NetService` object for each discovered service. Each network service browser performs one search at a time, so if you want to perform multiple simultaneous searches, use multiple network service browsers.
///
/// A network service browser performs all searches asynchronously using the current run loop to execute the search in the background. Results from a search are returned through the associated delegate object, which your client application must provide. Searching proceeds in the background until the object receives a `stop()` message.
///
/// To use an NSNetServiceBrowser object to search for services, allocate it, initialize it, and assign a delegate. <s>(If you wish, you can also use the `schedule(in:forMode:)` and `remove(from:forMode:)` methods to execute searches on a run loop other than the current one.)</s> Once your object is ready, you begin by gathering the list of accessible domains using either the <s>`searchForRegistrationDomains()` or `searchForBrowsableDomains()`</s> methods. From the list of returned domains, you can pick one and use the `searchForServices(ofType:inDomain:)` method to search for services in that domain.
///
/// <s>The NSNetServiceBrowser class provides two ways to search for domains. In most cases, your client should use the `searchForRegistrationDomains()` method to search only for local domains to which the host machine has registration authority. This is the preferred method for accessing domains as it guarantees that the host machine can connect to services in the returned domains. Access to domains outside this list may be more limited.</s>
public class NetServiceBrowser: Listener {
    var responder: Responder
    var services = [String]()

    // MARK: Creating Network Service Browsers

    /// Initializes an allocated NetServiceBrowser object.
    public init() {
        do {
            responder = try Responder.shared()
        } catch {
            fatalError("Could not get shared Responder: \(error)")
        }
        responder.listeners.append(self)
    }

    deinit {
        if let index = responder.listeners.index(where: { $0 === self }) {
            responder.listeners.remove(at: index)
        }
    }

    // MARK: Configuring Network Service Browsers

    /// The delegate object for this instance.
    public weak var delegate: NetServiceBrowserDelegate?

    // MARK: Using Network Service Browsers

    var currentSearch: (type: String, domain: String)?

    
    /// Starts a search for services of a particular type within a specific domain.
    ///
    /// - Parameters:
    ///   - type: Type of the service to search for.
    ///   - domain: Domain name in which to perform the search.
    ///
    /// This method returns immediately, sending a `netServiceBrowserWillSearch(_:)` 
    /// message to the delegate if the network was ready to initiate the search.
    /// The delegate receives subsequent `netServiceBrowser(_:didFind:moreComing:)` 
    /// messages for each service discovered.
    ///
    /// The serviceType argument must contain both the service type and transport
    /// layer information. To ensure that the mDNS responder searches for services, 
    /// rather than hosts, make sure to prefix both the service name and transport 
    /// layer name with an underscore character ("_"). For example, to search for
    /// an HTTP service on TCP, you would use the type string `"_http._tcp."`. Note 
    /// that the period character at the end is required.
    ///
    /// <s>The domainName argument can be an explicit domain name, the generic local
    /// domain @"local." (note trailing period, which indicates an absolute name), 
    /// or the empty string (@""), which indicates the default registration domains. 
    /// Usually, you pass in an empty string. Note that it is acceptable to use an 
    /// empty string for the domainName argument when publishing or browsing a 
    /// service, but do not rely on this for resolution.</s>
    public func searchForServices(ofType type: String, inDomain domain: String) {
        assert(domain == "local.", "only local. domain is supported")
        assert(type.hasSuffix("."), "type label(s) should end with a period")
        delegate?.netServiceBrowserWillSearch(self)

        currentSearch = (type, domain)
        let query = Message(header: Header(response: false), questions: [Question(name: "\(type).\(domain)", type: .pointer)])
        do {
            try responder.multicast(message: query)
        } catch {
            delegate?.netServiceBrowser(self, didNotSearch: error)
        }
    }

    /// Halts a currently running search or resolution.
    ///
    /// This method sends a netServiceBrowserDidStopSearch(_:) message to the delegate and causes the browser to discard any pending search results.
    public func stop() {
        currentSearch = nil
        delegate?.netServiceBrowserDidStopSearch(self)
    }

    func received(message: Message) {
        guard let (type, domain) = currentSearch else {
            return
        }

        let newPointers = message.answers
            .flatMap { $0 as? PointerRecord }
            .filter { !self.services.contains($0.destination) }
            .filter { $0.name == "\(type)\(domain)" }

        for pointer in newPointers {
            let service = NetService(domain: domain, type: type, name: pointer.destination.replacingOccurrences(of: ".\(type)\(domain)", with: ""))
            guard let serviceRecord = message.additional.flatMap({ $0 as? ServiceRecord }).first(where: { $0.name == pointer.destination }) else {
                continue
            }

            service.port = Int(serviceRecord.port)
            service.hostName = serviceRecord.server

            service.addresses = message.additional
                .flatMap { $0 as? HostRecord<IPv4> }
                .filter { $0.name == serviceRecord.server }
                .map { hostRecord in
                    var sin = sockaddr_in()
                    sin.sin_family = sa_family_t(AF_INET)
                    sin.sin_addr = hostRecord.ip.address
                    sin.sin_port = serviceRecord.port
                    return Socket.Address.ipv4(sin)
                }
            service.addresses! += message.additional
                .flatMap { $0 as? HostRecord<IPv6> }
                .filter { $0.name == serviceRecord.server }
                .map { hostRecord in
                    var sin6 = sockaddr_in6()
                    sin6.sin6_family = sa_family_t(AF_INET6)
                    sin6.sin6_addr = hostRecord.ip.address
                    sin6.sin6_port = serviceRecord.port
                    return Socket.Address.ipv6(sin6)
                }

            self.services.append(pointer.destination)
            self.delegate?.netServiceBrowser(self, didFind: service, moreComing: false)
        }
    }
}


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
//    func netServiceBrowser(_ browser: NetServiceBrowser,
//                           didFindDomain domainString: String,
//                           moreComing: Bool)
    
    
    /// Tells the delegate the a domain has disappeared or has become unavailable.
    ///
    /// The delegate uses this message to compile a list of unavailable domains. It should wait until `moreComing` is `false` to do a bulk update of user interface elements.
    ///
    /// - Parameters:
    ///   - browser: Sender of this delegate message.
    ///   - domainString: Name of the domain that became unavailable.
    ///   - moreComing: `true` when `browser` is waiting for additional domains. `false` when there are no additional domains.
//    func netServiceBrowser(_ browser: NetServiceBrowser,
//                           didRemoveDomain domainString: String,
//                           moreComing: Bool)
    
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
                           didNotSearch error: Error)

    /// Tells the delegate that a search was stopped.
    ///
    /// When `browser` receives a `stop()` message from its client, `browser` sends a `netServiceBrowserDidStopSearch:` message to its delegate. The delegate then performs any necessary cleanup.
    ///
    /// - Parameter browser: Sender of this delegate message.
    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser)
}

