import SwiftUI

enum SettingsTimeInput {
    static func format(_ text: String, replacing previousText: String) -> String {
        if previousText.hasSuffix(":"), text == String(previousText.dropLast()) {
            return String(text.dropLast())
        }

        let digits = text.compactMap(\.wholeNumberValue).map { String($0) }.joined()
        guard !digits.isEmpty else { return "" }
        let hourLength = text.firstIndex(of: ":") == text.index(after: text.startIndex) ? 1 : 2
        guard digits.count >= hourLength else { return digits }

        let hour = min(23, Int(digits.prefix(hourLength)) ?? 0)
        let minuteDigits = String(digits.dropFirst(hourLength).prefix(2))
        let minute = minuteDigits.count == 2
            ? String(format: "%02d", min(59, Int(minuteDigits) ?? 0))
            : minuteDigits
        return String(format: "%02d:", hour) + minute
    }

    static func minute(from text: String) -> Int? {
        let components = text.split(separator: ":", omittingEmptySubsequences: false)
        guard (1...2).contains(components.count), components[0].count <= 2,
              let hour = Int(components[0]), (0...23).contains(hour) else { return nil }
        guard components.count == 2, !components[1].isEmpty else { return hour * 60 }
        guard components[1].count <= 2, let minute = Int(components[1]),
              (0...59).contains(minute) else { return nil }
        return hour * 60 + minute
    }
}

/// Edits a 24-hour time stored as minutes since midnight.
struct SettingsTimePicker: View {
    let title: LocalizedStringKey
    @Binding var minute: Int
    var width: CGFloat = 80

    @State private var isEditing = false
    @State private var input = ""
    @FocusState private var inputFocused: Bool
    @State private var isHovered = false
    @State private var shakeAttempts = 0
    @State private var isShaking = false
    @State private var eventMonitor: Any?

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme

    private var formattedTime: String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    var body: some View {
        Group {
            if isEditing {
                inlineEditor
            } else {
                displayBadge
            }
        }
        .onChange(of: inputFocused) { _, focused in
            if !focused { save() }
        }
        .onChange(of: isEnabled) { _, enabled in
            if !enabled { cancel() }
        }
        .onChange(of: isEditing) { _, editing in
            updateEventMonitor(editing: editing)
        }
        .onDisappear {
            removeEventMonitor()
        }
    }

    private var displayBadge: some View {
        Text(formattedTime)
            .font(.system(size: 13))
            .monospacedDigit()
            .foregroundStyle(.primary)
            .lineLimit(1)
            .frame(width: width, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(colorScheme == .dark ? Color.white.opacity(isHovered ? 0.12 : 0.07)
                                              : Color.black.opacity(isHovered ? 0.09 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(colorScheme == .dark ? Color.white.opacity(isHovered ? 0.22 : 0.12)
                                                       : Color.black.opacity(isHovered ? 0.20 : 0.10), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .onHover { isHovered = $0 }
            .onTapGesture { beginEditing() }
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(title))
            .accessibilityValue(Text(formattedTime))
    }

    private var inlineEditor: some View {
        TextField("", text: $input, prompt: Text(formattedTime).foregroundStyle(.tertiary))
            .textFieldStyle(.plain)
            .multilineTextAlignment(.center)
            .font(.system(size: 13))
            .monospacedDigit()
            .focused($inputFocused)
            .focusEffectDisabled()
            .onSubmit(save)
            .onExitCommand(perform: cancel)
            .labelsHidden()
            .accessibilityLabel(Text(title))
            .frame(width: width, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        Color(red: 0.22, green: 0.54, blue: 0.98),
                        lineWidth: 1.5
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .modifier(ShakeEffect(animatableData: CGFloat(shakeAttempts)))
            .onChange(of: input) { oldValue, newValue in
                let formatted = SettingsTimeInput.format(newValue, replacing: oldValue)
                if input != formatted { input = formatted }
            }
            .task {
                await Task.yield()
                inputFocused = true
            }
    }

    private func beginEditing() {
        guard isEnabled else { return }
        input = ""
        shakeAttempts = 0
        isShaking = false
        isEditing = true
    }

    private func save() {
        guard isEditing, isEnabled else { return }

        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            isEditing = false
            inputFocused = false
            return
        }

        if let parsed = SettingsTimeInput.minute(from: trimmed) {
            minute = parsed
            isEditing = false
            inputFocused = false
            isShaking = false
        } else {
            triggerShake()
        }
    }

    private func cancel() {
        isEditing = false
        inputFocused = false
        isShaking = false
    }

    private func triggerShake() {
        guard !isShaking else { return }
        isShaking = true
        withAnimation(.easeInOut(duration: 0.25)) {
            shakeAttempts += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isShaking = false
        }
    }

    private func updateEventMonitor(editing: Bool) {
        guard editing else {
            removeEventMonitor()
            return
        }
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            guard let window = event.window, window == NSApp.keyWindow else { return event }
            let hit = window.contentView?.hitTest(event.locationInWindow)
            if !(hit is NSTextField || hit is NSTextView) {
                DispatchQueue.main.async { self.save() }
            }
            return event
        }
    }

    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

private struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 3.5
    var shakesPerUnit: CGFloat = 2
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amount * sin(animatableData * .pi * shakesPerUnit),
                y: 0
            )
        )
    }
}
