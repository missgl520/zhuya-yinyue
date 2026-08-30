// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// LiveKit 实时语音服务
//
// 功能：
//   1. 从后端获取连接信息（URL + Token）
//   2. 连接 LiveKit 房间
//   3. 启用麦克风（音频自动发布）
//   4. 订阅 AI Agent 音频（自动播放）
//
// 用法：
//   final svc = LiveKitService();
//   await svc.connect(room: 'zhuyapp-voice');
//   // 麦克风自动发布，AI 音频自动播放
//   await svc.disconnect();
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';

import '../auth/client_auth.dart';
import '../config.dart';

/// 连接状态
enum LiveKitState { idle, connecting, connected, error }

/// LiveKit 实时语音服务
class LiveKitService {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  String? _errorMessage;

  LiveKitState _state = LiveKitState.idle;

  // ── Getters ──────────────────────────────────────────

  LiveKitState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _state == LiveKitState.connected;

  // ── 连接 ─────────────────────────────────────────────

  /// 从后端获取 token 并连接 LiveKit 房间
  Future<void> connect({required String room, String userId = ''}) async {
    if (_state == LiveKitState.connecting || _state == LiveKitState.connected) {
      return;
    }

    _setState(LiveKitState.connecting, null);

    try {
      // 1. 从后端获取连接信息
      final connInfo = await _fetchConnectionInfo(room: room, userId: userId);
      final url = connInfo['livekit_url'] as String;
      final token = connInfo['token'] as String;

      debugPrint('[LiveKit] connecting to $url, room=$room');

      // 2. 创建 Room 实例
      _room = Room(
        roomOptions: RoomOptions(adaptiveStream: true, dynacast: true),
      );

      // 3. 创建事件监听器（示例见 https://docs.livekit.io/client/events/#events）
      _listener = _room!.createListener();
      _listener!
        ..on<RoomDisconnectedEvent>((event) {
          debugPrint('[LiveKit] room disconnected: ${event.reason}');
          _setState(LiveKitState.idle, null);
        })
        ..on<TrackSubscribedEvent>((event) {
          debugPrint('[LiveKit] track subscribed: ${event.track.sid}');
        })
        ..on<ParticipantEvent>((event) {
          debugPrint('[LiveKit] participant event: $event');
        })
        ..on<AudioPlaybackStatusChanged>((event) async {
          debugPrint('[LiveKit] audio playback: ${event.isPlaying}');
          if (!event.isPlaying) {
            await _room?.startAudio();
          }
        });

      // 4. 连接
      await _room!.connect(url, token);
      debugPrint('[LiveKit] connected!');

      // 5. 启用麦克风
      await _room!.localParticipant?.setMicrophoneEnabled(
        true,
        audioCaptureOptions: const AudioCaptureOptions(
          noiseSuppression: true,
          echoCancellation: true,
        ),
      );
      debugPrint('[LiveKit] microphone enabled');

      _setState(LiveKitState.connected, null);
    } catch (e) {
      debugPrint('[LiveKit] connect error: $e');
      _setState(LiveKitState.error, e.toString());
      rethrow;
    }
  }

  /// 主动断开
  Future<void> disconnect() async {
    await _listener?.cancelAll();
    _listener = null;
    await _room?.disconnect();
    _room = null;
    _setState(LiveKitState.idle, null);
  }

  /// 切换静音
  Future<void> setMuted(bool muted) async {
    await _room?.localParticipant?.setMicrophoneEnabled(!muted);
  }

  // ── 内部方法 ─────────────────────────────────────────

  Future<Map<String, dynamic>> _fetchConnectionInfo({
    required String room,
    required String userId,
  }) async {
    try {
      final baseUrl = BackendConfig.instance.baseUrl;
      final authUserId = await ClientAuth.instance.userId;
      final headers = ClientAuth.instance.signedHeaders(
        method: 'GET',
        path: '/livekit/connect',
        bodyBytes: const [],
        userId: authUserId,
      );
      final resp = await http.get(
        Uri.parse('$baseUrl/livekit/connect?room=$room&user_id=$userId'),
        headers: headers,
      );
      if (resp.statusCode != 200) {
        throw Exception('获取 LiveKit 连接信息失败: ${resp.statusCode}');
      }
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('后端不可用: $e');
    }
  }

  void _setState(LiveKitState state, String? error) {
    _state = state;
    _errorMessage = error;
  }
}
