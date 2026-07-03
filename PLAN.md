# Kế Hoạch Phát Triển Ứng Dụng Smart Reader

> **Phiên bản kế hoạch:** 2.0 — Rebuild từ nền ReadBox sang Smart Reader  
> **Ngày cập nhật:** 2026-07-03

---

## 📋 Tổng Quan Dự Án

**Smart Reader** là ứng dụng camera-to-document thông minh, cho phép người dùng:
- Chụp hình tài liệu thực tế → OCR bằng PaddleOCR (Python server) → biên tập → xuất PDF chuyên nghiệp
- Chuyển đổi định dạng tài liệu: PDF ↔ Word ↔ Image
- Biên tập văn bản sau OCR với bộ công cụ giống Word (font, màu, căn lề…)
- Theo dõi tiến trình các job OCR realtime
- Xem bài viết hướng dẫn và công cụ tiện ích trên trang chủ

**Nguồn gốc:** Clone từ ReadBox → giữ lại Auth, Notification, Account; rebuild hoàn toàn điều hướng và các màn hình nghiệp vụ chính.

---

## 🏗️ Kiến Trúc Hiện Tại (Kế Thừa)

| Layer | Trạng thái | Ghi chú |
|---|---|---|
| Clean Architecture (Domain / Data) | ✅ Giữ nguyên | |
| BLoC / Cubit state management | ✅ Giữ nguyên | |
| Dependency Injection (GetIt) | ✅ Giữ nguyên | |
| Authentication (Login, Register, ForgotPassword) | ✅ Kế thừa | |
| i18n (VI / EN) | ✅ Kế thừa | |
| Routing system | ✅ Mở rộng | Thêm route mới |
| OCR BLoC (OcrJobCubit, OcrEditorCubit, OcrUploadCubit) | ✅ Kế thừa | Đã có |
| Tools (Word→PDF, Document Scanner) | ✅ Kế thừa | |
| Notification screens | ✅ Kế thừa | |
| Settings / Account screens | ✅ Kế thừa | |

---

## 🗺️ Điều Hướng Mới — Bottom Navigation (5 Tab)

```
┌──────────────────────────────────────────────────────┐
│                   Smart Reader App                    │
├──────────┬──────────┬──────────┬──────────┬──────────┤
│  🏠 Home │ 📋 OCR  │ 📷 Quét │ 🔔 Notif │ 👤 Tài  │
│  Trang   │ Danh    │ Tài liệu │  Thông   │  Khoản  │
│  chủ    │  sách   │          │   báo    │         │
└──────────┴──────────┴──────────┴──────────┴──────────┘
```

| Tab | Route | Screen | Trạng thái |
|---|---|---|---|
| Home | `/home` | `HomeScreen` | 🔨 Xây mới |
| OCR List | `/ocrList` | `OcrJobListScreen` | ✅ Đã có → tích hợp vào tab |
| Quét tài liệu | `/scanner` | `OcrUploadScreen` | ✅ Đã có → làm tab chính |
| Thông báo | `/notifications` | `NotificationScreen` | ✅ Kế thừa |
| Tài khoản | `/profile` | `ProfileScreen` | ✅ Kế thừa |

---

## 📦 Các Giai Đoạn Phát Triển

---

### **GIAI ĐOẠN 0: Rebuild Bottom Navigation Shell**
> Mục tiêu: Thay toàn bộ shell điều hướng cũ bằng BottomNavigationBar 5 tab.

#### 0.1. Tạo `AppShell` Widget
- [ ] Tạo `lib/ui/screen/app_shell.dart` — StatefulWidget giữ `PageController` / `IndexedStack` cho 5 tab
- [ ] Tích hợp `BottomNavigationBar` với icon + label theo thiết kế mới
- [ ] Badge số thông báo chưa đọc trên tab Notification (dùng `NotificationCubit`)
- [ ] Badge floating action (hoặc icon nổi bật) cho tab Quét tài liệu ở giữa

#### 0.2. Cập Nhật Routes
- [ ] Thêm `appShell` route làm màn hình chính sau login
- [ ] Giữ các route con (bookDetail, ocrEditor, settings…) không thay đổi
- [ ] Redirect `splashScreen` → `appShell` (nếu đã đăng nhập) thay vì `mainScreen` cũ

#### 0.3. Cấu Trúc File
```
lib/ui/screen/
  ├── app_shell.dart            ← THÊM MỚI
  ├── home/
  │   └── home_screen.dart      ← THÊM MỚI
  ├── ocr/
  │   ├── ocr_job_list_screen.dart   ✅ đã có
  │   ├── ocr_upload_screen.dart     ✅ đã có
  │   └── ocr_editor_screen.dart     ✅ đã có
  ├── notification/             ✅ kế thừa
  ├── settings/                 ✅ kế thừa
  └── auth/                     ✅ kế thừa
```

---

### **GIAI ĐOẠN 1: Màn Trang Chủ (Home Tab)**
> Mục tiêu: Xây `HomeScreen` — trung tâm điều hướng công cụ và nội dung bài viết.

#### 1.1. Thiết Kế Layout
```
HomeScreen
  ├── AppBar: Logo "Smart Reader" + Search icon
  ├── Section 1 — Công Cụ Chuyển Đổi (Horizontal ScrollView)
  │   ├── Card: PDF → Word
  │   ├── Card: Word → PDF
  │   ├── Card: Image → PDF
  │   ├── Card: PDF → Image
  │   └── Card: Nén PDF
  ├── Section 2 — Quét Nhanh (Banner CTA)
  │   └── Button "Quét tài liệu ngay" → chuyển sang tab Scanner
  ├── Section 3 — Job OCR Gần Đây (Horizontal List, max 5)
  │   └── "Xem tất cả" → chuyển sang tab OCR List
  └── Section 4 — Bài Viết / Hướng Dẫn (Vertical List)
      ├── Bài viết tip sử dụng OCR
      └── Hướng dẫn biên tập PDF
```

#### 1.2. Công Cụ Chuyển Đổi
- [ ] `ToolCardWidget` — card tái sử dụng (icon + label + onTap)
- [ ] Điều hướng tới `WordToPdfConverterScreen` (đã có)
- [ ] Điều hướng tới `DocumentScannerScreen` (đã có)
- [ ] Placeholder card cho Image→PDF, PDF→Image, Nén PDF (hiển thị "Coming Soon" badge)

#### 1.3. BLoC / Cubit
- [ ] `HomeCubit` — load job gần đây + bài viết (tái dùng `OcrJobCubit` + API bài viết nếu có)
- [ ] State: `HomeLoaded { recentJobs, articles }`

#### 1.4. Bài Viết (Articles)
- [ ] Model `ArticleModel { id, title, summary, thumbnailUrl, publishedAt }`
- [ ] API endpoint hoặc static data nếu backend chưa có
- [ ] `ArticleCardWidget` — thumbnail + title + date
- [ ] `ArticleDetailScreen` — WebView hoặc render Markdown

---

### **GIAI ĐOẠN 2: Màn Danh Sách OCR (OCR List Tab)**
> Mục tiêu: Nâng cấp `OcrJobListScreen` thành tab độc lập với UX tốt hơn.

#### 2.1. Tính Năng Hiện Có (Giữ Nguyên)
- ✅ Filter theo trạng thái: Tất cả / Đang chờ / Đang xử lý / Hoàn tất / Thất bại
- ✅ Pull-to-refresh + load-more
- ✅ Realtime status update
- ✅ Điều hướng sang `OcrEditorScreen`

#### 2.2. Nâng Cấp
- [ ] **Empty state đẹp** — illustration + nút "Quét ngay" khi chưa có job
- [ ] **Job card nâng cấp** — thêm thumbnail preview trang đầu tiên
- [ ] **Swipe to delete** — xoá job thất bại / đã xong
- [ ] **Search bar** — tìm kiếm theo tên file / ngày tạo
- [ ] **Batch actions** — chọn nhiều job để xoá hoặc xuất PDF

#### 2.3. BLoC Updates
- [ ] Thêm action `deleteJob(jobId)` vào `OcrJobCubit`
- [ ] Thêm action `searchJobs(query)` vào `OcrJobCubit`

---

### **GIAI ĐOẠN 3: Màn Quét Tài Liệu (Scanner Tab)**
> Mục tiêu: Biến `OcrUploadScreen` thành trung tâm công cụ OCR với UX camera-first.

#### 3.1. Layout Scanner Tab
```
ScannerScreen (tab chính)
  ├── Header: "Quét Tài Liệu"
  ├── Primary Action — Camera Scan (lớn, nổi bật)
  │   └── Mở camera → chụp → crop → upload
  ├── Secondary Actions (Grid 2x2)
  │   ├── Chọn ảnh từ thư viện
  │   ├── Chọn PDF sẵn có
  │   ├── Chụp nhiều trang (multi-page batch)
  │   └── Quét QR / Barcode (optional)
  └── Tip ngắn: "Đặt tài liệu phẳng, đủ ánh sáng"
```

#### 3.2. Luồng Camera Scan
```
[Mở Camera] 
  → [Preview realtime + auto edge detection] 
  → [Chụp / Chọn vùng crop] 
  → [Preview ảnh đã crop] 
  → [Xác nhận / Chụp thêm trang] 
  → [Upload lên server] 
  → [Tạo OCR Job] 
  → [Chuyển sang OcrJobListScreen với job mới]
```

#### 3.3. Dependencies Cần Thêm
- [ ] `edge_detection` hoặc `document_scanner` — tự động phát hiện viền tài liệu
- [ ] `camera` — camera preview
- [ ] `image_cropper` — crop thủ công nếu auto-detect sai

#### 3.4. Multi-page Support
- [ ] `MultiPageScanCubit` — quản lý danh sách ảnh đã chụp
- [ ] `PageThumbnailReel` — dải thumbnail nằm ngang, có thể sắp xếp lại
- [ ] Xác nhận thứ tự trang trước khi upload

---

### **GIAI ĐOẠN 4: Màn Biên Tập OCR (OCR Editor) — Nâng Cấp**
> Mục tiêu: Nâng cấp `OcrEditorScreen` thành rich-text editor giống Word.

#### 4.1. Tính Năng Hiện Có (Giữ Nguyên)
- ✅ Rail thumbnail trang (trái)
- ✅ Preview bbox click được
- ✅ Panel chỉnh sửa text / hình / bảng cơ bản

#### 4.2. Rich Text Editor Toolbar
```
Toolbar
  ├── Font family dropdown (Roboto, Times New Roman, Arial…)
  ├── Font size (8–72pt)
  ├── Bold / Italic / Underline / Strikethrough
  ├── Text color picker
  ├── Highlight color picker
  ├── Align: Left / Center / Right / Justify
  ├── List: Bullet / Numbered
  ├── Indent: tăng / giảm
  └── Insert: Hình ảnh / Bảng / Ngắt trang
```

#### 4.3. Dependencies
- [ ] `flutter_quill` — rich text editor engine
- [ ] `flutter_colorpicker` — color picker
- [ ] `google_fonts` — font family preview

#### 4.4. BLoC Updates (`OcrEditorCubit`)
- [ ] `updateTextBlock(blockId, quillDelta)` — lưu nội dung rich text
- [ ] `applyFormatToAll(format)` — áp dụng style cho toàn bộ tài liệu
- [ ] `reorderPage(from, to)` — kéo thả sắp xếp lại trang
- [ ] `exportToPdf()` — gửi lên server render PDF với layout cuối cùng

#### 4.5. Export PDF Flow
```
[Nhấn Xuất PDF]
  → [Chọn layout: A4 / Letter / Gốc]
  → [Chọn chất lượng: Draft / Standard / High]
  → [Server render PDF]
  → [Download / Share / Lưu vào thư viện]
```

---

### **GIAI ĐOẠN 5: Màn Thông Báo (Notification Tab)**
> Kế thừa hoàn toàn từ ReadBox, chỉ tích hợp vào tab mới.

- ✅ `NotificationScreen` — danh sách thông báo
- ✅ `NotificationDetailScreen` — chi tiết thông báo
- ✅ `NotificationCubit` — đếm unread, load list
- [ ] Cập nhật: Thêm loại thông báo `ocr_job_completed` hiển thị đúng icon + action

---

### **GIAI ĐOẠN 6: Màn Tài Khoản (Account Tab)**
> Kế thừa từ ReadBox, bổ sung phần liên quan đến OCR.

- ✅ `ProfileScreen` — thông tin cá nhân, avatar
- ✅ `SettingsScreen` — cài đặt app, ngôn ngữ, theme
- ✅ `SubscriptionPlanScreen` — gói dịch vụ
- ✅ `PaymentHistoryScreen` — lịch sử thanh toán
- [ ] **Thêm mục "Lưu trữ OCR"** — dung lượng đã dùng / còn lại
- [ ] **Thêm mục "Ngôn ngữ OCR mặc định"** — Vietnamese / English / Auto

---

## 🎨 Design System

### Theme & Color
| Token | Giá trị gợi ý |
|---|---|
| Primary | `#1A6BFF` (xanh dương đậm — chuyên nghiệp) |
| Secondary | `#00C7B1` (teal — công nghệ) |
| Background | `#F8F9FC` |
| Surface | `#FFFFFF` |
| Error | `#FF4444` |
| Success | `#2ECC71` |

### Bottom Nav Icons
| Tab | Icon |
|---|---|
| Home | `Icons.home_rounded` |
| OCR List | `Icons.list_alt_rounded` |
| Quét | `Icons.document_scanner_rounded` (FAB-style) |
| Thông báo | `Icons.notifications_rounded` |
| Tài khoản | `Icons.person_rounded` |

### Typography
- Tiêu đề màn hình: **Inter Bold 20px**
- Section header: **Inter SemiBold 16px**
- Body: **Inter Regular 14px**
- Caption: **Inter Regular 12px**

---

## 🔗 Tích Hợp Backend (codebase-admin + codebase-ocr)

### API Endpoints Cần Có

| Endpoint | Mô tả | Backend |
|---|---|---|
| `POST /ocr/jobs` | Tạo job OCR mới từ ảnh | codebase-ocr |
| `GET /ocr/jobs` | Danh sách job (filter, paginate) | codebase-ocr |
| `GET /ocr/jobs/:id` | Chi tiết + kết quả OCR | codebase-ocr |
| `DELETE /ocr/jobs/:id` | Xoá job | codebase-ocr |
| `PUT /ocr/jobs/:id/content` | Cập nhật nội dung biên tập | codebase-ocr |
| `POST /ocr/jobs/:id/export-pdf` | Xuất PDF | codebase-ocr |
| `POST /converter/word-to-pdf` | Chuyển Word → PDF | codebase-admin |
| `POST /converter/pdf-to-word` | Chuyển PDF → Word | codebase-admin |
| `GET /articles` | Danh sách bài viết hướng dẫn | codebase-admin |
| `GET /articles/:id` | Chi tiết bài viết | codebase-admin |

### WebSocket / SSE
- [ ] Realtime OCR job status: `WS /ocr/jobs/:id/status`
- [ ] Dùng để cập nhật progress bar trong `OcrJobListScreen`

---

## 📁 Cấu Trúc Thư Mục Mục Tiêu

```
lib/
  ├── blocs/
  │   ├── ocr/                    ✅ đã có
  │   ├── home/
  │   │   └── home_cubit.dart     🔨 mới
  │   └── ...
  ├── domain/
  │   ├── data/
  │   │   ├── models/
  │   │   │   ├── article_model.dart   🔨 mới
  │   │   │   └── ...
  │   │   └── ...
  │   └── repositories/
  │       ├── article_repository.dart  🔨 mới
  │       └── ...
  └── ui/
      └── screen/
          ├── app_shell.dart           🔨 mới (BottomNav shell)
          ├── home/
          │   ├── home_screen.dart     🔨 mới
          │   └── widgets/
          │       ├── tool_card_widget.dart
          │       ├── recent_job_card.dart
          │       └── article_card_widget.dart
          ├── ocr/                     ✅ nâng cấp
          │   ├── ocr_job_list_screen.dart
          │   ├── ocr_upload_screen.dart
          │   ├── ocr_editor_screen.dart
          │   └── widgets/
          │       └── editor_toolbar.dart  🔨 mới
          ├── scanner/                 🔨 mới
          │   ├── scanner_screen.dart
          │   └── multi_page_scan_screen.dart
          ├── notification/            ✅ kế thừa
          ├── settings/                ✅ kế thừa
          └── auth/                    ✅ kế thừa
```

---

## ✅ Checklist Tổng Thể

### Giai Đoạn 0 — Navigation Shell
- [ ] Tạo `AppShell` với BottomNavigationBar 5 tab
- [ ] Cập nhật routing (splash → appShell)
- [ ] Badge thông báo unread trên tab 4

### Giai Đoạn 1 — Home Screen
- [ ] Layout HomeScreen (tools + recent jobs + articles)
- [ ] `ToolCardWidget`
- [ ] `HomeCubit` + `HomeState`
- [ ] `ArticleModel` + `ArticleCardWidget`
- [ ] Banner CTA "Quét ngay"

### Giai Đoạn 2 — OCR List (Nâng Cấp)
- [ ] Empty state đẹp
- [ ] Swipe-to-delete
- [ ] Search bar
- [ ] Job thumbnail preview

### Giai Đoạn 3 — Scanner Tab
- [ ] `ScannerScreen` layout
- [ ] Camera integration + edge detection
- [ ] Multi-page batch flow
- [ ] Upload → tạo job → điều hướng

### Giai Đoạn 4 — OCR Editor (Nâng Cấp)
- [ ] `flutter_quill` rich text toolbar
- [ ] Font family + size + color picker
- [ ] Export PDF flow với tuỳ chọn layout
- [ ] Drag-reorder pages

### Giai Đoạn 5 & 6 — Notification & Account
- [ ] Tích hợp vào tab shell
- [ ] Thêm loại noti `ocr_job_completed`
- [ ] Thêm mục "Lưu trữ OCR" trong Account

---

## 🚀 Thứ Tự Ưu Tiên Triển Khai

```
[P0] AppShell + Bottom Nav → Nền tảng cho mọi thứ
  ↓
[P1] HomeScreen cơ bản → Trang chủ có thể demo
  ↓
[P1] ScannerScreen → Core feature chính
  ↓
[P2] OCR List nâng cấp → UX tốt hơn
  ↓
[P2] OCR Editor + Rich Text → Biên tập chuyên nghiệp
  ↓
[P3] Articles + ArticleDetail → Nội dung & SEO
  ↓
[P3] Account OCR Storage → Quản lý tài nguyên
```
