import SwiftUI

struct SettingsDurationPicker: View {
    let title: LocalizedStringKey
    @Binding var selection: TimeInterval
    let options: [TimeInterval]
    var minimum: TimeInterval = 1
    var maximum: TimeInterval = DurationInput.maximumDuration
    var step: TimeInterval = 1
    var inputUnit: DurationInput.Unit = .minutes
    var placeholder: LocalizedStringKey = "0"

    @State private var isEditing = false
    @State private var input = ""
    @FocusState private var inputFocused: Bool
    @State private var shakeAttempts: Int = 0
    @State private var isShaking = false
    @Environment(\.locale) private var locale
    @Environment(\.isEnabled) private var isEnabled

    private var maxUnits: Int {
        max(1, Int(maximum / inputUnit.multiplier))
    }

    private var minUnits: Int {
        max(1, Int((minimum / inputUnit.multiplier).rounded()))
    }

    private var stepUnits: Int {
        max(1, Int((step / inputUnit.multiplier).rounded()))
    }

    var body: some View {
        Group {
            if isEditing {
                inlineEditor
            } else {
                SettingsMenuPicker(
                    title: title,
                    selection: $selection,
                    selectedLabel: Text(durationLabel(selection)),
                    customAction: beginEditing
                ) {
                    ForEach(options, id: \.self) { duration in
                        Text(durationLabel(duration)).tag(duration)
                    }
                }
            }
        }
        .onChange(of: inputFocused) { _, focused in
            if !focused { save() }
        }
        .onChange(of: isEnabled) { _, enabled in
            if !enabled { cancel() }
        }
    }

    private var unitText: String {
        let key = inputUnit == .seconds ? "settings.duration.seconds" : "settings.duration.minutes"
        return AppLanguage.localizedString(key, locale: locale).lowercased(with: locale)
    }

    private var inlineEditor: some View {
        HStack(spacing: 4) {
            TextField("", text: $input)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .focused($inputFocused)
                .onSubmit(save)
                .onExitCommand(perform: save)
                .labelsHidden()
                .accessibilityLabel(Text(title))
                .onChange(of: input) { oldValue, newValue in
                    handleInputChange(oldValue: oldValue, newValue: newValue)
                }

            Text(unitText)
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .frame(width: 170, height: 28)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    inputFocused ? Color.accentColor : Color(nsColor: .separatorColor),
                    lineWidth: inputFocused ? 2 : 1
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture {
            inputFocused = true
        }
        .modifier(ShakeEffect(animatableData: CGFloat(shakeAttempts)))
        .task {
            // Wait for the native menu to relinquish keyboard focus.
            await Task.yield()
            inputFocused = true
        }
    }

    private func handleInputChange(oldValue: String, newValue: String) {
        let digits = newValue.filter { $0.isNumber }

        if digits.isEmpty {
            if input != "" {
                input = ""
            }
            return
        }

        if let parsed = Int(digits) {
            if parsed > maxUnits {
                input = "\(maxUnits)"
                triggerShake()
            } else {
                let normalized = "\(parsed)"
                if input != normalized {
                    input = normalized
                }
            }
        } else {
            // If the integer overflows, clamp to maxUnits
            input = "\(maxUnits)"
            triggerShake()
        }
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

    private func beginEditing() {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 0
        let units = selection / inputUnit.multiplier
        input = formatter.string(from: NSNumber(value: units)) ?? "\(Int(units))"
        shakeAttempts = 0
        isShaking = false
        isEditing = true
    }

    private func save() {
        guard isEditing, isEnabled else { return }

        let parsedUnits: Double
        if let val = Double(input.filter({ $0.isNumber })) {
            parsedUnits = val
        } else {
            parsedUnits = Double(minUnits)
        }

        selection = DurationInput.clampedSeconds(
            from: parsedUnits,
            unit: inputUnit,
            minimum: minimum,
            maximum: maximum,
            step: step
        )
        isEditing = false
        inputFocused = false
        isShaking = false
    }

    private func cancel() {
        isEditing = false
        inputFocused = false
        isShaking = false
    }

    private func durationLabel(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = seconds < 60 ? [.second]
            : seconds.truncatingRemainder(dividingBy: 60) == 0 ? [.hour, .minute]
            : [.hour, .minute, .second]
        var calendar = Calendar.current
        calendar.locale = locale
        formatter.calendar = calendar
        return formatter.string(from: seconds) ?? "\(Int(seconds))"
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
