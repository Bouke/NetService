# Pure Swift NetService (Bonjour / Zeroconf / mDNS) implementation

[![Build Status](https://travis-ci.org/Bouke/NetService.svg?branch=master)](https://travis-ci.org/Bouke/NetService)

This module allows you to publish your own Bonjour service on the local
network. On macOS NetService is included with Cocoa, however on Linux there's
no such thing in the standard library.

This branch uses dns_sd as the responder, instead of implementing mDNS itself. On macOS this means that it uses the system-wide daemon, and on Linux one should install `libavahi-compat-libdnssd-dev` to run the system-wide daemon. Beware that this currently only covers registering a service, nothing more.

## Usage

See also [NetService-Example](https://github.com/Bouke/NetService-Example). Note that like Apple's NetService, you need to run a RunLoop in order for the callbacks to happen.

There's also a command line tool included called `dns-sd`, with a subset of the functionality provided by Apple's tool with the same name. You can use this tool to verify the implementation and debug your network when advertisements are not working. Run `swift run dns-sd --help` for usage instructions.

### Publish a NetService

This code will publish a new NetService advertising port 8000. Note that you need to setup a listening socket on port 8000 yourself.

```swift
import Foundation
import NetService

let service = NetService(domain: "local.", type: "_hap._tcp.", name: "Zithoek", port: 8000)
service.delegate = ...
service.publish()
withExtendedLifetime((service, delegate)) {
    RunLoop.main.run()
}
```

### Browsing for NetServices

This code will start a search for the given service type.

```swift
let browser = NetServiceBrowser()
browser.delegate = ...
browser.searchForServices(ofType: "_airplay._tcp.", inDomain: "local.")
withExtendedLifetime((browser, delegate)) {
    RunLoop.main.run()
}
```

## Credits

This library was written by [Bouke Haarsma](https://boukehaarsma.nl).
