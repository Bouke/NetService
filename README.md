# Pure Swift NetService (Bonjour / Zeroconf / mDNS) implementation

At the moment Swift's Foundation doesn't include NetService on Linux. This project's aim is to fill that gap. At the moment it is in very rough shape. Basic features like browsing and publishing work. However there are (very) rough edges at the moment.

## Usage

### Publish a NetService

This code will publish a new NetService. It will also setup both IPv4 and IPv6 listening sockets at an available port.

    let service = NetService(domain: "local.", type: "_hap._tcp.", name: "Zithoek", port: 0)
    service.publish(options: [.listenForConnections])
    service.schedule(in: .main, forMode: .defaultRunLoopMode)
    service.delegate = ...
    withExtendedLifetime((service, delegate)) {
        RunLoop.main.run()
    }

### Browsing for NetServices

This code will start a search for the given service type.

    let browser = NetServiceBrowser()
    browser.searchForServices(ofType: "_airplay._tcp.", inDomain: "local.")
    browser.delegate = ...
    withExtendedLifetime((browser, delegate)) {
        RunLoop.main.run()
    }

## Status

### API

* [x] NetService.publish
* [x] NetService.publish([.noAutoRename, .listenForConnections])
* [x] NetServiceBrowser.searchForServices(ofType:inDomain:)
* [ ] Other methods on NetService
* [ ] Other methods on NetServiceBrowser

### Issues

* Starting a NetService after previously stopping it with .listenForConnections doesn't accept any new connects
* API not 100% compatible with Cocoa counterpart
* Only search domain ``local.`` is supported
* Changes in IP addresses (on reconnect) are not picked up
* Does not accommodate for system sleep (service/browser should broadcast/query directly)
* CFNetwork is missing on Linux, so project is a dead end (for now).
