import Foundation
import CoreGraphics

struct ProjectedBox {
    let rect: CGRect
    let distance: Float
    let relYaw: Float
}

/// Phép chiếu góc tuyến tính (đủ cho debug overlay; không phải ma trận view-projection đầy đủ).
struct ScreenProjection {
    let camera: CameraState
    let viewport: CGSize

    var vFOV: Float {
        guard viewport.width > 0 else { return camera.hFOV }
        return camera.hFOV * Float(viewport.height / viewport.width)
    }

    static func wrap180(_ angle: Float) -> Float {
        var r = angle.truncatingRemainder(dividingBy: 360)
        if r > 180 { r -= 360 } else if r < -180 { r += 360 }
        return r
    }

    /// Góc lệch (độ) từ tâm ngắm tới điểm p, và khoảng cách 3D (mét).
    func angles(to p: SIMD3<Float>) -> (yaw: Float, pitch: Float, distance: Float) {
        let d = p - camera.position
        let horiz = (d.x * d.x + d.z * d.z).squareRoot()
        let azimuth = atan2f(d.x, d.z) * 180 / Float.pi
        let elevation = atan2f(d.y, horiz) * 180 / Float.pi
        let dist = (horiz * horiz + d.y * d.y).squareRoot()
        return (Self.wrap180(azimuth - camera.yaw), elevation - camera.pitch, dist)
    }

    func screenX(relYaw: Float) -> CGFloat {
        viewport.width / 2 + CGFloat(relYaw / camera.hFOV) * viewport.width
    }

    func screenY(relPitch: Float) -> CGFloat {
        viewport.height / 2 - CGFloat(relPitch / vFOV) * viewport.height
    }

    /// Khung bao của một vật thể đứng trên mặt đất; nil nếu nằm ngoài màn hình/phía sau.
    func boundingRect(base: SIMD3<Float>, height: Float, halfWidth: Float) -> ProjectedBox? {
        let foot = angles(to: base)
        guard foot.distance > 0.1 else { return nil }
        let head = angles(to: base + SIMD3<Float>(0, height, 0))
        let halfWidthDeg = atanf(halfWidth / foot.distance) * 180 / Float.pi
        guard abs(foot.yaw) < camera.hFOV / 2 + halfWidthDeg + 1 else { return nil }

        let cx = screenX(relYaw: foot.yaw)
        let top = screenY(relPitch: head.pitch)
        let bottom = screenY(relPitch: foot.pitch)
        let w = CGFloat(halfWidthDeg / camera.hFOV) * viewport.width
        let rect = CGRect(x: cx - w, y: top, width: 2 * w, height: bottom - top)
        guard rect.height > 0, rect.intersects(CGRect(origin: .zero, size: viewport)) else { return nil }
        return ProjectedBox(rect: rect, distance: foot.distance, relYaw: foot.yaw)
    }
}
