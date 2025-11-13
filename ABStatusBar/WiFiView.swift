//
//  WiFiView.swift
//  ABStatusBar
//
//  Created by Austin Bales on 2025-11-12.
//

internal import Combine
import CoreLocation
import CoreWLAN
import SwiftUI

class WiFiMonitor: NSObject, ObservableObject, CLLocationManagerDelegate {
  @Published var isConnected: Bool = false
  @Published var signalStrength: Int = 0  // 0-3 bars
  @Published var ssid: String = ""

  private var client: CWWiFiClient?
  private var timer: Timer?
  private var locationManager: CLLocationManager?

  override init() {
    super.init()

    // Request location permissions
    locationManager = CLLocationManager()
    locationManager?.delegate = self

    let status = locationManager?.authorizationStatus ?? .notDetermined
    print("WiFi: Location authorization status: \(status.rawValue)")

    if status == .notDetermined {
      print("WiFi: Requesting location authorization")
      locationManager?.requestWhenInUseAuthorization()
    }

    client = CWWiFiClient.shared()
    startMonitoring()
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    print("WiFi: Location authorization changed to: \(manager.authorizationStatus.rawValue)")
    updateWiFiStatus()
  }

  func startMonitoring() {
    updateWiFiStatus()
    timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
      self?.updateWiFiStatus()
    }
  }

  private func updateWiFiStatus() {
    // Try to get default interface name
    let interfaceNames = CWWiFiClient.interfaceNames()
    print("WiFi: Available interfaces: \(String(describing: interfaceNames))")

    guard let interfaceNames = interfaceNames,
      let firstInterfaceName = interfaceNames.first,
      let interface = CWWiFiClient.shared().interface(withName: firstInterfaceName)
    else {
      print("WiFi: No interface available")
      isConnected = false
      return
    }

    print("WiFi: Interface name: \(interface.interfaceName ?? "unknown")")
    print("WiFi: Power on: \(interface.powerOn())")
    print("WiFi: Service active: \(interface.serviceActive())")

    let ssidData = interface.ssid()
    print("WiFi: SSID: \(String(describing: ssidData))")

    if let ssidData = ssidData {
      isConnected = true
      ssid = ssidData

      // Convert RSSI to signal bars (0-3)
      // RSSI typically ranges from -90 (weak) to -30 (strong)
      let rssi = interface.rssiValue()
      print("WiFi: Connected to \(ssidData), RSSI: \(rssi)")
      if rssi >= -50 {
        signalStrength = 3
      } else if rssi >= -60 {
        signalStrength = 2
      } else if rssi >= -70 {
        signalStrength = 1
      } else {
        signalStrength = 0
      }
    } else {
      print("WiFi: Not connected or no permission to read SSID")
      isConnected = false
      signalStrength = 0
      ssid = ""
    }
  }

  deinit {
    timer?.invalidate()
  }
}

struct WiFiView: View {
  @StateObject private var monitor = WiFiMonitor()

  var body: some View {
    Image(systemName: wifiIconName)
      .font(.system(size: 14, weight: .medium))
      .foregroundColor(.primary)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
  }

  private var wifiIconName: String {
    if !monitor.isConnected {
      return "wifi.slash"
    }

    switch monitor.signalStrength {
    case 3:
      return "wifi"
    case 2:
      return "wifi"
    case 1:
      return "wifi"
    case 0:
      return "wifi"
    default:
      return "wifi.slash"
    }
  }
}
