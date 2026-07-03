import 'dart:io';

import 'package:dio/dio.dart';
import 'package:readbox/domain/data/datasources/datasource.dart';
import 'package:readbox/domain/data/models/models.dart';

/// Repository điều phối nghiệp vụ OCR giữa UI/Cubit và data source.
class OcrRepository {
  final OcrRemoteDataSource remoteDataSource;

  OcrRepository({required this.remoteDataSource});

  Future<OcrJobModel> createJob({
    required File file,
    String lang = 'auto',
    bool extractImages = true,
    List<int>? pages,
    CancelToken? cancelToken,
    void Function(int sent, int total)? onSendProgress,
  }) {
    return remoteDataSource.createJob(
      file: file,
      lang: lang,
      extractImages: extractImages,
      pages: pages,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
    );
  }

  Future<OcrJobPage> getJobs({int page = 1, int size = 20, String? status}) {
    return remoteDataSource.getJobs(page: page, size: size, status: status);
  }

  Future<OcrJobModel> getJob(String id) => remoteDataSource.getJob(id);

  Future<OcrJobModel> requeueJob(String id) => remoteDataSource.requeueJob(id);

  Future<List<OcrPageModel>> getResult(String id, {int? page}) {
    return remoteDataSource.getResult(id, page: page);
  }

  Future<void> saveResult(String id, List<OcrPageModel> pages) {
    return remoteDataSource.saveResult(id, pages);
  }

  Future<Map<String, dynamic>> exportJob(String id, String format) {
    return remoteDataSource.exportJob(id, format);
  }

  Future<void> deleteJob(String id) => remoteDataSource.deleteJob(id);
}
