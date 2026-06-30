# OCR App Plan — App Flutter mới chuyên OCR

> Mục tiêu: App di động **mới** chuyên dụng để OCR tài liệu. Người dùng chụp/chọn PDF–ảnh → upload lên server → server xử lý bất đồng bộ (RabbitMQ + PaddleOCR worker) → app nhận kết quả (text + bbox) và cho phép đọc, tìm kiếm, TTS, dịch/AI, xuất file.
>
> Đây là app tách rời Readbox nhưng **tuân thủ chuẩn coding Readbox** (`.agents/skills/flutter-standard`) để đồng nhất hệ sinh thái và tái dùng pattern. File plan đặt tạm trong readbox/docs; khi scaffold repo app mới có thể chuyển sang đó.

Ngôn ngữ OCR: **vi + en** (auto-detect). Realtime trạng thái qua **Socket.IO/FCM**.

---

## 0. Quy chuẩn áp dụng (bắt buộc)

- State: `flutter_bloc` (Cubit) + `equatable`; kế thừa `BaseBloc`/`BaseListCubit` nếu có.
- DI: `get_it` — đăng ký network/datasource/repository/cubit trong `injection_container.dart`.
- UI: không hardcode màu/dimens → dùng `lib/res/`; tái dùng widget chung; i18n `intl` (`.arb`) song ngữ vi/en.
- Style: file `snake_case`, class `PascalCase`, biến/hàm `camelCase`, `const` khi có thể.
- Async: bọc `try-catch`, báo lỗi qua State (không chỉ print).

---

## 0.1 Tích hợp backend

- `POST /ocr/jobs` (multipart file + `lang`) → `{ jobId, status }`.
- `GET /ocr/jobs`, `GET /ocr/jobs/:id`, `GET /ocr/jobs/:id/result?page=`.
- `POST /ocr/jobs/:id/export`.
- Socket event `ocr.job.updated` để cập nhật tiến độ.

---

## Phase 1 — Khởi tạo project & nền tảng (P4)

- [ ] Tạo Flutter app mới; cấu hình `.env` (API host/port — tái dùng pattern Readbox `flutter_dotenv`).
- [ ] Network: Dio client (copy pattern `network_impl.dart`: Bearer token + refresh-token interceptor + header `x-custom-lang`).
- [ ] DI `injection_container.dart`; `base_bloc` (`InitState/LoadingState/LoadedState/ErrorState`).
- [ ] `lib/res/colors.dart`, `lib/res/dimens.dart`; i18n `intl` (vi/en).
- [ ] Auth tối thiểu (login + lưu token bằng `flutter_secure_storage`).
- **DoD:** App chạy, gọi được API có token, đổi ngôn ngữ vi/en.

## Phase 2 — Domain layer OCR (P4)

- [ ] Entities: `OcrJobEntity { id, fileName, lang, status, totalPages, processedPages, createdAt }`, `OcrPageEntity { page, width, height, List<OcrLine> }`, `OcrLine { text, confidence, List<Offset> bbox }`.
- [ ] `ocr_remote_data_source.dart` — gọi các endpoint `/ocr/...`.
- [ ] `ocr_repository.dart` — `createJob(file, lang)`, `getJobs(params)`, `getJob(id)`, `getResult(id, page)`, `export(id, format)`.
- [ ] Khai báo endpoint trong `api_constant.dart`.
- **DoD:** Repository trả về model parse đúng từ JSON.

## Phase 3 — Upload tài liệu (P4)

- [ ] Màn `UploadScreen`: chọn PDF/ảnh (`file_picker`) hoặc **chụp tài liệu** (camera + crop), chọn `lang` (vi/en/auto).
- [ ] `UploadCubit` — tạo job (hiển thị progress), xử lý lỗi qua state, toast khi xong.
- [ ] Sau khi tạo → điều hướng/đưa job vào danh sách (`queued`).
- **DoD:** Upload thành công, nhận `jobId`.

## Phase 4 — Danh sách job + realtime (P5)

- [ ] `JobListScreen` + `OcrJobCubit` (list, phân trang, filter status, pull-to-refresh).
- [ ] `job_card` widget: tên file, ngôn ngữ, badge trạng thái, progress `processedPages/totalPages`.
- [ ] Socket.IO client nghe `ocr.job.updated` → cập nhật card realtime; fallback poll khi mất socket.
- [ ] (Tùy chọn) Nhận FCM push khi job `done` (tái dùng pattern FCM Readbox).
- **DoD:** Trạng thái job tự cập nhật; mở lại app vẫn lấy đúng theo `jobId`.

## Phase 5 — Xem & sử dụng kết quả OCR (P5)

- [ ] `OcrViewerScreen` + `OcrResultCubit`: render trang gốc (PDF/ảnh) + **overlay bbox** (scale theo `width/height` API) — vẽ highlight vùng text.
- [ ] Tab “Text thuần”; tap bbox ↔ scroll tới dòng text.
- [ ] **Tìm kiếm** trong tài liệu (highlight match), **copy** text.
- [ ] **TTS đọc to** bằng `flutter_tts` + auto-detect ngôn ngữ trang; điều khiển play/pause, highlight từ đang đọc.
- [ ] **Dịch/AI**: gọi `ai/translate`, `ai/lookup` cho đoạn text chọn.
- [ ] Lazy-load kết quả theo trang đang xem.
- **DoD:** Đọc được tài liệu scan, overlay đúng vị trí, TTS + dịch hoạt động.

## Phase 6 — Export & hoàn thiện (P6)

- [ ] Xuất `.txt` / **searchable PDF** (gọi export API) + chia sẻ file.
- [ ] Trạng thái rỗng/loading/skeleton, retry job `failed`, xoá job.
- [ ] Kiểm tra song ngữ đầy đủ, dark mode, responsive (tablet).
- **DoD:** Tải/chia sẻ file export; UX mượt, không hardcode chuỗi.

---

## Cấu trúc thư mục đề xuất

```
lib/
├── blocs/
│   ├── upload/      (upload_cubit.dart, upload_state.dart)
│   ├── ocr_job/     (ocr_job_cubit.dart, ocr_job_state.dart)
│   └── ocr_result/  (ocr_result_cubit.dart, ocr_result_state.dart)
├── domain/
│   ├── data/entities/   (ocr_job_entity.dart, ocr_page_entity.dart)
│   ├── data/datasources/remote/ (ocr_remote_data_source.dart)
│   ├── repositories/    (ocr_repository.dart)
│   └── network/         (network_impl.dart, api_constant.dart)
├── ui/
│   ├── screen/  (upload, job_list, ocr_viewer)
│   └── widget/  (job_card, bbox_overlay, status_badge)
├── res/         (colors.dart, dimens.dart)
├── services/    (socket_service.dart, fcm_service.dart, tts_service.dart)
└── injection_container.dart
```

## Ghi chú kỹ thuật

- **Overlay bbox**: toạ độ bbox theo ảnh OCR; scale = kích thước render trên màn / kích thước ảnh OCR (`width/height`).
- **Bất đồng bộ**: kết quả luôn lưu server theo `jobId`; app không phụ thuộc việc giữ socket — mở lại lấy theo `jobId`.
- **Tái dùng từ Readbox**: pattern Dio/refresh-token, TTS service, language detector, AI repository — copy & rút gọn cho app OCR.
- **Gói tham khảo**: `dio`, `flutter_bloc`, `get_it`, `equatable`, `flutter_dotenv`, `flutter_secure_storage`, `file_picker`, `socket_io_client`, `flutter_tts`, `flutter_langdetect`.
```
