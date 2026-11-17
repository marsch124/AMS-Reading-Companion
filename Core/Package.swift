// swift-tools-version: 5.9
import PackageDescription

// The rules of AMS Reading Companion, with no screen in them: the shelf, the importers for Kobo,
// Apple Books and Kindle, and the search. `swift test` runs them in seconds.
let package = Package(
    name: "ReadingCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "ReadingCore", targets: ["ReadingCore"])],
    targets: [
        .target(name: "ReadingCore", linkerSettings: [.linkedLibrary("sqlite3")]),
        .testTarget(name: "ReadingCoreTests", dependencies: ["ReadingCore"]),
    ]
)
