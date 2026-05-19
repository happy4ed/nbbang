import 'dart:async';

import 'package:flutter/services.dart';

// Status constants mirror com.google.mlkit.genai.common.FeatureStatus
// 0=UNAVAILABLE, 1=DOWNLOADABLE, 2=DOWNLOADING, 3=AVAILABLE
class LlmService {
  static const _channel = MethodChannel('com.happy4ed.nbbang/gemini_nano');

  static const int statusUnavailable = 0;
  static const int statusDownloadable = 1;
  static const int statusDownloading = 2;
  static const int statusAvailable = 3;

  Future<int> checkStatus() async {
    try {
      return await _channel.invokeMethod<int>('checkStatus') ?? 0;
    } on PlatformException {
      return 0;
    }
  }

  Future<void> prepareIfNeeded() async {
    try {
      await _channel.invokeMethod<void>('prepareIfNeeded');
    } on PlatformException catch (e) {
      throw Exception('Gemini Nano 준비 실패: ${e.message}');
    }
  }

  Future<String?> generateText(String prompt) async {
    try {
      return await _channel
          .invokeMethod<String>('generateText', {'prompt': prompt})
          .timeout(const Duration(seconds: 35));
    } on TimeoutException {
      return null;
    } on PlatformException catch (e) {
      throw Exception('Gemini Nano 생성 실패: ${e.message}');
    }
  }
}
