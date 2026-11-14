import Foundation
import Combine
import os

extension Comparable {
    func clamped(to r: ClosedRange<Self>) -> Self { min(max(self, r.lowerBound), r.upperBound) }
}

struct MenuSettings: Codable, Equatable {
    // Aim Assist
    var aimEnabled = false
    var aimFOV: Float = 8
    var aimStrength: Float = 0.12
    var aimMaxSpeed: Float = 120
    var aimTargetsHead = false
    var aimOnlyWhileInput = true
    // ESP Debug
    var espEnabled = false
    var espBox = true
    var espName = true
    var espDistance = true
    var espHealth = true
    var espSnaplines = false
    var espHeadDot = false
    // Arena / giao diện
    var lookSensitivity: Float = 0.15
    var botCount = 6
    var botSpeed: Float = 1
    var hapticsEnabled = true
    var menuOpacity: Double = 0.95
    // Menu
    var menuCollapsed = false
    var menuOffsetX: Double = 12
    var menuOffsetY: Double = 40

    static let aimFOVRange: ClosedRange<Float> = 2...30
    static let aimStrengthRange: ClosedRange<Float> = 0.02...1
    static let aimSpeedRange: ClosedRange<Float> = 30...400
    static let sensitivityRange: ClosedRange<Float> = 0.05...0.5
    static let botSpeedRange: ClosedRange<Float> = 0.3...2.5
    static let botCountRange: ClosedRange<Int> = 1...10
    static let opacityRange: ClosedRange<Double> = 0.4...1

    private static func clean(_ v: Float, _ r: ClosedRange<Float>, _ d: Float) -> Float {
        v.isFinite ? v.clamped(to: r) : d
    }

    /// Kiểm tra đầu vào: ép giá trị về khoảng hợp lệ, loại NaN/inf (dữ liệu lưu hỏng hoặc bị sửa tay).
    func sanitized() -> MenuSettings {
        var s = self
        let d = MenuSettings()
        s.aimFOV = Self.clean(s.aimFOV, Self.aimFOVRange, d.aimFOV)
        s.aimStrength = Self.clean(s.aimStrength, Self.aimStrengthRange, d.aimStrength)
        s.aimMaxSpeed = Self.clean(s.aimMaxSpeed, Self.aimSpeedRange, d.aimMaxSpeed)
        s.lookSensitivity = Self.clean(s.lookSensitivity, Self.sensitivityRange, d.lookSensitivity)
        s.botSpeed = Self.clean(s.botSpeed, Self.botSpeedRange, d.botSpeed)
        s.botCount = s.botCount.clamped(to: Self.botCountRange)
        s.menuOpacity = s.menuOpacity.isFinite ? s.menuOpacity.clamped(to: Self.opacityRange) : d.menuOpacity
        if !s.menuOffsetX.isFinite { s.menuOffsetX = d.menuOffsetX }
        if !s.menuOffsetY.isFinite { s.menuOffsetY = d.menuOffsetY }
        return s
    }
}

enum AimPreset: CaseIterable {
    case light, medium, strong
    var title: String {
        switch self { case .light: return "NHẸ"; case .medium: return "VỪA"; case .strong: return "MẠNH" }
    }
    var values: (fov: Float, strength: Float, speed: Float) {
        switch self {
        case .light: return (5, 0.06, 60)
        case .medium: return (8, 0.12, 120)
        case .strong: return (14, 0.30, 240)
        }
    }
}

extension MenuSettings {
    mutating func apply(_ preset: AimPreset) {
        let v = preset.values
        aimFOV = v.fov; aimStrength = v.strength; aimMaxSpeed = v.speed
    }

    /// Đọc cài đặt cũ thiếu trường mới: trường thiếu lấy giá trị mặc định (không bị reset toàn bộ).
    static func decodeMerging(_ data: Data) throws -> MenuSettings {
        let defaultData = try JSONEncoder().encode(MenuSettings())
        guard var base = try JSONSerialization.jsonObject(with: defaultData) as? [String: Any],
              let saved = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CocoaError(.coderReadCorrupt)
        }
        for (k, v) in saved where base[k] != nil { base[k] = v }
        return try JSONDecoder().decode(MenuSettings.self, from: JSONSerialization.data(withJSONObject: base))
    }
}

final class SettingsStore: ObservableObject {
    @Published var settings: MenuSettings

    private static let log = Logger(subsystem: "com.example.tanlocmenu", category: "settings")
    private static let key = "tanloc.menu.settings.v1"
    private let defaults: UserDefaults
    private var cancellable: AnyCancellable?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key) {
            do {
                settings = try MenuSettings.decodeMerging(data).sanitized()
            } catch {
                Self.log.error("Không đọc được cài đặt, dùng mặc định: \(error.localizedDescription)")
                settings = MenuSettings()
            }
        } else {
            settings = MenuSettings()
        }
        cancellable = $settings
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] in self?.save($0) }
    }

    /// Ghi ngay (gọi khi app xuống nền).
    func flush() { save(settings) }

    /// Khôi phục mặc định nhưng giữ vị trí/trạng thái menu.
    func resetKeepingLayout() {
        var s = MenuSettings()
        s.menuOffsetX = settings.menuOffsetX
        s.menuOffsetY = settings.menuOffsetY
        s.menuCollapsed = settings.menuCollapsed
        settings = s
    }

    private func save(_ s: MenuSettings) {
        do {
            defaults.set(try JSONEncoder().encode(s.sanitized()), forKey: Self.key)
        } catch {
            Self.log.error("Không lưu được cài đặt: \(error.localizedDescription)")
        }
    }
}
