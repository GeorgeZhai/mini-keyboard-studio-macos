// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "MiniKeyboard",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "MiniKeyboard", targets: ["MiniKeyboardApp"]),
    .executable(name: "MiniKeyboardDiag", targets: ["MiniKeyboardDiag"]),
  ],
  targets: [
    .target(
      name: "MiniKeyboardUSB",
      path: "Sources/MiniKeyboardUSB",
      publicHeadersPath: "include",
      cSettings: [
        .unsafeFlags(["-fobjc-arc"])
      ],
      linkerSettings: [
        .linkedFramework("Foundation"),
        .linkedFramework("IOKit"),
        .linkedFramework("IOUSBHost"),
      ]
    ),
    .target(
      name: "MiniKeyboardCore",
      dependencies: ["MiniKeyboardUSB"],
      path: "Sources/MiniKeyboardCore"
    ),
    .executableTarget(
      name: "MiniKeyboardApp",
      dependencies: ["MiniKeyboardCore"],
      path: "Sources/MiniKeyboardApp"
    ),
    .executableTarget(
      name: "MiniKeyboardDiag",
      dependencies: ["MiniKeyboardCore"],
      path: "Sources/MiniKeyboardDiag"
    ),
    .executableTarget(
      name: "MiniKeyboardCoreTests",
      dependencies: ["MiniKeyboardCore"],
      path: "Tests/MiniKeyboardCoreTests"
    ),
  ]
)
