// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 客户端鉴权（client_auth.dart）
//
// 与后端 auth.py 完全一致的「API Key + 请求签名」实现：
//   - 每个请求携带 X-Api-Key / X-Timestamp / X-Nonce / X-Signature / X-User-Id
//   - 签名串 = HMAC-SHA256(API_KEY, "METHOD\nPATH\nTIMESTAMP\nNONCE\nSHA256(BODY)")
//   - 设备 user_id：按安装生成并持久化，用于后端多用户数据隔离
//
// 生产构建请通过 --dart-define=ZHUYU_API_KEY=<与后端一致的密钥> 注入，
// 切勿把真实密钥硬编码进仓库。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

class ClientAuth {
  ClientAuth._();

  static final ClientAuth instance = ClientAuth._();

  /// 必须与后端 ZHUYU_API_KEY 一致；生产环境用 --dart-define 覆盖。
  static const String apiKey = String.fromEnvironment(
    'ZHUYU_API_KEY',
    defaultValue: 'zhuyu-dev-key-change-me',
  );

  String? _cachedUserId;

  /// 设备 / 用户唯一标识（按安装生成，持久化到 Hive）。
  Future<String> get userId async {
    if (_cachedUserId != null) return _cachedUserId!;
    final box = await Hive.openBox('settings');
    String id = box.get('deviceUserId', defaultValue: '') as String;
    if (id.isEmpty) {
      id = const Uuid().v4();
      await box.put('deviceUserId', id);
    }
    _cachedUserId = id;
    return id;
  }

  /// 计算签名头（与后端 canonical 严格一致）。
  Map<String, String> signedHeaders({
    required String method,
    required String path,
    required List<int> bodyBytes,
    required String userId,
  }) {
    final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final nonce = const Uuid().v4();
    final bodyHash = sha256.convert(bodyBytes).toString();
    final canonical = '$method\n$path\n$ts\n$nonce\n$bodyHash';
    final sig = Hmac(
      sha256,
      utf8.encode(apiKey),
    ).convert(utf8.encode(canonical)).toString();
    return {
      'X-Api-Key': apiKey,
      'X-Timestamp': ts,
      'X-Nonce': nonce,
      'X-Signature': sig,
      'X-User-Id': userId,
    };
  }
}

/// Dio 拦截器：自动为每个请求附加签名头与 user_id。
class SigningInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final userId = await ClientAuth.instance.userId;
    final method = options.method.toUpperCase();
    final path = options.path; // 不含 query，与后端 request.url.path 对齐

    List<int> bodyBytes = const [];
    if (options.data != null) {
      try {
        bodyBytes = utf8.encode(jsonEncode(options.data));
      } catch (_) {
        bodyBytes = const [];
      }
    }

    final headers = ClientAuth.instance.signedHeaders(
      method: method,
      path: path,
      bodyBytes: bodyBytes,
      userId: userId,
    );
    options.headers.addAll(headers);
    handler.next(options);
  }
}
