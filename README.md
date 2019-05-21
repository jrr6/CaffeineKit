<img src="https://github.com/aaplmath/CaffeineKit/raw/master/logo.png" height="150" align="left">

# CaffeineKit

A Swift library for keeping Macs awake.

[![GitHub release](https://img.shields.io/github/release/aaplmath/CaffeineKit.svg)](https://github.com/aaplmath/CaffeineKit/releases)
[![GitHub license](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://raw.githubusercontent.com/aaplmath/CaffeineKit/master/LICENSE)
[![Documentation](https://aaplmath.github.io/CaffeineKit/badge.svg)](https://aaplmath.github.io/CaffeineKit)
[![Swift version](https://img.shields.io/badge/Swift-5-orange.svg)](https://swift.org)
[![Build status](https://travis-ci.org/aaplmath/CaffeineKit.svg?branch=master)](https://travis-ci.org/aaplmath/CaffeineKit)

---

**Still under development! Breaking changes may be introduced without warning.**

CaffeineKit prevents sleep using the command-line utility `caffeinate`. Why is it better than `let proc = Process(); proc.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate"); proc.arguments = ["-d", "-i"]; try! proc.run()`?

* **Safety**: CaffeineKit ensures that "zombie" `caffeinate` processes don't linger when your app terminates. In fact, even if your app is force-quit (i.e., receives `SIGKILL`), CaffeineKit can (usually\*) prevent `caffeinate` processes from hanging around.

    \*If you use the `process` Caffeination option, CaffeineKit can't prevent `caffeinate` from persisting if your app is force-quit. But it will still stop zombie processes if you receive any other sort of interrupt!
  
* **Swiftiness**: `try Caffeination(withOpts: [.display, .idle, .timed(2)]).start()` vs. `let proc = Process(); proc.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate"); proc.arguments = ["-d", "-i", "-t", "2"]; try proc.run()`. Need more be said?
* **Flexibility**: CaffeineKit is versatile. For instance (no pun intended), instances of `Caffeination` can be reused. (Ever tried re-running a `Process`?) Multiple `Caffeination` sessions can even occur concurrently. Caffeination exposes an incredibly simple and intuitive architecture, but one that is powerful and customizable if you want it to be.
* **Closures made simple**: CaffeineKit exposes a robust, generics-based closure model that makes it trivial to create closures that prevent screen, disk, or idle sleep. These are especially useful for tasks that require that the computer stay awake, but which macOS might not recognize as having this requirement.



### Examples

Creating a simple `Caffeination` instance that prevents the display from sleeping:

```swift
let caf = Caffeination(withOpts: [.idle, .display])
do {
    try caf.start()
} catch {
    print("Caffeination failed to start")
}
// Do some other things
caf.stop()
```



Preventing idle sleep for 5 minutes:

```swift
let caf = Caffeination(withOpts: [.idle, .timed(5 * 60)])
do {
    try caf.start()
} catch {
    print("Caffeination failed to start")
}
```



Creating a closure that prevents sleep:

```swift
myObject.closureProperty = try Caffeination.closure { (myInt, myStr) -> Int in
    // Actions that require the computer to be awake
    return 1
}
```

