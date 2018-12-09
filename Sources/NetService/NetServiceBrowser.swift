// Documentation © Apple, Inc.

import CoreFoundation

import struct Foundation.Data
import class Foundation.NSNumber
import Cdns_sd

fileprivate let _browseCallback: DNSServiceBrowseReply = { (sdRef, flags, interfaceIndex, errorCode, name, regtype, domain, context) in
    let browser: NetServiceBrowser = Unmanaged.fromOpaque(context!).takeUnretainedValue()
    guard errorCode == kDNSServiceErr_NoError else {
        browser.didNotSearch(error: errorCode)
        return
    }
    let name = String(cString: name!)
    let domain = String(cString: domain!)
    let regtype = String(cString: regtype!)
    let flags = ServiceFlags(rawValue: flags)
    let service = NetService(domain: domain, type: regtype, name: name)
    if flags.contains(.add) {
        browser.didFind(service: service, moreComing: flags.contains(.moreComing))
    } else {
        browser.didRemove(service: service, moreComing: flags.contains(.moreComing))
    }
}

fileprivate let _processResult: CFSocketCallBack = { (s, type, address, data, info) in
    let browser: NetServiceBrowser = Unmanaged.fromOpaque(info!).takeUnretainedValue()
    browser.processResult()
}

fileprivate let _enumDomainsReply: DNSServiceDomainEnumReply = { (sdRef, flags, interfaceIndex, errorCode, replyDomain, context) in
    let browser: NetServiceBrowser = Unmanaged.fromOpaque(context!).takeUnretainedValue()
    guard errorCode == kDNSServiceErr_NoError else {
        browser.didNotSearch(error: errorCode)
        return
    }
    let flags = ServiceFlags(rawValue: flags)
    let domain = String(cString: replyDomain!)
    if flags.contains(.add) {
        browser.didFind(domain: domain, moreComing: flags.contains(.moreComing))
    } else {
        browser.didRemove(domain: domain, moreComing: flags.contains(.moreComing))
    }
}

/// The NSNetServiceBrowser class defines an interface for finding published services on a network using multicast DNS. An instance of NSNetServiceBrowser is known as a network service browser.
///
/// Services can range from standard services, such as HTTP and FTP, to custom services defined by other applications. You can use a network service browser in your code to obtain the list of accessible domains and then to obtain an `NetService` object for each discovered service. Each network service browser performs one search at a time, so if you want to perform multiple simultaneous searches, use multiple network service browsers.
///
/// A network service browser performs all searches asynchronously using the current run loop to execute the search in the background. Results from a search are returned through the associated delegate object, which your client application must provide. Searching proceeds in the background until the object receives a `stop()` message.
///
/// To use an NSNetServiceBrowser object to search for services, allocate it, initialize it, and assign a delegate. <s>(If you wish, you can also use the `schedule(in:forMode:)` and `remove(from:forMode:)` methods to execute searches on a run loop other than the current one.)</s> Once your object is ready, you begin by gathering the list of accessible domains using either the <s>`searchForRegistrationDomains()` or `searchForBrowsableDomains()`</s> methods. From the list of returned domains, you can pick one and use the `searchForServices(ofType:inDomain:)` method to search for services in that domain.
///
/// <s>The NSNetServiceBrowser class provides two ways to search for domains. In most cases, your client should use the `searchForRegistrationDomains()` method to search only for local domains to which the host machine has registration authority. This is the preferred method for accessing domains as it guarantees that the host machine can connect to services in the returned domains. Access to domains outside this list may be more limited.</s>
public class NetServiceBrowser {
    private var serviceRef: DNSServiceRef? = nil
    private var socket: CFSocket? = nil
    private var source: CFRunLoopSource? = nil

    // MARK: Creating Network Service Browsers

    /// Initializes an allocated NetServiceBrowser object.
    public init() {
    }

    deinit {
    }

    // MARK: Configuring Network Service Browsers

    /// The delegate object for this instance.
    public weak var delegate: NetServiceBrowserDelegate?

    // MARK: Using Network Service Browsers

    /// Initiates a search for domains visible to the host. This method returns
    /// immediately.
    ///
    /// The delegate receives a `netServiceBrowser(_:didFindDomain:moreComing:)`
    /// message for each domain discovered.
    ///
    /// Implementers note: Apple's documentation doesn't mention that
    /// a `netServiceBrowserWillSearch(_:)` will be sent to the delegate, but the
    /// actual implementation from Apple does, and thus this implementation does
    /// as well.
    public func searchForBrowsableDomains() {
        browse {
            DNSServiceEnumerateDomains(&serviceRef, ServiceFlags.browseDomains.rawValue, 0, _enumDomainsReply, Unmanaged.passUnretained(self).toOpaque())
        }
    }

    /// Initiates a search for domains in which the host may register services.
    ///
    /// This method returns immediately, sending a `netServiceBrowserWillSearch(_:)`
    /// message to the delegate if the network was ready to initiate the search.
    /// The delegate receives a subsequent `netServiceBrowser(_:didFindDomain:moreComing:)`
    /// message for each domain discovered.
    ///
    /// Most network service browser clients do not have to use this method—it
    /// is sufficient to publish a service with the empty string, which registers
    /// it in any available registration domains automatically.
    public func searchForRegistrationDomains() {
        browse {
            DNSServiceEnumerateDomains(&serviceRef, ServiceFlags.registrationDomains.rawValue, 0, _enumDomainsReply, Unmanaged.passUnretained(self).toOpaque())
        }
    }

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
        guard serviceRef == nil else {
            return didNotSearch(error: -72003) // CFNetServiceErrorInProgress
        }
        browse {
            DNSServiceBrowse(&serviceRef, 0, 0, type, domain, _browseCallback, Unmanaged.passUnretained(self).toOpaque())
        }
    }

    func browse(setup: () -> DNSServiceErrorType) {
        delegate?.netServiceBrowserWillSearch(self)

        let error = setup()

        guard error == 0 else {
            didNotSearch(error: error)
            return
        }

        start()
    }

    func start() {
        assert(serviceRef != nil, "serviceRef should've been set already")

        let fd = DNSServiceRefSockFD(serviceRef)
        let info = Unmanaged.passUnretained(self).toOpaque()

        var context = CFSocketContext(version: 0, info: info, retain: nil, release: nil, copyDescription: nil)

        socket = CFSocketCreateWithNative(nil, fd, CFOptionFlags(kCFSocketReadCallBack), _processResult, &context)

        // Don't close the underlying socket on invalidate, as it is owned by dns_sd.
        var socketFlags = CFSocketGetSocketFlags(socket)
        socketFlags &= ~CFOptionFlags(kCFSocketCloseOnInvalidate)
        CFSocketSetSocketFlags(socket, socketFlags)

        source = CFSocketCreateRunLoopSource(nil, socket, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes)
    }

    /// Halts a currently running search or resolution.
    ///
    /// This method sends a netServiceBrowserDidStopSearch(_:) message to the delegate and causes the browser to discard any pending search results.
    public func stop() {
        assert(serviceRef != nil, "Browser already stopped")
        CFRunLoopSourceInvalidate(source)
        CFSocketInvalidate(socket)
        DNSServiceRefDeallocate(serviceRef)
        delegate?.netServiceBrowserDidStopSearch(self)
    }

    //MARK:- Internal

    func didNotSearch(error: DNSServiceErrorType) {
        delegate?.netServiceBrowser(self, didNotSearch: [
            "NSNetServicesErrorDomain": NSNumber(value: 10),
            "NSNetServicesErrorCode": NSNumber(value: error)
        ])
    }

    func didFind(service: NetService, moreComing: Bool) {
        delegate?.netServiceBrowser(self, didFind: service, moreComing: moreComing)
    }

    func didRemove(service: NetService, moreComing: Bool) {
        delegate?.netServiceBrowser(self, didRemove: service, moreComing: moreComing)
    }

    func didFind(domain: String, moreComing: Bool) {
        delegate?.netServiceBrowser(self, didFindDomain: domain, moreComing: moreComing)
    }

    func didRemove(domain: String, moreComing: Bool) {
        delegate?.netServiceBrowser(self, didRemoveDomain: domain, moreComing: moreComing)
    }

    fileprivate func processResult() {
        DNSServiceProcessResult(serviceRef)
    }
}
