//
//  ContentView.swift
//  MagicCuts
//
//  Created by Bradley Zellman on 10/5/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var bluetoothViewModel = BluetoothViewModel()
    
    // Enum to define our navigation paths
    enum Route: Hashable {
        case discover
        case monitored
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                Text("MagicCuts")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Bluetooth Device Monitoring for Shortcuts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()
                
                VStack(spacing: 15) {
                    NavigationLink(value: Route.discover) {
                        Label("Discover Devices", systemImage: "magnifyingglass")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    
                    NavigationLink(value: Route.monitored) {
                        Label("Monitored Devices", systemImage: "checklist")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.secondary.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .toolbar(.hidden, for: .navigationBar) // Correct way to hide the bar on the root view
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .discover:
                    DeviceDiscoveryView(bluetoothViewModel: bluetoothViewModel)
                case .monitored:
                    MonitoredDevicesView()
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: MonitoredDevice.self, inMemory: true)
}
