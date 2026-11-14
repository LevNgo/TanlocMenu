import Foundation

struct AimTarget: Equatable {
    let entityID: Int
    let dYaw: Float
    let dPitch: Float
    var angularDistance: Float { (dYaw * dYaw + dPitch * dPitch).squareRoot() }
}

/// Logic thuần (không phụ thuộc UI) nên dễ unit test.
enum AimAssist {
    static let deadzone: Float = 0.05

    static func aimHeightFraction(head: Bool) -> Float { head ? 0.92 : 0.65 }

    /// Chọn mục tiêu còn sống, không bị che, gần tâm ngắm nhất trong vòng FOV hỗ trợ.
    static func selectTarget(entities: [DebugEntity],
                             projection: ScreenProjection,
                             settings: MenuSettings) -> AimTarget? {
        var best: AimTarget?
        for e in entities where e.health > 0 && !e.isOccluded {
            let p = e.position + SIMD3<Float>(0, e.height * aimHeightFraction(head: settings.aimTargetsHead), 0)
            let a = projection.angles(to: p)
            let t = AimTarget(entityID: e.id, dYaw: a.yaw, dPitch: a.pitch)
            guard t.angularDistance <= settings.aimFOV else { continue }
            if let b = best, b.angularDistance <= t.angularDistance { continue }
            best = t
        }
        return best
    }

    /// Độ hiệu chỉnh trong 1 frame: làm mượt theo hệ số, giới hạn tốc độ tối đa (độ/giây).
    static func correction(for t: AimTarget, strength: Float, maxSpeed: Float, dt: Float) -> (dYaw: Float, dPitch: Float) {
        guard dt > 0, t.angularDistance > deadzone else { return (0, 0) }
        let s = min(max(strength, 0), 1)
        let alpha = 1 - powf(1 - s, dt * 60)
        var dy = t.dYaw * alpha
        var dp = t.dPitch * alpha
        let mag = (dy * dy + dp * dp).squareRoot()
        let cap = maxSpeed * dt
        if mag > cap, mag > 0 {
            let k = cap / mag
            dy *= k; dp *= k
        }
        return (dy, dp)
    }
}

/// Gắn Aim Assist vào bất kỳ game nào cài `GameDebugProvider`.
final class AimAssistController {
    private(set) var currentTargetID: Int?

    func update(provider: GameDebugProvider, settings: MenuSettings, inputActive: Bool, dt: Float) {
        currentTargetID = nil
        guard settings.aimEnabled, !settings.aimOnlyWhileInput || inputActive else { return }
        let projection = ScreenProjection(camera: provider.camera, viewport: provider.viewport)
        guard let target = AimAssist.selectTarget(entities: provider.debugEntities(),
                                                  projection: projection,
                                                  settings: settings) else { return }
        currentTargetID = target.entityID
        let c = AimAssist.correction(for: target, strength: settings.aimStrength,
                                     maxSpeed: settings.aimMaxSpeed, dt: dt)
        provider.applyAimCorrection(dYaw: c.dYaw, dPitch: c.dPitch)
    }
}
