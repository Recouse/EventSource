# EventSource

[![Build macOS](https://github.com/Recouse/EventSource/actions/workflows/macos.yml/badge.svg)](https://github.com/Recouse/EventSource/actions/workflows/macos.yml)
[![Build Linux](https://github.com/Recouse/EventSource/actions/workflows/linux.yml/badge.svg)](https://github.com/Recouse/EventSource/actions/workflows/linux.yml)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FRecouse%2FEventSource%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/Recouse/EventSource)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FRecouse%2FEventSource%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/Recouse/EventSource)

EventSource is a Swift package that provides a simple implementation of a client for [Server-Sent 
Events](https://html.spec.whatwg.org/multipage/server-sent-events.html) (SSE). It allows you to easily 
receive real-time updates from a server over a persistent HTTP connection, using a simple and efficient 
interface.

It also leverages Swift concurrency features to provide a more expressive and intuitive way to handle asynchronous operations.

> [!Note]
> Please note that this package was originally developed to be used in conjunction with another package, 
and as such, it may not cover all specification details. Please be aware of this limitation when 
evaluating whether EventSource is suitable for your specific use case.

## Installation

The module name of the package is `EventSource`. Choose one of the instructions below to install and add 
the following import statement to your source code.

```swift
import EventSource
```

#### [Xcode Package Dependency](https://developer.apple.com/documentation/xcode/adding_package_dependencies_to_your_app)

From Xcode menu: `File` > `Swift Packages` > `Add Package Dependency`

```text
https://github.com/Recouse/EventSource
```

#### [Swift Package Manager](https://www.swift.org/package-manager)

In your `Package.swift` file, first add the following to the package `dependencies`:

```swift
.package(url: "https://github.com/Recouse/EventSource.git"),
```

And then, include "EventSource" as a dependency for your target:

```swift
.target(name: "<target>", dependencies: [
    .product(name: "EventSource", package: "EventSource"),
]),
```

## Usage

Using EventSource is easy. Simply create a new task from an instance of EventSource with the URLRequest of the SSE endpoint you want to connect to, and await for events:
```swift
import EventSource

let eventSource = EventSource()
let dataTask = eventSource.dataTask(for: urlRequest)

for await event in dataTask.events() {
    switch event {
    case .open:
        print("Connection was opened.")
    case .error(let error):
        print("Received an error:", error.localizedDescription)
    case .message(let message):
        print("Received a message", message.data ?? "")
    case .closed:
        print("Connection was closed.")
    }
}
```

Use `dataTask.cancel()` to explicitly close the connection. However, in that case `.closed` event won't be emitted.

## Compatibility

* macOS 10.15+
* iOS 13.0+
* tvOS 13.0+
* watchOS 6.0+
* visionOS 1.0+

## Dependencies

No dependencies.

## Contributing

Contributions to are always welcomed! If you'd like to contribute, please fork this repository and 
submit a pull request with your changes.

## License

EventSource is released under the MIT License. See [LICENSE](LICENSE) for more information.

