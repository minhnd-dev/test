import Carbon
import SwiftUI

struct SettingsView: View {
    let onSave: () -> Void
    let onCancel: () -> Void

    @StateObject private var settings = SettingsStore.shared
    @State private var isRecording = false
    @State private var recordingMonitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            GroupBox {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Show popup:")
                        Spacer()
                        Picker("", selection: $settings.triggerMethod) {
                            Text("On key combination").tag(TriggerMethod.hotkey)
                            Text("On text selection").tag(TriggerMethod.textSelection)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 180)
                    }

                    if settings.triggerMethod == .hotkey {
                        Divider()
                            .padding(.vertical, 10)

                        HStack {
                            Text("Key combination:")
                            Spacer()
                            Button(action: toggleRecording) {
                                Text(isRecording ? "Press keys..." : settings.hotkeyDisplayString)
                                    .frame(minWidth: 100)
                            }
                            .buttonStyle(.bordered)
                            .disabled(isRecording)

                            Button("Reset") {
                                settings.hotkeyKeyCode = Int(kVK_ANSI_T)
                                settings.hotkeyModifiers = Int(optionKey) | Int(shiftKey)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                            .disabled(isRecording)
                        }
                    }
                }
                .padding(8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .controlSize(.small)
                Button("Save", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
        }
        .frame(width: 440, height: 160)
        .animation(.easeInOut(duration: 0.2), value: settings.triggerMethod)
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true

        let monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [self] event in
            if event.keyCode == 0x35 {
                stopRecording()
                return nil
            }

            let hasModifier =
                event.modifierFlags.intersection([.command, .option, .shift, .control]) != []
            guard hasModifier else { return nil }

            settings.hotkeyKeyCode = Int(event.keyCode)
            settings.hotkeyModifiers = Self.modifierFlags(from: event.modifierFlags)

            stopRecording()
            return nil
        }

        recordingMonitor = monitor
    }

    private func stopRecording() {
        if let monitor = recordingMonitor {
            NSEvent.removeMonitor(monitor)
        }
        recordingMonitor = nil
        isRecording = false
    }

    private static func modifierFlags(from flags: NSEvent.ModifierFlags) -> Int {
        var mods = 0
        if flags.contains(.command) { mods |= Int(cmdKey) }
        if flags.contains(.option) { mods |= Int(optionKey) }
        if flags.contains(.shift) { mods |= Int(shiftKey) }
        if flags.contains(.control) { mods |= Int(controlKey) }
        return mods
    }
}
