//
//  ContentView.swift
//  ABStatusBar
//
//  Created by Austin Bales on 2025-11-12.
//

internal import Combine
import SwiftUI

struct StatusBarView: View {
  var body: some View {
    HStack(alignment: .center, spacing: 0) {
      Spacer()
      WiFiView()
      WeekNumberView()
      ClockView()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

struct WeekNumberView: View {
  @State private var currentDate = Date()

  let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

  var body: some View {
    Text(weekString)
      .font(.system(size: 14, weight: .medium, design: .default))
      .foregroundColor(.primary)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .onReceive(timer) { input in
        currentDate = input
      }
  }

  private var weekString: String {
    let calendar = Calendar.current
    let weekNumber = calendar.component(.weekOfYear, from: currentDate)
    return "Week \(weekNumber)"
  }
}

struct ClockView: View {
  @State private var currentTime = Date()

  let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

  var body: some View {
    Text(timeString)
      .font(.system(size: 14, weight: .medium, design: .default))
      .foregroundColor(.primary)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .onReceive(timer) { input in
        currentTime = input
      }
  }

  private var timeString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE MMM d  h:mm a"
    return formatter.string(from: currentTime)
  }
}

#Preview {
  ClockView()
    .frame(width: 300, height: 32)
}
