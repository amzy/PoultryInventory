// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// Generated file. Do not edit.
//

import PackageDescription

let package = Package(
    name: "FlutterGeneratedPluginSwiftPackage",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "FlutterGeneratedPluginSwiftPackage", type: .static, targets: ["FlutterGeneratedPluginSwiftPackage"])
    ],
    dependencies: [
        .package(name: "cloud_firestore", path: "../.packages/cloud_firestore-6.9.0"),
        .package(name: "firebase_auth", path: "../.packages/firebase_auth-6.6.1"),
        .package(name: "firebase_core", path: "../.packages/firebase_core-4.14.0"),
        .package(name: "google_sign_in_ios", path: "../.packages/google_sign_in_ios-6.3.3"),
        .package(name: "FlutterFramework", path: "../.packages/FlutterFramework")
    ],
    targets: [
        .target(
            name: "FlutterGeneratedPluginSwiftPackage",
            dependencies: [
                .product(name: "cloud-firestore", package: "cloud_firestore"),
                .product(name: "firebase-auth", package: "firebase_auth"),
                .product(name: "firebase-core", package: "firebase_core"),
                .product(name: "google-sign-in-ios", package: "google_sign_in_ios"),
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
