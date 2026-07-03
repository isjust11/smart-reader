import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:readbox/blocs/utils.dart';
import 'package:readbox/domain/data/models/models.dart';
import 'package:readbox/domain/network/network.dart';

/// Kết quả phân trang danh sách job OCR.
class OcrJobPage {
  final List<OcrJobModel> jobs;
  final int total;
  final int page;
  final int size;
  final int totalPages;

  const OcrJobPage({
    required this.jobs,
    required this.total,
    required this.page,
    required this.size,
    required this.totalPages,
  });
}

/// Nguồn dữ liệu remote cho các endpoint `/ocr/...`.
class OcrRemoteDataSource {
  final Network network;

  OcrRemoteDataSource({required this.network});

  /// Tạo job OCR mới bằng upload file (PDF/ảnh).
  Future<OcrJobModel> createJob({
    required File file,
    String lang = 'auto',
    bool extractImages = true,
    List<int>? pages,
    CancelToken? cancelToken,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final fileName = file.path.split(RegExp(r'[/\\]')).last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
        contentType: _resolveContentType(fileName),
      ),
      'lang': lang,
      'extractImages': extractImages.toString(),
      if (pages != null && pages.isNotEmpty) 'pages': pages.join(','),
    });

    final response = await network.postWithFormData(
      url: '${ApiConstant.apiHost}${ApiConstant.ocrJobs}',
      formData: formData,
      options: Options(
        responseType: ResponseType.json,
        contentType: 'multipart/form-data',
      ),
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
    );

    if (response.isSuccess) {
      return OcrJobModel.fromJson(_unwrap(response.data));
    }
    return Future.error(response.errMessage);
  }

  /// Danh sách job của người dùng, phân trang + lọc theo trạng thái.
  Future<OcrJobPage> getJobs({
    int page = 1,
    int size = 20,
    String? status,
  }) async {
    try {
      final response = await network.get(
        url: '${ApiConstant.apiHost}${ApiConstant.ocrJobs}',
        params: {
          'page': page,
          'size': size,
          if (status != null && status.isNotEmpty) 'status': status,
        },
      );

      if (!response.isSuccess) {
        return Future.error(response.errMessage);
      }

      final body = response.data;
      final rawList = (body is Map ? body['data'] : body) as List? ?? const [];
      final jobs = rawList
          .whereType<Map>()
          .map((e) => OcrJobModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      final pagination = (body is Map ? body['pagination'] : null) as Map?;
      return OcrJobPage(
        jobs: jobs,
        total: _toInt(pagination?['total'], jobs.length),
        page: _toInt(pagination?['page'], page),
        size: _toInt(pagination?['size'], size),
        totalPages: _toInt(pagination?['totalPages'], 1),
      );
    } catch (e) {
      return Future.error(BlocUtils.getMessageError(e));
    }
  }

  /// Chi tiết một job theo id (đã mã hóa base64 phía backend).
  Future<OcrJobModel> getJob(String id) async {
    final response = await network.get(
      url: '${ApiConstant.apiHost}${ApiConstant.ocrJobDetail(id)}',
    );
    if (response.isSuccess) {
      return OcrJobModel.fromJson(_unwrap(response.data));
    }
    return Future.error(response.errMessage);
  }

  /// Đẩy lại job vào hàng đợi (retry khi failed).
  Future<OcrJobModel> requeueJob(String id) async {
    final response = await network.post(
      url: '${ApiConstant.apiHost}${ApiConstant.ocrJobRequeue(id)}',
    );
    if (response.isSuccess) {
      return OcrJobModel.fromJson(_unwrap(response.data));
    }
    return Future.error(response.errMessage);
  }

  /// Kết quả OCR (text + bbox) theo trang (hoặc toàn bộ khi bỏ trống page).
  Future<List<OcrPageModel>> getResult(String id, {int? page}) async {
    final response = await network.get(
      url: '${ApiConstant.apiHost}${ApiConstant.ocrJobResult(id)}',
      params: {if (page != null) 'page': page},
    );
    if (!response.isSuccess) {
      return Future.error(response.errMessage);
    }
    final body = response.data;
    final rawList = (body is Map ? body['data'] : body) as List? ?? const [];
    return rawList
        .whereType<Map>()
        .map((e) => OcrPageModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Lưu toàn bộ trang OCR đã chỉnh sửa từ editor.
  Future<void> saveResult(String id, List<OcrPageModel> pages) async {
    final response = await network.put(
      url: '${ApiConstant.apiHost}${ApiConstant.ocrJobSaveResult(id)}',
      body: {
        'pages': pages.map((e) => e.toJson()).toList(),
      },
    );
    if (!response.isSuccess) {
      return Future.error(response.errMessage);
    }
  }

  /// Xoá một job OCR theo id.
  Future<void> deleteJob(String id) async {
    final response = await network.delete(
      url: '${ApiConstant.apiHost}${ApiConstant.ocrJobDetail(id)}',
    );
    if (!response.isSuccess) {
      return Future.error(response.errMessage);
    }
  }

  /// Export kết quả OCR (`txt` đồng bộ, `pdf` bất đồng bộ).
  Future<Map<String, dynamic>> exportJob(String id, String format) async {
    final response = await network.post(
      url: '${ApiConstant.apiHost}${ApiConstant.ocrJobExport(id)}',
      body: {'format': format},
    );
    if (response.isSuccess) {
      final body = response.data;
      if (body is Map) {
        final data = body['data'];
        if (data is Map) return Map<String, dynamic>.from(data);
        return Map<String, dynamic>.from(body);
      }
      return <String, dynamic>{};
    }
    return Future.error(response.errMessage);
  }

  MediaType _resolveContentType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return MediaType('application', 'pdf');
      case 'png':
        return MediaType('image', 'png');
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'webp':
        return MediaType('image', 'webp');
      case 'tif':
      case 'tiff':
        return MediaType('image', 'tiff');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  /// Backend `success()` có thể trả object trực tiếp hoặc bọc trong `data`.
  Map<String, dynamic> _unwrap(dynamic data) {
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }

  int _toInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
