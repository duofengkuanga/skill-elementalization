// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "kcoisga",
    platforms: [
        .macOS("15.0")
    ],
    products: [
        .library(name: "CoolSkillCore", targets: ["CoolSkillCore"]),
        .executable(name: "kcoisga", targets: ["CoolSkill"])
    ],
    targets: [
        .target(name: "CoolSkillCore"),
        .executableTarget(
            name: "CoolSkill",
            dependencies: ["CoolSkillCore"]
        ),
        .testTarget(
            name: "CoolSkillCoreTests",
            dependencies: ["CoolSkillCore"]
        )
    ]
)
