import 'dart:io';

import 'package:equatable/equatable.dart';

/// Nguồn tài liệu chờ upload OCR.
class OcrUploadSelection extends Equatable {
  final File? documentFile;
  final List<File> imagePages;

  const OcrUploadSelection({
    this.documentFile,
    this.imagePages = const [],
  });

  bool get hasDocument =>
      documentFile != null && documentFile!.path.isNotEmpty;

  bool get hasImagePages => imagePages.isNotEmpty;

  bool get hasSelection => hasDocument || hasImagePages;

  int get pageCount => hasDocument ? 1 : imagePages.length;

  bool get isMultiPageImages => imagePages.length > 1;

  OcrUploadSelection copyWith({
    File? documentFile,
    bool clearDocument = false,
    List<File>? imagePages,
    bool clearImagePages = false,
  }) {
    return OcrUploadSelection(
      documentFile: clearDocument ? null : (documentFile ?? this.documentFile),
      imagePages:
          clearImagePages ? const [] : (imagePages ?? this.imagePages),
    );
  }

  @override
  List<Object?> get props => [documentFile?.path, imagePages.map((e) => e.path)];
}
