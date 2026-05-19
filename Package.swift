// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VerkadaKit",
    platforms: [
        .tvOS   (.v18),
        .iOS    ("17.6"),
        .macOS  (.v13),
        .macCatalyst(.v18)
    ],
    products: [
        .library(
            name: "Verkada",
            targets: ["Verkada"]
        ),
    ],
    dependencies: [
        .Tapioca,
    ],
    targets: [
        .target(
            name: "Verkada",
            dependencies: [
                .Tapioca
            ]
        ),
    ]
)
extension String {
    static let Tapioca = "https://github.com/Project-Academy/Tapioca.git"
}
extension Package.Dependency {
    static var Tapioca: Package.Dependency { .package(url: .Tapioca, from: "1.1.0") }
}
extension Target.Dependency {
    static var Tapioca: Target.Dependency { .product(name: "Tapioca", package: "Tapioca") }
}
