import 'dart:math' show max;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../core/services/diagnostic_log.dart'
    show diagnosticMaxScreenshotBytes;

const _maxSourceBytes = 20 * 1024 * 1024;
const _maxSourcePixels = 24 * 1024 * 1024;
const _maxEdge = 1920;

final feedbackScreenshotPickerProvider =
    Provider<Future<Uint8List?> Function()>((ref) => _pickScreenshot);

Future<Uint8List?> _pickScreenshot() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    requestFullMetadata: false,
  );
  if (file == null) return null;
  if (await file.length() > _maxSourceBytes) {
    throw const FormatException('Screenshot source is too large');
  }
  return compute(normalizeFeedbackScreenshot, await file.readAsBytes());
}

Uint8List normalizeFeedbackScreenshot(Uint8List bytes) {
  if (bytes.lengthInBytes > _maxSourceBytes) {
    throw const FormatException('Screenshot source is too large');
  }
  final decoder = img.findDecoderForData(bytes);
  if (decoder == null ||
      (decoder is! img.JpegDecoder && decoder is! img.PngDecoder)) {
    throw const FormatException('Choose a PNG or JPEG screenshot');
  }
  final info = decoder.startDecode(bytes);
  if (info == null ||
      info.width <= 0 ||
      info.height <= 0 ||
      info.width * info.height > _maxSourcePixels) {
    throw const FormatException('Invalid screenshot dimensions');
  }
  final decoded = decoder.decodeFrame(0);
  if (decoded == null) throw const FormatException('Invalid screenshot');

  final resized = _resizeToEdge(img.bakeOrientation(decoded), _maxEdge);

  // Render into fresh RGB pixels to omit embedded metadata and flatten alpha.
  var clean = img.Image(
    width: resized.width,
    height: resized.height,
    numChannels: 3,
  );
  img.fill(clean, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(clean, resized);
  while (true) {
    for (final quality in [85, 75, 65, 55]) {
      final jpeg = img.encodeJpg(clean, quality: quality);
      if (jpeg.lengthInBytes <= diagnosticMaxScreenshotBytes) return jpeg;
    }
    final edge = max(clean.width, clean.height);
    if (edge <= 480) {
      throw const FormatException('Screenshot is too large after compression');
    }
    clean = _resizeToEdge(clean, (edge * 0.75).round());
  }
}

img.Image _resizeToEdge(img.Image image, int limit) {
  final edge = max(image.width, image.height);
  if (edge <= limit) return image;
  return img.copyResize(
    image,
    width: max(1, (image.width * limit / edge).round()),
    height: max(1, (image.height * limit / edge).round()),
    interpolation: img.Interpolation.average,
  );
}
