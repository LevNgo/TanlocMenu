import SwiftUI
import UIKit

/// ESP Debug: chỉ đọc `DebugEntity` + `ScreenProjection` — dùng lại nguyên cho game của bạn.
struct ESPOverlay: View {
    let entities: [DebugEntity]
    let projection: ScreenProjection
    let settings: MenuSettings
    let highlightedID: Int?

    var body: some View {
        Canvas { ctx, size in
            for e in entities {
                guard let box = projection.boundingRect(base: e.position, height: e.height, halfWidth: 0.3) else { continue }
                let color = e.id == highlightedID ? Theme.espTarget : (e.isOccluded ? Theme.espHidden : Theme.espVisible)
                if settings.espBox {
                    ctx.stroke(Path(box.rect), with: .color(color),
                               style: StrokeStyle(lineWidth: 1.5, dash: e.isOccluded ? [4, 3] : []))
                }
                if settings.espSnaplines {
                    var line = Path()
                    line.move(to: CGPoint(x: size.width / 2, y: size.height))
                    line.addLine(to: CGPoint(x: box.rect.midX, y: box.rect.maxY))
                    ctx.stroke(line, with: .color(color.opacity(0.5)), lineWidth: 1)
                }
                if settings.espHeadDot {
                    let r = max(2, box.rect.width * 0.12)
                    let c = CGPoint(x: box.rect.midX, y: box.rect.minY + box.rect.height * 0.08)
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(color))
                }
                if settings.espHealth {
                    let frac = CGFloat(max(0, e.health)) / CGFloat(max(1, e.maxHealth))
                    let bar = CGRect(x: box.rect.minX - 6, y: box.rect.minY, width: 3, height: box.rect.height)
                    ctx.fill(Path(bar), with: .color(Color.black.opacity(0.6)))
                    ctx.fill(Path(CGRect(x: bar.minX, y: bar.maxY - bar.height * frac, width: 3, height: bar.height * frac)),
                             with: .color(Theme.accent))
                }
                var parts: [String] = []
                if settings.espName { parts.append(e.name) }
                if settings.espDistance { parts.append(String(format: "%.0fm", box.distance)) }
                if !parts.isEmpty {
                    ctx.draw(Text(parts.joined(separator: " · "))
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(color),
                             at: CGPoint(x: box.rect.midX, y: box.rect.minY - 3), anchor: .bottom)
                }
            }
        }
    }
}

/// Cảnh đấu trường (vẽ bot + cột che), sắp xếp xa → gần.
private struct SceneLayer: View {
    let projection: ScreenProjection
    let entities: [DebugEntity]
    let pillars: [ArenaModel.Pillar]

    var body: some View {
        Canvas { ctx, size in
            let horizon = projection.screenY(relPitch: -projection.camera.pitch)
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.04, green: 0.07, blue: 0.14)))
            ctx.fill(Path(CGRect(x: 0, y: horizon, width: size.width, height: max(0, size.height - horizon))),
                     with: .color(Color(red: 0.06, green: 0.08, blue: 0.11)))

            // Vạch mốc mỗi 15° để thấy rõ chuyển động camera.
            for k in -12...12 {
                let rel = ScreenProjection.wrap180(Float(k) * 15 - projection.camera.yaw)
                guard abs(rel) < projection.camera.hFOV / 2 + 1 else { continue }
                let x = projection.screenX(relYaw: rel)
                var p = Path()
                p.move(to: CGPoint(x: x, y: horizon)); p.addLine(to: CGPoint(x: x, y: size.height))
                ctx.stroke(p, with: .color(Theme.accent.opacity(0.08)), lineWidth: 1)
            }
            var h = Path()
            h.move(to: CGPoint(x: 0, y: horizon)); h.addLine(to: CGPoint(x: size.width, y: horizon))
            ctx.stroke(h, with: .color(Theme.accent.opacity(0.25)), lineWidth: 1)

            var items: [(dist: Float, rect: CGRect, isBot: Bool)] = []
            for p in pillars {
                let base = SIMD3<Float>(p.center.x, 0, p.center.y)
                if let b = projection.boundingRect(base: base, height: p.height, halfWidth: p.radius) {
                    items.append((b.distance, b.rect, false))
                }
            }
            for e in entities {
                if let b = projection.boundingRect(base: e.position, height: e.height, halfWidth: 0.3) {
                    items.append((b.distance, b.rect, true))
                }
            }
            for item in items.sorted(by: { $0.dist > $1.dist }) {
                if item.isBot {
                    ctx.fill(Path(roundedRect: item.rect, cornerRadius: item.rect.width * 0.3),
                             with: .color(Color(red: 0.80, green: 0.32, blue: 0.28)))
                    let d = item.rect.width * 0.75
                    ctx.fill(Path(ellipseIn: CGRect(x: item.rect.midX - d / 2, y: item.rect.minY, width: d, height: d)),
                             with: .color(Color(red: 0.92, green: 0.55, blue: 0.45)))
                } else {
                    ctx.fill(Path(roundedRect: item.rect, cornerRadius: 3),
                             with: .color(Color(red: 0.20, green: 0.24, blue: 0.32)))
                }
            }
        }
    }
}

private struct CrosshairLayer: View {
    let hFOV: Float
    let settings: MenuSettings
    let hitFlash: Bool

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let color: Color = hitFlash ? .white : Theme.accent
            var p = Path()
            for d in [CGPoint(x: 1, y: 0), CGPoint(x: -1, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: 0, y: -1)] {
                p.move(to: CGPoint(x: c.x + d.x * 6, y: c.y + d.y * 6))
                p.addLine(to: CGPoint(x: c.x + d.x * 14, y: c.y + d.y * 14))
            }
            ctx.stroke(p, with: .color(color), lineWidth: 2)
            if settings.aimEnabled {
                let r = CGFloat(settings.aimFOV / hFOV) * size.width
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                           with: .color(Theme.accent.opacity(0.35)),
                           style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
        }
    }
}

struct ArenaView: View {
    @ObservedObject var model: ArenaModel
    @ObservedObject var store: SettingsStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var lastDrag: CGPoint?

    var body: some View {
        GeometryReader { geo in
            let proj = ScreenProjection(camera: model.camera, viewport: geo.size)
            ZStack(alignment: .topLeading) {
                SceneLayer(projection: proj, entities: model.debugEntities(), pillars: model.pillars)
                    .allowsHitTesting(false)

                if store.settings.espEnabled {
                    ESPOverlay(entities: model.debugEntities(), projection: proj,
                               settings: store.settings, highlightedID: model.lockedTargetID)
                        .allowsHitTesting(false)
                }

                Color.clear.contentShape(Rectangle()).gesture(lookGesture)

                CrosshairLayer(hFOV: model.camera.hFOV, settings: store.settings, hitFlash: model.hitFlash)
                    .allowsHitTesting(false)

                hud(insets: geo.safeAreaInsets)
                fireButton(insets: geo.safeAreaInsets)

                FloatingMenu(store: store, container: geo.size, insets: geo.safeAreaInsets)
            }
            .onAppear { model.viewport = geo.size }
            .onChange(of: geo.size) { model.viewport = $0 }
        }
        .background(Theme.bg)
        .ignoresSafeArea()
        .onAppear {
            model.settingsProvider = { [store] in store.settings }
            Haptics.enabled = store.settings.hapticsEnabled
            model.start()
        }
        .onChange(of: store.settings.hapticsEnabled) { Haptics.enabled = $0 }
        .onDisappear { model.stop() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { model.start() } else { model.stop(); store.flush() }
        }
    }

    private var lookGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                if let last = lastDrag { model.look(dx: v.location.x - last.x, dy: v.location.y - last.y) }
                lastDrag = v.location
                model.isLooking = true
            }
            .onEnded { _ in
                lastDrag = nil
                model.isLooking = false
            }
    }

    private func hud(insets: EdgeInsets) -> some View {
        let acc = model.shots == 0 ? 0 : Int((Double(model.hits) / Double(model.shots) * 100).rounded())
        return VStack(alignment: .trailing, spacing: 6) {
            Text("SHOTS \(model.shots)   HITS \(model.hits)   ACC \(acc)%")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.textPrimary)
            if let name = model.lockedTargetName {
                Text("LOCK ▸ \(name)")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundColor(Theme.accent)
            }
            Button("RESET") { model.resetStats() }
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.top, insets.top + 10)
        .padding(.trailing, insets.trailing + 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    private func fireButton(insets: EdgeInsets) -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                ZStack {
                    Circle().fill(Theme.accent.opacity(model.isFiring ? 0.9 : 0.55))
                    Circle().stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                    Text("BẮN").font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundColor(.white)
                }
                .frame(width: 84, height: 84)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            guard !model.isFiring else { return }
                            model.isFiring = true
                            Haptics.impact(.medium)
                            model.fire()
                        }
                        .onEnded { _ in model.isFiring = false }
                )
                .accessibilityLabel("Bắn")
                .accessibilityAddTraits(.isButton)
            }
        }
        .padding(.bottom, insets.bottom + 24)
        .padding(.trailing, insets.trailing + 28)
    }
}
