//
//  AppSettings.swift
//  ABStatusBar
//
//  Created by Austin Bales on 2025-11-12.
//

internal import Combine
import SwiftUI

class AppSettings: ObservableObject {
  static let shared = AppSettings()

  @AppStorage("debugMode") var debugMode: Bool = false

  private init() {}

  func debugPrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    if debugMode {
      let output = items.map { "\($0)" }.joined(separator: separator)
      print(output, terminator: terminator)
    }
  }
}
