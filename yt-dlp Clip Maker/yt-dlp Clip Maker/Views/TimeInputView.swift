import SwiftUI

/// Input field for time values in HH:MM:SS format
struct TimeInputView: View {
    let label: String
    @Binding var value: String
    var maxTime: TimeInterval? = nil

    @State private var isValid: Bool = true
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("00:00:00", text: $value)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .frame(width: 100)
                .focused($isFocused)
                .onChange(of: value) { _, newValue in
                    validateAndFormat(newValue)
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        formatOnBlur()
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isValid ? Color.clear : Color.red, lineWidth: 1)
                )
        }
    }

    private func validateAndFormat(_ input: String) {
        // Allow partial input while typing
        let cleaned = input.filter { $0.isNumber || $0 == ":" }

        // Validate format
        if let _ = TimeFormatter.parse(cleaned) {
            isValid = true
        } else if cleaned.isEmpty || isPartiallyValid(cleaned) {
            isValid = true  // Allow partial input
        } else {
            isValid = false
        }
    }

    private func isPartiallyValid(_ input: String) -> Bool {
        // Check if input could become valid with more characters
        let pattern = #"^(\d{0,2}:?){0,3}$"#
        return input.range(of: pattern, options: .regularExpression) != nil
    }

    private func formatOnBlur() {
        // Try to parse and reformat the value
        if let time = TimeFormatter.parse(value) {
            value = TimeFormatter.format(time)
            isValid = true
        } else if value.isEmpty {
            value = "00:00:00"
            isValid = true
        }
    }
}

/// Combined start/end time input with validation
struct TimeRangeInputView: View {
    @Binding var startTime: String
    @Binding var endTime: String
    let videoDuration: TimeInterval?
    let validationMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Clip Range")
                .font(.headline)

            HStack(spacing: 16) {
                TimeInputView(
                    label: "Start",
                    value: $startTime,
                    maxTime: videoDuration
                )

                TimeInputView(
                    label: "End",
                    value: $endTime,
                    maxTime: videoDuration
                )

                if let duration = videoDuration {
                    Spacer()
                    Text("Video duration: \(TimeFormatter.formatShort(duration))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let message = validationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        TimeInputView(label: "Start Time", value: .constant("00:01:30"))

        TimeRangeInputView(
            startTime: .constant("00:01:30"),
            endTime: .constant("00:02:45"),
            videoDuration: 632,
            validationMessage: nil
        )

        TimeRangeInputView(
            startTime: .constant("00:05:00"),
            endTime: .constant("00:02:00"),
            videoDuration: 632,
            validationMessage: "Start time must be before end time"
        )
    }
    .padding()
    .frame(width: 400)
}
