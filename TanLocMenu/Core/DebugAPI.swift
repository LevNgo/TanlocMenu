import Foundation
import CoreGraphics

/// Một đối tượng mà GAME CỦA BẠN báo cho module debug (qua API hợp lệ của game).
struct DebugEntity: Identifiable, Equatable {
    let id: Int
    var name: String
    /// Vị trí chân đối tượng, đơn vị mét. x = phải, y = lên, z = phía trước (yaw 0).
    var position: SIMD3<Float>
    var height: Float
    var health: Int
    var maxHealth: Int
    /// Game tự tính (raycast) — module không tự đoán.
    var isOccluded: Bool
}

/// Camera người chơi. yaw/pitch tính bằng độ. yaw dương = quay phải, pitch dương = nhìn lên.
struct CameraState: Equatable {
    var position: SIMD3<Float>
    var yaw: Float
    var pitch: Float
    var hFOV: Float
}

/// Game của bạn cần cài đặt protocol này để dùng Aim Assist + ESP Debug.
/// Gọi mọi hàm từ main thread.
protocol GameDebugProvider: AnyObject {
    var camera: CameraState { get }
    var viewport: CGSize { get }
    func debugEntities() -> [DebugEntity]
    /// Game áp độ lệch góc (độ) vào camera của chính nó.
    func applyAimCorrection(dYaw: Float, dPitch: Float)
}
