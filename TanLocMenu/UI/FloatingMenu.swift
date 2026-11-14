import SwiftUI

enum MenuTab: String, CaseIterable, Identifiable {
    case aim = "AIM", esp = "ESP", arena = "ARENA", ui = "UI"
    var id: String { rawValue }
}

/// Menu nổi: kéo thả bằng thanh tiêu đề, thu gọn thành nút tròn "TL", vị trí được lưu và luôn nằm trong màn hình.
struct FloatingMenu: View {
    @ObservedObject var store: SettingsStore
    let container: CGSize
    let insets: EdgeInsets
    @GestureState private var dragOffset: CGSize = .zero
    @State private var tab: MenuTab = .aim

    private let expandedWidth: CGFloat = 288
    private let collapsedSize: CGFloat = 52

    private var collapsed: Bool { store.settings.menuCollapsed }
    private var panelSize: CGSize {
        collapsed
            ? CGSize(width: collapsedSize, height: collapsedSize)
            : CGSize(width: expandedWidth,
                     height: max(160, min(container.height - insets.top - insets.bottom - 16, 430)))
    }

    private func origin(extra: CGSize) -> CGPoint {
        let minX = insets.leading + 6
        let maxX = max(minX, container.width - insets.trailing - panelSize.width - 6)
        let minY = insets.top + 6
        let maxY = max(minY, container.height - insets.bottom - panelSize.height - 6)
        return CGPoint(x: (CGFloat(store.settings.menuOffsetX) + extra.width).clamped(to: minX...maxX),
                       y: (CGFloat(store.settings.menuOffsetY) + extra.height).clamped(to: minY...maxY))
    }

    private func commit(_ translation: CGSize) {
        let o = origin(extra: translation)
        store.settings.menuOffsetX = Double(o.x)
        store.settings.menuOffsetY = Double(o.y)
    }

    var body: some View {
        let o = origin(extra: dragOffset)
        Group {
            if collapsed { collapsedButton } else { panel }
        }
        .frame(width: panelSize.width, height: panelSize.height)
        .offset(x: o.x, y: o.y)
        .animation(.easeOut(duration: 0.18), value: collapsed)
    }

    // MARK: Nút thu gọn
    private var collapsedButton: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Theme.accent, Color(red: 0.05, green: 0.2, blue: 0.5)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().stroke(Color.white.opacity(0.25), lineWidth: 1)
            Text("TL").font(.system(size: 17, weight: .black, design: .rounded)).foregroundColor(.white)
        }
        .shadow(color: Theme.accent.opacity(0.6), radius: 8)
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($dragOffset) { v, state, _ in state = v.translation }
                .onEnded { v in
                    if (v.translation.width * v.translation.width + v.translation.height * v.translation.height) < 64 {
                        store.settings.menuCollapsed = false      // chạm nhẹ = mở rộng
                    } else {
                        commit(v.translation)
                    }
                }
        )
        .accessibilityLabel("Mở Tan Loc Menu")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Panel mở rộng
    private var panel: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Theme.accent.opacity(0.35)).frame(height: 1)
            Picker("Mục", selection: $tab) {
                ForEach(MenuTab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) { content }
                    .padding(12)
            }
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.panel.opacity(store.settings.menuOpacity)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.accent.opacity(0.5), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.5), radius: 12)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle().fill(Theme.accent).frame(width: 8, height: 8)
            Text("TAN LOC MENU")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .tracking(1.5)
                .foregroundColor(Theme.textPrimary)
            Spacer()
            Button {
                store.settings.menuCollapsed = true
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 28)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.off))
            }
            .accessibilityLabel("Thu gọn menu")
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(Color.white.opacity(0.001))   // để vùng trống của header nhận cử chỉ kéo
        .gesture(
            DragGesture()
                .updating($dragOffset) { v, state, _ in state = v.translation }
                .onEnded { commit($0.translation) }
        )
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .aim: aimTab
        case .esp: espTab
        case .arena: arenaTab
        case .ui: uiTab
        }
        Text("Chỉ dùng trong môi trường thử nghiệm do bạn sở hữu.")
            .font(.system(size: 10))
            .foregroundColor(Theme.textSecondary)
    }

    @ViewBuilder private var aimTab: some View {
        OnOffToggle(title: "Bật Aim Assist", isOn: $store.settings.aimEnabled)
        Group {
            HStack(spacing: 6) {
                ForEach(AimPreset.allCases, id: \.self) { preset in
                    Button {
                        Haptics.impact(.light)
                        store.settings.apply(preset)
                    } label: {
                        Text(preset.title)
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 30)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.off))
                    }
                }
            }
            LabeledSlider(title: "Vòng hỗ trợ (FOV)", value: $store.settings.aimFOV,
                          range: MenuSettings.aimFOVRange, format: "%.1f°")
            LabeledSlider(title: "Lực hỗ trợ", value: $store.settings.aimStrength,
                          range: MenuSettings.aimStrengthRange, format: "%.2f")
            LabeledSlider(title: "Tốc độ tối đa", value: $store.settings.aimMaxSpeed,
                          range: MenuSettings.aimSpeedRange, format: "%.0f°/s")
            Picker("Vị trí ngắm", selection: $store.settings.aimTargetsHead) {
                Text("Thân").tag(false)
                Text("Đầu").tag(true)
            }
            .pickerStyle(.segmented)
            OnOffToggle(title: "Chỉ khi đang kéo / bắn", isOn: $store.settings.aimOnlyWhileInput)
        }
        .disabled(!store.settings.aimEnabled)
        .opacity(store.settings.aimEnabled ? 1 : 0.4)
    }

    @ViewBuilder private var espTab: some View {
        OnOffToggle(title: "Bật ESP Debug", isOn: $store.settings.espEnabled)
        Group {
            OnOffToggle(title: "Khung", isOn: $store.settings.espBox)
            OnOffToggle(title: "Tên", isOn: $store.settings.espName)
            OnOffToggle(title: "Khoảng cách", isOn: $store.settings.espDistance)
            OnOffToggle(title: "Thanh máu", isOn: $store.settings.espHealth)
            OnOffToggle(title: "Đường kẻ tới mục tiêu", isOn: $store.settings.espSnaplines)
            OnOffToggle(title: "Chấm đầu", isOn: $store.settings.espHeadDot)
        }
        .disabled(!store.settings.espEnabled)
        .opacity(store.settings.espEnabled ? 1 : 0.4)
    }

    @ViewBuilder private var arenaTab: some View {
        SectionTitle(text: "ĐẤU TRƯỜNG LUYỆN TẬP")
        Stepper("Số bot: \(store.settings.botCount)", value: $store.settings.botCount,
                in: MenuSettings.botCountRange)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(Theme.textPrimary)
        LabeledSlider(title: "Tốc độ bot", value: $store.settings.botSpeed,
                      range: MenuSettings.botSpeedRange, format: "x%.1f")
        LabeledSlider(title: "Độ nhạy kéo", value: $store.settings.lookSensitivity,
                      range: MenuSettings.sensitivityRange, format: "%.2f")
    }

    @ViewBuilder private var uiTab: some View {
        SectionTitle(text: "GIAO DIỆN")
        OnOffToggle(title: "Rung phản hồi", isOn: $store.settings.hapticsEnabled)
        LabeledSlider(title: "Độ đậm menu",
                      value: Binding<Float>(get: { Float(store.settings.menuOpacity) },
                                            set: { store.settings.menuOpacity = Double($0) }),
                      range: Float(MenuSettings.opacityRange.lowerBound)...Float(MenuSettings.opacityRange.upperBound),
                      format: "%.2f")
        Button {
            store.resetKeepingLayout()
        } label: {
            Text("KHÔI PHỤC MẶC ĐỊNH")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1)
                .foregroundColor(Theme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.off))
        }
        .padding(.top, 8)
    }
}
