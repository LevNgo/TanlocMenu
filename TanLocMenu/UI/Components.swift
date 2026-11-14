import SwiftUI
import UIKit

struct SectionTitle: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Rectangle().fill(Theme.accent).frame(width: 3, height: 12)
            Text(text)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.4)
                .foregroundColor(Theme.textSecondary)
            Spacer()
        }
        .padding(.top, 6)
    }
}

/// Nút bật/tắt với trạng thái ON/OFF hiển thị rõ ràng.
struct OnOffToggle: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            Haptics.impact(.light)
            isOn.toggle()
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text(isOn ? "ON" : "OFF")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(isOn ? .white : Theme.textSecondary)
                    .frame(width: 48, height: 24)
                    .background(Capsule().fill(isOn ? Theme.accent : Theme.off))
                    .overlay(Capsule().stroke(isOn ? Theme.accent.opacity(0.6) : Color.clear, lineWidth: 3).blur(radius: 3))
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "Bật" : "Tắt")
    }
}

struct LabeledSlider: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let format: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(.system(size: 12)).foregroundColor(Theme.textSecondary)
                Spacer()
                Text(String(format: format, value))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
            }
            Slider(value: $value, in: range).tint(Theme.accent)
        }
    }
}
