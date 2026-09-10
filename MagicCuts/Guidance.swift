import SwiftUI
import TipKit
import AppIntents

struct IdentifyTip: Tip {
    var title: Text { Text("Not sure which device?") }
    var message: Text? { Text("Move one device closer and watch its signal. A name alone does not prove which device it is.") }
    var options: [any TipOption] { MaxDisplayCount(1) }
}
struct TuneTip: Tip {
    var title: Text { Text("Choose what counts as nearby") }
    var message: Text? { Text("Edit the threshold, then test it in the places you plan to use.") }
    var options: [any TipOption] { MaxDisplayCount(1) }
}
struct ValidateTip: Tip {
    var title: Text { Text("Test both places") }
    var message: Text? { Text("A nearby test alone cannot tell you what happens farther away.") }
    var options: [any TipOption] { MaxDisplayCount(1) }
}
struct ShortcutTip: Tip {
    var title: Text { Text("Use your result in Shortcuts") }
    var message: Text? { Text("A proximity check returns a result your shortcut can act on.") }
    var options: [any TipOption] { MaxDisplayCount(1) }
}

struct ShortcutsSetupView: View {
    let device: MonitoredDevice
    @AppStorage private var verifiedThreshold: String
    init(device: MonitoredDevice) {
        self.device = device
        _verifiedThreshold = AppStorage(wrappedValue: "", "shortcutVerified.\(device.persistentIdentifier)")
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Use \(device.name)").font(.title2.bold())
                Text("1. Open Shortcuts").font(.headline)
                Text("Find MagicCuts and add “Check if Bluetooth Device is Nearby” to a shortcut.")
                ShortcutsLink().shortcutsLinkStyle(.automaticOutline)
                Text("2. Choose your device").font(.headline)
                Text("Select \(device.name). The check uses its saved threshold of \(device.requiredSignalStrength) dBm.")
                Text("3. Add an If action").font(.headline)
                Text("True means at least one reading met the threshold. False means it was not detected above the threshold—not confirmed absence. Bluetooth errors stop the shortcut.")
                Text("4. Run it in both places").font(.headline)
                Text("Test your shortcut nearby and away. Opening Shortcuts does not verify its behavior.")
                if device.serviceUUIDs.isEmpty { InlineFailure(message: "This device advertises no saved service identifiers. Background checks may not find it; test your actual shortcut and try with MagicCuts open.") }
                Text("MagicCuts supplies a check, not an automatic arrival trigger. Bluetooth advertising and iOS background limits can affect results.").font(.callout).foregroundStyle(.secondary)
                Button(verifiedThreshold == device.confirmationKey ? "Verified by you" : "I tested my Shortcut") { verifiedThreshold = device.confirmationKey; ShortcutTip().invalidate(reason: .actionPerformed) }
                    .buttonStyle(ControlStyle()).accessibilityIdentifier("shortcut.verify")
                if !verifiedThreshold.isEmpty { Button("Reset confirmation") { verifiedThreshold = "" } }
            }.padding(MC.inset).frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
        }.background(MC.canvas).navigationTitle("Configure Shortcut").navigationBarTitleDisplayMode(.inline)
    }
}

struct HelpView: View {
    var body: some View {
        List {
            Section("Identify") { Text("MagicCuts reads Bluetooth LE advertisements. Some devices do not advertise, and names can be missing or shared. Move one device at a time and watch its signal change.") }
            Section("Tune") { Text("Less negative RSSI means a stronger signal. It is not an exact distance: walls, your body, orientation, and interference change readings.") }
            Section("Validate") { Text("Each test observes for 10 seconds. Two or more readings all on the expected side validate that window. Mixed or sparse readings need another test. No readings cannot prove a device is away.") }
            Section("Shortcuts") { Text("The Shortcut returns true for any valid reading at or above the saved threshold. A validation test is stricter. Verify your actual shortcut, especially in the background.") }
        }.navigationTitle("How MagicCuts works")
    }
}
