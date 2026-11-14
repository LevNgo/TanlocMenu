import XCTest
@testable import TanLocMenu

final class TanLocMenuTests: XCTestCase {
    private func camera(yaw: Float = 0, pitch: Float = 0) -> CameraState {
        CameraState(position: SIMD3<Float>(0, 1.6, 0), yaw: yaw, pitch: pitch, hFOV: 90)
    }
    private func projection(_ cam: CameraState) -> ScreenProjection {
        ScreenProjection(camera: cam, viewport: CGSize(width: 800, height: 400))
    }
    private func entity(id: Int, x: Float, z: Float, occluded: Bool = false, health: Int = 100) -> DebugEntity {
        DebugEntity(id: id, name: "E\(id)", position: SIMD3<Float>(x, 0, z), height: 1.8,
                    health: health, maxHealth: 100, isOccluded: occluded)
    }

    func testProjectionAngles() {
        let p = projection(camera())
        let a = p.angles(to: SIMD3<Float>(0, 1.6, 10))
        XCTAssertEqual(a.yaw, 0, accuracy: 0.001)
        XCTAssertEqual(a.pitch, 0, accuracy: 0.001)
        XCTAssertEqual(a.distance, 10, accuracy: 0.001)
        XCTAssertEqual(p.angles(to: SIMD3<Float>(10, 1.6, 10)).yaw, 45, accuracy: 0.01)
    }

    func testBoundingRectNilWhenBehindCamera() {
        XCTAssertNil(projection(camera()).boundingRect(base: SIMD3<Float>(0, 0, -10), height: 1.8, halfWidth: 0.3))
    }

    func testSelectsNearestInsideFOV() {
        var s = MenuSettings(); s.aimFOV = 8
        let t = AimAssist.selectTarget(entities: [entity(id: 1, x: 0, z: 10), entity(id: 2, x: 5, z: 10)],
                                       projection: projection(camera()), settings: s)
        XCTAssertEqual(t?.entityID, 1)
    }

    func testIgnoresOccludedAndDead() {
        let s = MenuSettings()
        let t = AimAssist.selectTarget(entities: [entity(id: 1, x: 0, z: 10, occluded: true),
                                                  entity(id: 2, x: 0, z: 12, health: 0)],
                                       projection: projection(camera()), settings: s)
        XCTAssertNil(t)
    }

    func testCorrectionRespectsMaxSpeed() {
        let t = AimTarget(entityID: 1, dYaw: 5, dPitch: 0)
        let c = AimAssist.correction(for: t, strength: 1, maxSpeed: 60, dt: 1.0 / 60)
        XCTAssertEqual(c.dYaw, 1, accuracy: 1e-4)      // 60°/s * 1/60 s
        XCTAssertEqual(c.dPitch, 0, accuracy: 1e-4)
    }

    func testCorrectionZeroInsideDeadzone() {
        let c = AimAssist.correction(for: AimTarget(entityID: 1, dYaw: 0.01, dPitch: 0),
                                     strength: 1, maxSpeed: 100, dt: 0.016)
        XCTAssertEqual(c.dYaw, 0)
    }

    func testSanitizeClampsAndRejectsNaN() {
        var s = MenuSettings()
        s.aimFOV = 999
        s.aimStrength = .nan
        s.aimMaxSpeed = -5
        let c = s.sanitized()
        XCTAssertEqual(c.aimFOV, 30)
        XCTAssertEqual(c.aimStrength, MenuSettings().aimStrength)
        XCTAssertEqual(c.aimMaxSpeed, 30)
    }

    func testStorePersistsAndSurvivesCorruptData() {
        let suite = "tanloc.test.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        defer { d.removePersistentDomain(forName: suite) }

        let a = SettingsStore(defaults: d)
        a.settings.aimEnabled = true
        a.settings.aimFOV = 12
        a.flush()
        let b = SettingsStore(defaults: d)
        XCTAssertTrue(b.settings.aimEnabled)
        XCTAssertEqual(b.settings.aimFOV, 12)

        d.set(Data("không phải JSON".utf8), forKey: "tanloc.menu.settings.v1")
        XCTAssertEqual(SettingsStore(defaults: d).settings, MenuSettings())
    }

    func testOldSettingsMissingNewFieldsKeepValues() throws {
        let old = Data("{\"aimEnabled\":true,\"aimFOV\":10}".utf8)
        let s = try MenuSettings.decodeMerging(old)
        XCTAssertTrue(s.aimEnabled)
        XCTAssertEqual(s.aimFOV, 10)
        XCTAssertEqual(s.botCount, MenuSettings().botCount)
    }

    func testPresetAndBotCountClamp() {
        var s = MenuSettings()
        s.apply(.strong)
        XCTAssertEqual(s.aimFOV, 14)
        s.botCount = 99
        XCTAssertEqual(s.sanitized().botCount, 10)
        XCTAssertEqual(ArenaModel.makeBots(count: 4).count, 4)
    }

    func testSegmentCircleOcclusion() {
        let a = SIMD2<Float>(0, 0), b = SIMD2<Float>(0, 20)
        XCTAssertTrue(ArenaModel.segmentHitsCircle(a, b, SIMD2<Float>(0.5, 10), 1))
        XCTAssertFalse(ArenaModel.segmentHitsCircle(a, b, SIMD2<Float>(5, 10), 1))
    }
}
