# TAN LOC MENU — Aim Assist & ESP Debug (iOS, SwiftUI)

> **Trạng thái trung thực:** mã nguồn được viết trên môi trường Linux không có Swift/Xcode.
> **Chưa biên dịch, chưa chạy trên iPhone, chưa có IPA.** Mọi mục "Kiểm thử" bên dưới là việc bạn cần làm trên Mac.

---------------------------------------------------------------------

## 1. Phân tích gói `KHOÁ_HỌC_MAKE_FILE_800K_1.zip`

Đã mở và đọc **một phần** (mẫu đại diện), không đọc từng file trong ~60 file.

| Thư mục | Nội dung quan sát được | Là mã nguồn thực? |
|---|---|---|
| `CODE/` (~40 `.txt`) | Một file Unity C# (`Aimlock.txt`, lớp `AimAssist : MonoBehaviour`, dùng `Physics.OverlapSphere/Raycast`). Phần lớn file `*Base.txt`/`V2` là **C++ header được mã hoá base64** (phần đầu giải mã ra: hàm `lerp`, deadzone, làm mượt; include `install_file.hpp`). Hai file `Đam.txt.rc4.enc.base45` bị **mã hoá RC4 + base45**. | Có mã thật, nhưng chỉ là toán làm mượt/clamp. **Không thấy** liên kết nào tới game của bạn. |
| `FORM IOS/` (~20 file) | `.mobileconfig`, `.plist`, `.crt`: cấu hình DNS-over-HTTPS, VPN, Wi-Fi, **chứng chỉ gốc (root CA)**; nhãn như "CHEAT IOS", "ANTI-CRACK-SERVER". | Không phải mã nguồn app; là profile cấu hình thiết bị. |
| `FORM ADR/` (2 file) | Mẫu cho Android. | Chưa mở. |
| Không có | `.exe`, dự án Xcode/Unity, asset, API của game, `install_file.hpp`. | — |

**Thiếu:** `install_file.hpp`/`install_files.hpp`, khoá giải mã RC4, mã nguồn/API game của bạn, ID bundle của game.

**Phần tôi KHÔNG chuyển đổi/tái sử dụng:** các profile cấu hình (root CA/DNS/VPN), payload mã hoá, và mã nhằm tác động vào game bên thứ ba. Tên file ("Bám Đầu", "Khoá Tâm", "Fix Lạc Đạn"…) cho thấy bộ này được làm cho một game bắn súng di động có sẵn, và tôi không thấy gì chứng minh nó thuộc game của bạn.
Toàn bộ mã trong dự án này **tôi viết mới** theo đặc tả của bạn; chỉ dùng ý tưởng phổ thông (làm mượt kiểu lerp, chọn mục tiêu trong FOV).

**Về `.exe → .ipa`:** không có `.exe` nào trong gói, và dù có thì không thể chuyển trực tiếp.

## 2. Thực tế kiến trúc iOS (quan trọng)

Một app iOS độc lập **không thể** vẽ đè lên app khác hay đọc danh sách đối tượng của game khác (sandbox). Con đường hợp lệ duy nhất là **nhúng module này vào chính game của bạn**, và game báo dữ liệu qua `GameDebugProvider`.
Vì vậy dự án gồm:
1. **Module tái sử dụng** (`Core/` + `ESPOverlay`): Aim Assist, ESP, cài đặt, menu.
2. **Đấu trường luyện tập tích hợp sẵn** (`Demo/`): bot di chuyển, cột che khuất, nút bắn — để mọi chức năng chạy thật và kiểm thử được ngay, không có nút giả.

## 3. Chức năng đã cài đặt

| Chức năng | Cách hoạt động |
|---|---|
| Aim Assist | Chọn bot còn sống, **không bị che**, gần tâm ngắm nhất trong vòng FOV; nhích camera theo hệ số làm mượt, giới hạn tốc độ tối đa (°/s). Tuỳ chọn: ngắm thân/đầu, chỉ hoạt động khi đang kéo/bắn. Vòng FOV vẽ quanh tâm ngắm. |
| ESP Debug | Khung (nét đứt nếu bị che), tên, khoảng cách (m), thanh máu; mục tiêu đang được hỗ trợ tô trắng. Chỉ đọc `DebugEntity` do game cung cấp. |
| Menu | Bật/tắt riêng từng chức năng (nhãn ON/OFF), kéo thả bằng thanh tiêu đề, nút thu gọn → nút tròn "TL" (chạm để mở, kéo để di chuyển), luôn nằm trong màn hình & safe area. |
| Lưu cài đặt | `UserDefaults` (JSON, debounce 0.3s, ghi ngay khi app xuống nền). Dữ liệu hỏng/NaN → tự về mặc định/ép về khoảng hợp lệ. |
| Giao diện | Dark, đen + xanh dương, thiết kế cho iPhone (dọc và ngang). |

Giới hạn đã biết: phép chiếu là **tuyến tính theo góc** (đủ cho debug, không phải ma trận view-projection thật); bot trong demo bị che chỉ bởi cột (tính trên mặt phẳng); nếu thêm trường vào `MenuSettings` thì dữ liệu cũ sẽ bị reset về mặc định (chưa có migrate).

## 4. Cấu trúc

```
project.yml                   # XcodeGen
TanLocMenu/
  TanLocMenuApp.swift
  Core/   DebugAPI.swift  ScreenProjection.swift  AimAssist.swift  MenuSettings.swift
  Demo/   ArenaModel.swift  ArenaView.swift       # game luyện tập + ESPOverlay
  UI/     Theme.swift  Components.swift  FloatingMenu.swift
TanLocMenuTests/TanLocMenuTests.swift   # 9 unit test
```

## 5. Build, ký và cài lên iPhone

Yêu cầu: Mac + Xcode 15+, iPhone iOS 16+, Apple ID.

**Cách A – XcodeGen**
```bash
brew install xcodegen
cd TanLocMenu && xcodegen generate && open TanLocMenu.xcodeproj
```
**Cách B – thủ công (nếu A lỗi):** Xcode → New Project → iOS App (SwiftUI, tên `TanLocMenu`, iOS 16) → xoá `ContentView.swift`/`App` mặc định → kéo thư mục `TanLocMenu/` vào project → thêm Unit Test target và kéo `TanLocMenuTests.swift` vào.

Ký & cài:
1. Target **TanLocMenu** → *Signing & Capabilities* → tick *Automatically manage signing*, chọn **Team** (Apple ID cá nhân dùng được), đổi **Bundle Identifier** thành duy nhất của bạn.
2. Cắm iPhone, bật **Settings → Privacy & Security → Developer Mode**, khởi động lại.
3. Chọn iPhone làm destination → **Run (⌘R)**. Lần đầu: Settings → General → VPN & Device Management → tin cậy chứng chỉ nhà phát triển.
4. Tài khoản miễn phí: app hết hạn sau 7 ngày, cài lại bằng Xcode. Muốn phát hành thử cho nhiều thiết bị: Apple Developer Program + **TestFlight** (Product → Archive → Distribute).
5. IPA chỉ có sau **Product → Archive** thành công; tôi chưa tạo bản nào.

## 6. Tích hợp vào game của bạn

1. Copy `Core/` + `UI/` + `ESPOverlay` (trong `ArenaView.swift`) vào game.
2. Cho lớp điều khiển camera của game cài `GameDebugProvider`: `camera`, `viewport`, `debugEntities()` (kèm `isOccluded` từ raycast của game), `applyAimCorrection`.
3. Mỗi frame gọi `AimAssistController.update(...)`; dựng `ESPOverlay` đè lên khung nhìn.
4. Chỉ bật trong build debug/chế độ luyện tập, ví dụ bọc bằng `#if DEBUG`.

## 7. Quy trình kiểm thử

**Unit test (⌘U):** projection, chọn mục tiêu, bỏ qua mục tiêu bị che/đã chết, giới hạn tốc độ, deadzone, ép giá trị hợp lệ, lưu/đọc cài đặt và dữ liệu hỏng, che khuất bởi cột. *Chưa chạy lần nào.*

**Trên iPhone (thủ công):**
| # | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Mở app | Thấy đấu trường tối, tâm ngắm xanh, menu góc trái trên. |
| 2 | Kéo ngón tay trên nền | Camera quay; vạch mốc 15° trượt theo. |
| 3 | Bật ESP | Khung + tên + mét + thanh máu quanh bot; bot sau cột hiện nét đứt, màu nhạt. |
| 4 | Tắt từng mục Khung/Tên/Khoảng cách/Thanh máu | Phần tương ứng biến mất ngay. |
| 5 | Tắt ESP | Mọi lớp phủ biến mất; các công tắc con mờ và không bấm được. |
| 6 | Aim Assist OFF, tự ngắm bắn ~20 phát | Ghi lại ACC làm mốc. |
| 7 | Bật Aim Assist (FOV 8°, lực 0,12), kéo nhẹ gần bot | Tâm ngắm bị kéo dần về bot, HUD hiện `LOCK ▸ BOT_n`, vòng FOV xuất hiện. |
| 8 | Tăng FOV/lực; giảm tốc độ tối đa | Hút mạnh/yếu rõ rệt; tốc độ tối đa giới hạn chuyển động. |
| 9 | Đổi Thân ↔ Đầu | Điểm ngắm đổi cao/thấp. |
| 10 | "Chỉ khi đang kéo/bắn" bật, thả tay | Camera đứng yên; tắt mục này thì camera tự trôi về bot. |
| 11 | Đưa bot ra sau cột | Mất `LOCK`, không hút vào bot bị che. |
| 12 | Bắn trúng | Tâm ngắm nháy trắng, HITS tăng; 3 phát hạ bot, 1,5s sau hồi sinh. |
| 13 | Kéo header sang mép/xoay máy | Menu không ra khỏi màn hình/vùng tai thỏ. |
| 14 | Nhấn `–` | Thu gọn thành nút "TL"; chạm → mở; kéo → di chuyển. |
| 15 | Đổi vài cài đặt, vuốt thoát app, mở lại | Cài đặt và vị trí menu được giữ. |
| 16 | "Khôi phục mặc định" | Giá trị về mặc định, vị trí menu giữ nguyên. |

## 8. Rủi ro chưa được xác minh
- Chưa biên dịch: có thể còn lỗi cú pháp/cảnh báo nhỏ khi mở trong Xcode.
- `geo.safeAreaInsets` khi `.ignoresSafeArea()` đặt ngoài `GeometryReader` cần kiểm tra thực tế trên máy có tai thỏ/Dynamic Island.
- Hiệu năng: mỗi frame dựng lại SwiftUI Canvas (6 bot nên nhẹ); game thật nên vẽ ESP bằng Metal/SpriteKit của game.

## 9. Không có Mac / iPhone 7 Plus (tối đa iOS 15.8)
- Deployment target đã hạ xuống **iOS 15.0** (các API đang dùng đều có từ iOS 15; chưa kiểm chứng trên máy thật).
- Build không cần Mac: đưa project lên GitHub → tab Actions → "Build unsigned IPA" → Run workflow → tải artifact `TanLocMenu.ipa`. (Workflow chưa chạy thử.)
- Ký + cài: dùng Sideloadly (Windows/Mac) với Apple ID của bạn, cắm cáp iPhone. Apple ID miễn phí: hết hạn sau 7 ngày.

## 10. Phiên bản mở rộng (menu 4 tab)
- **AIM:** bật/tắt; preset NHẸ / VỪA / MẠNH; FOV, lực, tốc độ tối đa; ngắm thân/đầu; chỉ hoạt động khi đang kéo/bắn.
- **ESP:** khung, tên, khoảng cách, thanh máu, đường kẻ tới mục tiêu, chấm đầu.
- **ARENA:** số bot (1–10), tốc độ bot, độ nhạy kéo camera.
- **UI:** rung phản hồi, độ đậm menu, khôi phục mặc định.
- Cài đặt cũ thiếu trường mới được giữ lại (merge với mặc định) thay vì bị reset. Có thêm 2 unit test cho phần này.
- Vẫn **chưa biên dịch/chạy thử**.
