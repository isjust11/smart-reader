# Smart Reader — App fork từ Readbox

App này được **fork độc lập** từ Readbox (copy toàn bộ source) để phát triển sản phẩm OCR.
Thư mục: `readbox/smart-reader/` — nằm trên nhánh `smart-reader`.

> Lệnh Flutter phải chạy **trong thư mục `smart-reader/`** (đây là một Flutter project độc lập), không chạy ở thư mục readbox gốc.

---

## 1. Những gì đã được đổi sẵn

| Hạng mục | Readbox | Smart Reader |
|---|---|---|
| Android `applicationId` + `namespace` | `com.hungvv.readbox` | **`com.hungvv.smartreader`** |
| Android label (`AndroidManifest`) | `readbox` | **Smart Reader** |
| Android `app_name` (`strings.xml`) | `ReadBox` | **Smart Reader** |
| `MainActivity` package | `com.hungvv.readbox` | **`com.hungvv.smartreader`** (file mới: `.../kotlin/com/hungvv/smartreader/MainActivity.kt`) |
| iOS `PRODUCT_BUNDLE_IDENTIFIER` | `com.hungvv.readbox` | **`com.hungvv.smartreader`** |
| iOS `CFBundleDisplayName` | `Readbox` | **Smart Reader** |
| iOS `CFBundleName` | `readbox` | `smart_reader` |
| pubspec `description` | readbox… | Smart Reader… |

> Lưu ý: **tên package Dart vẫn giữ `readbox`** trong `pubspec.yaml` để không phải sửa toàn bộ `import 'package:readbox/...'`. Có thể đổi sau (xem mục 4).

---

## 2. BẮT BUỘC làm trước khi build (cần tài khoản/console bên ngoài)

App vẫn đang trỏ tới cấu hình dịch vụ của Readbox theo `applicationId` cũ → build sẽ lỗi hoặc dùng nhầm dữ liệu Readbox. Cần cập nhật:

### 2.1 Firebase (BẮT BUỘC — nếu không build Android sẽ fail)
Plugin `com.google.gms.google-services` yêu cầu `google-services.json` có client trùng `applicationId`.
- Cách nhanh: cài FlutterFire CLI rồi chạy trong `smart-reader/`:
  ```bash
  flutterfire configure
  ```
  Chọn/ tạo Firebase project, đăng ký app Android `com.hungvv.smartreader` và iOS `com.hungvv.smartreader`. Lệnh này sẽ ghi đè:
  - `android/app/google-services.json`
  - `ios/Runner/GoogleService-Info.plist` (và `ios/GoogleService-Info.plist`)
  - `lib/firebase_options.dart`
- Hoặc thủ công: vào Firebase Console → thêm 2 app với applicationId/bundle mới → tải lại 3 file trên.

### 2.2 Google Sign-In
- Phụ thuộc Firebase ở trên. Sau khi có `GoogleService-Info.plist` mới, cập nhật URL scheme `REVERSED_CLIENT_ID` trong `ios/Runner/Info.plist` (mục `google`).
- Android: thêm SHA-1/SHA-256 của keystore Smart Reader vào Firebase (xem `docs/GET_SHA1_FOR_GOOGLE_SIGNIN.md`).

### 2.3 AdMob (nếu giữ quảng cáo)
- `android/app/src/main/AndroidManifest.xml` → `com.google.android.gms.ads.APPLICATION_ID`.
- `ios/Runner/Info.plist` → `GADApplicationIdentifier`.
- Hiện đang là App ID của Readbox.

### 2.4 RevenueCat (nếu giữ subscription)
- Cập nhật `REVENUECAT_IOS_KEY` / `REVENUECAT_ANDROID_KEY` trong `.env.dev` / `.env.prod` cho app mới.

### 2.5 Facebook Login (nếu dùng)
- `android/.../res/values/strings.xml`: `facebook_app_id`, `facebook_client_token`, `fb_login_protocol_scheme`.
- `ios/Runner/Info.plist`: `FacebookAppID`, `FacebookClientToken`, `FacebookDisplayName`, URL scheme `fb...`.

### 2.6 Deep links / URL scheme (khuyến nghị đổi để tránh đụng Readbox)
Hiện vẫn dùng scheme `readbox` và host `readbox.pro.vn`. Nếu cài cả 2 app cùng máy sẽ tranh scheme. Đổi sang `smartreader`:
- `AndroidManifest.xml`: các `intent-filter` `android:scheme="readbox"` và host `readbox.pro.vn`.
- `ios/Runner/Info.plist`: `CFBundleURLSchemes` (`readbox`).
- Code xử lý `app_links` trong `lib/` (tìm chuỗi `readbox://`).

### 2.7 Icon & Splash
- Thay `assets/images/logo.png` bằng logo Smart Reader rồi tạo lại:
  ```bash
  dart run flutter_launcher_icons
  dart run flutter_native_splash:create
  ```

### 2.8 Ký release (Android)
- Tạo keystore riêng + `android/key.properties` cho Smart Reader (không dùng chung keystore Readbox khi phát hành).

---

## 3. Cấu hình API backend (OCR)
- Trỏ `.env.dev` / `.env.prod` tới backend OCR (xem `docs/OCR_BACKEND_PLAN.md` ở repo backend).
- Theo roadmap app trong `docs/OCR_APP_PLAN.md`.

---

## 4. (Tuỳ chọn) Đổi tên package Dart `readbox` -> `smart_reader`
Nếu muốn định danh hoàn toàn riêng:
1. Sửa `name: readbox` -> `name: smart_reader` trong `pubspec.yaml`.
2. Tìm-thay toàn bộ `package:readbox/` -> `package:smart_reader/` trong `lib/` và `test/`.
3. `flutter pub get` lại.

---

## 5. Build & chạy
```bash
cd smart-reader
flutter pub get
flutter run            # dev
# hoặc
flutter build apk --release
flutter build ipa
```

---

## 6. Checklist nhanh
- [ ] 2.1 Firebase reconfigure (bắt buộc)
- [ ] 2.2 Google Sign-In (SHA + reversed client id)
- [ ] 2.3 AdMob app id
- [ ] 2.4 RevenueCat keys
- [ ] 2.5 Facebook app id (nếu dùng)
- [ ] 2.6 Đổi deep link scheme sang `smartreader`
- [ ] 2.7 Icon + splash mới
- [ ] 2.8 Keystore release riêng
- [ ] 3. Trỏ API backend OCR
- [ ] 4. (tuỳ chọn) đổi tên package Dart
