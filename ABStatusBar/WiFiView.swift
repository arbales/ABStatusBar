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
  @Published var availableNetworks: [CWNetwork] = []
  @Published var isPowerOn: Bool = true

  private var client: CWWiFiClient?
  private var timer: Timer?
  private var locationManager: CLLocationManager?
  private var currentInterface: CWInterface?

  override init() {
    super.init()

    // Request location permissions
    locationManager = CLLocationManager()
    locationManager?.delegate = self

    let status = locationManager?.authorizationStatus ?? .notDetermined
    AppSettings.shared.debugPrint("WiFi: Location authorization status: \(status.rawValue)")

    if status == .notDetermined {
      AppSettings.shared.debugPrint("WiFi: Requesting location authorization")
      locationManager?.requestWhenInUseAuthorization()
    }

    client = CWWiFiClient.shared()
    startMonitoring()
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    AppSettings.shared.debugPrint(
      "WiFi: Location authorization changed to: \(manager.authorizationStatus.rawValue)")
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
    AppSettings.shared.debugPrint(
      "WiFi: Available interfaces: \(String(describing: interfaceNames))")

    guard let interfaceNames = interfaceNames,
      let firstInterfaceName = interfaceNames.first,
      let interface = CWWiFiClient.shared().interface(withName: firstInterfaceName)
    else {
      AppSettings.shared.debugPrint("WiFi: No interface available")
      isConnected = false
      return
    }

    AppSettings.shared.debugPrint("WiFi: Interface name: \(interface.interfaceName ?? "unknown")")

    isPowerOn = interface.powerOn()
    AppSettings.shared.debugPrint("WiFi: Power on: \(isPowerOn)")
    AppSettings.shared.debugPrint("WiFi: Service active: \(interface.serviceActive())")

    currentInterface = interface

    let ssidData = interface.ssid()
    AppSettings.shared.debugPrint("WiFi: SSID: \(String(describing: ssidData))")

    if let ssidData = ssidData {
      isConnected = true
      ssid = ssidData

      // Convert RSSI to signal bars (0-3)
      // RSSI typically ranges from -90 (weak) to -30 (strong)
      let rssi = interface.rssiValue()
      AppSettings.shared.debugPrint("WiFi: Connected to \(ssidData), RSSI: \(rssi)")
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
      AppSettings.shared.debugPrint("WiFi: Not connected or no permission to read SSID")
      isConnected = false
      signalStrength = 0
      ssid = ""
    }
  }

  func scanNetworks() {
    guard let interface = currentInterface else { return }

    do {
      let networks = try interface.scanForNetworks(withSSID: nil)

      // Deduplicate networks by SSID, keeping the one with strongest signal
      var networksBySSID: [String: CWNetwork] = [:]
      for network in networks {
        guard let ssid = network.ssid, !ssid.isEmpty else { continue }

        if let existing = networksBySSID[ssid] {
          // Keep the network with stronger signal
          if network.rssiValue > existing.rssiValue {
            networksBySSID[ssid] = network
          }
        } else {
          networksBySSID[ssid] = network
        }
      }

      // Sort by signal strength
      availableNetworks = networksBySSID.values.sorted { network1, network2 in
        network1.rssiValue > network2.rssiValue
      }

      print(
        "WiFi: Found \(networks.count) total networks, \(availableNetworks.count) unique networks")
    } catch {
      AppSettings.shared.debugPrint("WiFi: Error scanning networks: \(error)")
    }
  }

  func connect(to network: CWNetwork, password: String?) throws {
    guard let interface = currentInterface else {
      throw NSError(
        domain: "WiFiMonitor", code: -1,
        userInfo: [NSLocalizedDescriptionKey: "No interface available"])
    }

    if let password = password {
      try interface.associate(to: network, password: password)
    } else {
      try interface.associate(to: network, password: nil)
    }
  }

  func togglePower() {
    guard let interface = currentInterface else { return }

    do {
      let newState = !isPowerOn
      try interface.setPower(newState)
      isPowerOn = newState
      AppSettings.shared.debugPrint("WiFi: Power toggled to \(newState)")

      // Update status after toggling
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        self.updateWiFiStatus()
      }
    } catch {
      AppSettings.shared.debugPrint("WiFi: Error toggling power: \(error)")
    }
  }

  deinit {
    timer?.invalidate()
  }
}

struct WiFiMenuView: View {
  @ObservedObject var monitor: WiFiMonitor
  @Binding var isPresented: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // WiFi toggle
      HStack {
        Text("Wi-Fi")
          .font(.system(size: 13, weight: .semibold))
        Spacer()
        Toggle(
          "",
          isOn: Binding(
            get: { monitor.isPowerOn },
            set: { _ in monitor.togglePower() }
          )
        )
        .toggleStyle(.switch)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)

      Divider()

      // Current network section
      if monitor.isConnected && monitor.isPowerOn {
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Image(systemName: "wifi")
            Text(monitor.ssid)
              .font(.system(size: 13, weight: .semibold))
            Spacer()
            Image(systemName: "checkmark")
              .font(.system(size: 12, weight: .bold))
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
        }

        Divider()
      }

      // Available networks
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(Array(monitor.availableNetworks.enumerated()), id: \.offset) { index, network in
            if let ssid = network.ssid {
              Button(action: {
                // TODO: Handle network selection
                AppSettings.shared.debugPrint("Selected network: \(ssid)")
              }) {
                HStack {
                  Image(systemName: signalIcon(for: network.rssiValue))
                    .font(.system(size: 12))
                  Text(ssid)
                    .font(.system(size: 13))
                  Spacer()
                  if network.ssid == monitor.ssid {
                    Image(systemName: "checkmark")
                      .font(.system(size: 12, weight: .bold))
                  }
                  if network.wlanChannel?.channelBand == .band5GHz {
                    Text("5GHz")
                      .font(.system(size: 10))
                      .foregroundColor(.secondary)
                  }
                }
                .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .padding(.horizontal, 12)
              .padding(.vertical, 8)
              .background(Color.clear)
              .onHover { isHovered in
                // TODO: Add hover effect
              }
            }
          }
        }
      }
      .frame(maxHeight: 300)

      Divider()

      // Bottom actions
      Button("Open Network Preferences...") {
        NSWorkspace.shared.open(
          URL(string: "x-apple.systempreferences:com.apple.preference.network")!)
        isPresented = false
      }
      .buttonStyle(.plain)
      .font(.system(size: 13))
      .padding(.horizontal, 12)
      .padding(.vertical, 8)

      Divider()

      // Debug toggle
      Toggle(
        "Debug Mode",
        isOn: Binding(
          get: { AppSettings.shared.debugMode },
          set: { AppSettings.shared.debugMode = $0 }
        )
      )
      .toggleStyle(.checkbox)
      .font(.system(size: 13))
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
    }
    .frame(width: 300)
    .background(Color(NSColor.controlBackgroundColor))
    .cornerRadius(8)
    .shadow(radius: 10)
    .onAppear {
      monitor.scanNetworks()
    }
  }

  private func signalIcon(for rssi: Int) -> String {
    if rssi >= -50 {
      return "wifi"
    } else if rssi >= -60 {
      return "wifi"
    } else if rssi >= -70 {
      return "wifi"
    } else {
      return "wifi"
    }
  }
}

struct WiFiView: View {
  @StateObject private var monitor = WiFiMonitor()
  @State private var showMenu = false

  var body: some View {
    Button(action: {
      showMenu.toggle()
    }) {
      Image(systemName: wifiIconName)
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(.primary)
    }
    .buttonStyle(.plain)
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .debugBackground(.green)
    .popover(isPresented: $showMenu, arrowEdge: .bottom) {
      WiFiMenuView(monitor: monitor, isPresented: $showMenu)
    }
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
