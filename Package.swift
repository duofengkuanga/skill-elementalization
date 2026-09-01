// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "CoolSkill",
    platforms: [
        .macOS("15.0")
    ],
    products: [
        .library(name: "CoolSkillCore", targets: ["CoolSkillCore"]),
        .executable(name: "CoolSkill", targets: ["CoolSkill"])
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
