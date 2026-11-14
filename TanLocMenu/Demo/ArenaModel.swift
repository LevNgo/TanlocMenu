import SwiftUI
import UIKit

/// Vòng lặp theo màn hình (CADisplayLink). Gọi stop() khi không dùng để tránh giữ vòng tham chiếu.
final class DisplayLinkDriver: NSObject {
    private var link: CADisplayLink?
    private var handler: ((Double) -> Void)?
    private var last: CFTimeInterval = 0

    func start(_ handler: @escaping (Double) -> Void) {
        stop()
        self.handler = handler
        last = 0
        let l = CADisplayLink(target: self, selector: #selector(step(_:)))
        l.add(to: .main, forMode: .common)
        link = l
    }

    func stop() {
        link?.invalidate()
        link = nil
        handler = nil
    }

    @objc private func step(_ l: CADisplayLink) {
        defer { last = l.timestamp }
        guard last > 0 else { return }
        handler?(min(l.timestamp - last, 0.05))
    }
}

/// Đấu trường luyện tập do CHÍNH ỨNG DỤNG này sở hữu: bot di chuyển, cột che, bắn hitscan.
/// Cài đặt `GameDebugProvider` — đây là mẫu để bạn cài cho game thật của mình.
final class ArenaModel: ObservableObject, GameDebugProvider {
    struct Bot {
        let id: Int
        let name: String
        let anchor: SIMD2<Float>
        let amp: Float
        let speed: Float
        let phase: Float
        var health = 100
        var respawnAt: Double?
    }

    struct Pillar {
        let center: SIMD2<Float>
        let radius: Float
        let height: Float
    }

    private(set) var camera = CameraState(position: SIMD3<Float>(0, 1.6, 0), yaw: 0, pitch: 0, hFOV: 90)
    var viewport = CGSize(width: 844, height: 390)
    var settingsProvider: () -> MenuSettings = { MenuSettings() }

    private(set) var bots: [Bot]
    let pillars: [Pillar]
    private(set) var shots = 0
    private(set) var hits = 0
    private(set) var time: Double = 0
    private var botClock: Double = 0
    private(set) var lastHitTime: Double = -10
    var isLooking = false
    var isFiring = false

    private let aim = AimAssistController()
    private let driver = DisplayLinkDriver()

    var lockedTargetID: Int? { aim.currentTargetID }
    var lockedTargetName: String? { bots.first { $0.id == lockedTargetID }?.name }
    var hitFlash: Bool { time - lastHitTime < 0.15 }

    init() {
        bots = Self.makeBots(count: 6)
        pillars = [
            Pillar(center: SIMD2<Float>(3, 12), radius: 0.9, height: 3.5),
            Pillar(center: SIMD2<Float>(-6, 18), radius: 1.1, height: 3.5),
            Pillar(center: SIMD2<Float>(8, 8), radius: 0.8, height: 3.5)
        ]
    }

    static func makeBots(count: Int) -> [Bot] {
        let n = max(1, count)
        return (0..<n).map { i in
            let a = Float(i) * (2 * Float.pi / Float(n)) + 0.3
            let d = 9 + Float(i) * (24 / Float(n))
            return Bot(id: i + 1, name: "BOT_\(i + 1)",
                       anchor: SIMD2<Float>(sinf(a) * d, cosf(a) * d),
                       amp: 2.5, speed: 0.6 + 0.1 * Float(i % 6), phase: Float(i))
        }
    }

    // MARK: Vòng đời
    func start() {
        driver.start { [weak self] dt in self?.tick(dt) }
    }

    func stop() { driver.stop(); isLooking = false; isFiring = false }

    private func tick(_ dt: Double) {
        time += dt
        let s = settingsProvider()
        botClock += dt * Double(s.botSpeed)
        let wanted = s.botCount.clamped(to: MenuSettings.botCountRange)
        if bots.count != wanted { bots = Self.makeBots(count: wanted) }
        for i in bots.indices {
            if let r = bots[i].respawnAt, time >= r {
                bots[i].health = 100
                bots[i].respawnAt = nil
            }
        }
        aim.update(provider: self, settings: s,
                   inputActive: isLooking || isFiring, dt: Float(dt))
        objectWillChange.send()
    }

    // MARK: Điều khiển người chơi
    func look(dx: CGFloat, dy: CGFloat) {
        let k = settingsProvider().lookSensitivity
        camera.yaw = ScreenProjection.wrap180(camera.yaw + Float(dx) * k)
        camera.pitch = (camera.pitch - Float(dy) * k).clamped(to: -80...80)
    }

    func fire() {
        shots += 1
        let proj = ScreenProjection(camera: camera, viewport: viewport)
        let center = CGPoint(x: viewport.width / 2, y: viewport.height / 2)
        let hit = debugEntities()
            .filter { !$0.isOccluded }
            .compactMap { e -> (DebugEntity, ProjectedBox)? in
                guard let box = proj.boundingRect(base: e.position, height: e.height, halfWidth: 0.3) else { return nil }
                return (e, box)
            }
            .filter { $0.1.rect.contains(center) }
            .min { $0.1.distance < $1.1.distance }
        guard let h = hit, let idx = bots.firstIndex(where: { $0.id == h.0.id }) else { return }
        hits += 1
        lastHitTime = time
        bots[idx].health -= 34
        if bots[idx].health <= 0 { bots[idx].respawnAt = time + 1.5 }
    }

    func resetStats() { shots = 0; hits = 0 }

    // MARK: GameDebugProvider
    func position(of bot: Bot) -> SIMD3<Float> {
        let t = Float(botClock) * bot.speed + bot.phase
        return SIMD3<Float>(bot.anchor.x + bot.amp * sinf(t), 0, bot.anchor.y + bot.amp * cosf(t * 0.7))
    }

    func debugEntities() -> [DebugEntity] {
        bots.filter { $0.health > 0 }.map { b in
            let pos = position(of: b)
            return DebugEntity(id: b.id, name: b.name, position: pos, height: 1.8,
                               health: b.health, maxHealth: 100, isOccluded: isOccluded(pos))
        }
    }

    func applyAimCorrection(dYaw: Float, dPitch: Float) {
        camera.yaw = ScreenProjection.wrap180(camera.yaw + dYaw)
        camera.pitch = (camera.pitch + dPitch).clamped(to: -80...80)
    }

    // MARK: Che khuất (đoạn thẳng camera→bot cắt hình trụ cột)
    private func isOccluded(_ botPos: SIMD3<Float>) -> Bool {
        let a = SIMD2<Float>(camera.position.x, camera.position.z)
        let b = SIMD2<Float>(botPos.x, botPos.z)
        return pillars.contains { Self.segmentHitsCircle(a, b, $0.center, $0.radius) }
    }

    static func segmentHitsCircle(_ a: SIMD2<Float>, _ b: SIMD2<Float>, _ c: SIMD2<Float>, _ r: Float) -> Bool {
        let ab = b - a
        let len2 = ab.x * ab.x + ab.y * ab.y
        guard len2 > 1e-6 else { return false }
        let t = min(max(((c.x - a.x) * ab.x + (c.y - a.y) * ab.y) / len2, 0), 1)
        let closest = a + ab * t
        let d = c - closest
        return d.x * d.x + d.y * d.y <= r * r
    }
}
