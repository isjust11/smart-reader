import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:readbox/domain/network/api_constant.dart';
import 'package:readbox/services/secure_storage_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Payload realtime nhận từ event `ocr.job.updated` (khớp `OcrJobUpdatePayload`).
class OcrJobUpdate {
  final int jobId;
  final String status;
  final int? processedPages;
  final int? totalPages;
  final String? error;

  const OcrJobUpdate({
    required this.jobId,
    required this.status,
    this.processedPages,
    this.totalPages,
    this.error,
  });

  factory OcrJobUpdate.fromMap(Map<String, dynamic> map) {
    return OcrJobUpdate(
      jobId: _toInt(map['jobId']),
      status: map['status']?.toString() ?? '',
      processedPages:
          map['processedPages'] == null ? null : _toInt(map['processedPages']),
      totalPages: map['totalPages'] == null ? null : _toInt(map['totalPages']),
      error: map['error'] as String?,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

/// Tên event socket cho OCR (khớp `OCR_EVENTS` phía backend).
class _OcrEvents {
  static const jobUpdated = 'ocr.job.updated';
  static const joinJob = 'ocr.join';
  static const leaveJob = 'ocr.leave';
}

/// Service quản lý kết nối Socket.IO để nhận cập nhật realtime tiến độ OCR.
///
/// Client join room theo `jobId` (số nguyên gốc) để chỉ nhận cập nhật cho các
/// job đang quan tâm. Stream [updates] phát ra mọi [OcrJobUpdate] nhận được.
class OcrSocketService {
  final SecureStorageService _secureStorage = SecureStorageService();

  io.Socket? _socket;
  final StreamController<OcrJobUpdate> _controller =
      StreamController<OcrJobUpdate>.broadcast();
  final Set<int> _joinedRooms = <int>{};

  /// Stream các cập nhật job realtime.
  Stream<OcrJobUpdate> get updates => _controller.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Kết nối tới server socket (idempotent). Tự đính token vào auth header.
  Future<void> connect() async {
    if (_socket != null) {
      if (!(_socket!.connected)) _socket!.connect();
      return;
    }

    final token = await _secureStorage.getToken();
    final socket = io.io(
      _socketBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setExtraHeaders({
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          })
          .setAuth({if (token != null && token.isNotEmpty) 'token': token})
          .build(),
    );

    socket.onConnect((_) {
      if (kDebugMode) debugPrint('[OcrSocket] connected');
      // Re-join các room đã đăng ký khi reconnect.
      for (final jobId in _joinedRooms) {
        socket.emit(_OcrEvents.joinJob, {'jobId': jobId});
      }
    });

    socket.on(_OcrEvents.jobUpdated, (data) {
      if (data is Map) {
        _controller.add(OcrJobUpdate.fromMap(Map<String, dynamic>.from(data)));
      }
    });

    socket.onConnectError((err) {
      if (kDebugMode) debugPrint('[OcrSocket] connect error: $err');
    });
    socket.onError((err) {
      if (kDebugMode) debugPrint('[OcrSocket] error: $err');
    });

    _socket = socket;
    socket.connect();
  }

  /// Đăng ký nhận cập nhật cho một job cụ thể.
  void joinJob(int jobId) {
    if (jobId <= 0) return;
    _joinedRooms.add(jobId);
    if (isConnected) {
      _socket!.emit(_OcrEvents.joinJob, {'jobId': jobId});
    }
  }

  /// Hủy đăng ký một job.
  void leaveJob(int jobId) {
    _joinedRooms.remove(jobId);
    if (isConnected) {
      _socket!.emit(_OcrEvents.leaveJob, {'jobId': jobId});
    }
  }

  /// Ngắt kết nối nhưng giữ service để có thể connect lại.
  void disconnect() {
    _socket?.disconnect();
  }

  /// Giải phóng hoàn toàn (gọi khi service không còn dùng).
  Future<void> dispose() async {
    _socket?.dispose();
    _socket = null;
    _joinedRooms.clear();
    await _controller.close();
  }

  /// Base URL cho socket: bỏ trailing slash để socket_io_client parse đúng.
  String get _socketBaseUrl {
    final host = ApiConstant.apiHost;
    return host.endsWith('/') ? host.substring(0, host.length - 1) : host;
  }
}
