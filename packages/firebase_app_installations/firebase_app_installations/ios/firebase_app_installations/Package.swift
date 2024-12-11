// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

// Copyright 2024, the Chromium project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import Foundation
import PackageDescription

enum ConfigurationError: Error {
  case fileNotFound(String)
  case parsingError(String)
  case invalidFormat(String)
}

let appInstallationsDirectory = String(URL(string: #file)!.deletingLastPathComponent()
  .absoluteString
  .dropLast())

func loadFirebaseSDKVersion() throws -> String {
  let firebaseCoreScriptPath = NSString.path(withComponents: [
    appInstallationsDirectory,
    "..",
    "generated_firebase_sdk_version.txt",
  ])
  do {
    let version = try String(contentsOfFile: firebaseCoreScriptPath, encoding: .utf8)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return version
  } catch {
    throw ConfigurationError
      .fileNotFound("Error loading or parsing generated_firebase_sdk_version.txt: \(error)")
  }
}

func loadPubspecVersion() throws -> String {
  let pubspecPath = NSString.path(withComponents: [
    appInstallationsDirectory,
    "..",
    "..",
    "pubspec.yaml",
  ])
  do {
    let yamlString = try String(contentsOfFile: pubspecPath, encoding: .utf8)
    let lines = yamlString.split(separator: "\n")

    guard let firebaseCoreVersionLine = lines.first(where: { $0.contains("firebase_core:") }) else {
      throw ConfigurationError
        .invalidFormat("No firebase_core dependency version line found in pubspec.yaml")
    }
    var firebaseCoreVersion = firebaseCoreVersionLine.split(separator: ":")[1]
      .trimmingCharacters(in: .whitespaces)
    firebaseCoreVersion = firebaseCoreVersion.replacingOccurrences(of: "^", with: "")

    return firebaseCoreVersion
  } catch {
    throw ConfigurationError.fileNotFound("Error loading or parsing pubspec.yaml: \(error)")
  }
}

let firebase_sdk_version_string: String
let firebase_core_version_string: String
let shared_spm_tag = "-firebase-core-swift"

do {
  firebase_sdk_version_string = try loadFirebaseSDKVersion()
  firebase_core_version_string = try loadPubspecVersion()
} catch {
  fatalError("Failed to load configuration: \(error)")
}

guard let firebase_sdk_version = Version(firebase_sdk_version_string) else {
  fatalError("Invalid Firebase SDK version: \(firebase_sdk_version_string)")
}

guard let shared_spm_version = Version("\(firebase_core_version_string)\(shared_spm_tag)") else {
  fatalError("Invalid firebase_core version: \(firebase_core_version_string)\(shared_spm_tag)")
}

let package = Package(
  name: "firebase_app_installations",
  platforms: [
    .iOS("13.0"),
  ],
  products: [
    .library(name: "firebase-app-installations", targets: ["firebase_app_installations"]),
  ],
  dependencies: [
    .package(url: "https://github.com/firebase/firebase-ios-sdk", from: firebase_sdk_version),
    .package(url: "https://github.com/firebase/flutterfire", exact: shared_spm_version),
  ],
  targets: [
    .target(
      name: "firebase_app_installations",
      dependencies: [
        .product(name: "FirebaseInstallations", package: "firebase-ios-sdk"),
        // Wrapper dependency
        .product(name: "firebase-core-shared", package: "flutterfire"),
      ],
      resources: [
        .process("Resources"),
      ]
    ),
  ]
)