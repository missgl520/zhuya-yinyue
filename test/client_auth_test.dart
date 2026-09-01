// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 客户端鉴权签名单元测试（client_auth_test.dart）
//
// 验证 ClientAuth.signedHeaders 与后端 auth.py 完全一致的「API Key + 请求签名」：
//   签名串 = HMAC-SHA256(API_KEY, "METHOD\nPATH\nTIMESTAMP\nNONCE\nSHA256(BODY)")
//
// 运行需在进程内注入测试密钥（缺失时 ClientAuth.apiKey 会按设计抛 StateError）：
//   flutter test --dart-define=ZHUYU_API_KEY=unit-test-api-key
//
// 纯 Dart 逻辑，无需设备或网络。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhuyapp/core/auth/client_auth.dart';

void main() {
  group('ClientAuth 请求签名', () {
    test('signedHeaders 返回 5 个约定头且非空', () {
      final headers = ClientAuth.instance.signedHeaders(
        method: 'POST',
        path: '/api/chat',
        bodyBytes: utf8.encode('{"msg":"hi"}'),
        userId: 'user-1',
      );

      for (final key in const [
        'X-Api-Key',
        'X-Timestamp',
        'X-Nonce',
        'X-Signature',
        'X-User-Id',
      ]) {
        expect(headers.containsKey(key), isTrue, reason: '缺少请求头 $key');
        expect(headers[key], isNotEmpty, reason: '请求头 $key 不应为空');
      }
      expect(headers['X-User-Id'], 'user-1');
    });

    test('X-Signature == HMAC-SHA256(apiKey, canonical)', () {
      final body = utf8.encode('{"msg":"hi"}');
      const method = 'POST';
      const path = '/api/chat';

      final headers = ClientAuth.instance.signedHeaders(
        method: method,
        path: path,
        bodyBytes: body,
        userId: 'user-1',
      );

      final apiKey = ClientAuth.apiKey;
      final bodyHash = sha256.convert(body).toString();
      final canonical =
          '$method\n$path\n${headers['X-Timestamp']}\n${headers['X-Nonce']}\n$bodyHash';
      final expected = Hmac(sha256, utf8.encode(apiKey))
          .convert(utf8.encode(canonical))
          .toString();

      expect(headers['X-Signature'], expected);
    });

    test('body 不同 → 签名不同（bodyHash 进入 canonical）', () {
      final a = ClientAuth.instance.signedHeaders(
        method: 'POST',
        path: '/api/chat',
        bodyBytes: utf8.encode('A'),
        userId: 'u',
      );
      final b = ClientAuth.instance.signedHeaders(
        method: 'POST',
        path: '/api/chat',
        bodyBytes: utf8.encode('B'),
        userId: 'u',
      );
      expect(a['X-Signature'], isNot(b['X-Signature']));
    });

    test('path 不同 → 签名不同', () {
      final a = ClientAuth.instance.signedHeaders(
        method: 'POST',
        path: '/api/chat',
        bodyBytes: utf8.encode('same'),
        userId: 'u',
      );
      final b = ClientAuth.instance.signedHeaders(
        method: 'POST',
        path: '/api/memory',
        bodyBytes: utf8.encode('same'),
        userId: 'u',
      );
      expect(a['X-Signature'], isNot(b['X-Signature']));
    });
  });
}
