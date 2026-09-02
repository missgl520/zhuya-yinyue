// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 音频处理服务（FFmpeg）
//
// 处理流程：下载直链 → Loudnorm响度标准化 → Compand动态压缩 → 输出
//
// Loudnorm：EBU R128 标准响度标准化（-16 LUFS，保留动态）
// Compand：动态范围压缩（小声更清晰，大声更有力）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 音频处理配置
class AudioProcessConfig {
  /// 目标响度（LUFS），越低动态越大
  /// -14：广播标准（动态小）
  /// -16：流媒体标准（平衡，推荐）
  /// -19：播客标准（动态最大）
  final double targetLufs;

  /// 动态压缩强度（0=不压，1=最大）
  /// 0.3 = 轻度增强（推荐）
  /// 0.6 = 中度压缩
  /// 1.0 = 重度压（失真风险）
  final double compressLevel;

  /// 是否启用处理（关闭则直接播放原始文件）
  final bool enabled;

  const AudioProcessConfig({
    this.targetLufs = -16.0,
    this.compressLevel = 0.3,
    this.enabled = true,
  });

  static const standard = AudioProcessConfig();
  static const strong = AudioProcessConfig(compressLevel: 0.6, targetLufs: -14.0);
}

/// 处理状态
enum ProcessState { idle, downloading, processing, done, error }

/// 处理进度回调
typedef ProgressCallback = void Function(ProcessState state, double progress, String? message);

/// 音频处理服务
class AudioProcessService {
  static final AudioProcessService _instance = AudioProcessService._();
  factory AudioProcessService() => _instance;
  AudioProcessService._();

  final _dio = Dio();

  /// 获取临时处理目录
  Future<Directory> get _tempDir async {
    final dir = Directory(p.join((await getTemporaryDirectory()).path, 'audio_process'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// 获取处理后缓存目录
  Future<Directory> get _cacheDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'processed_music'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// 检查缓存（相同URL+配置 → 返回缓存路径）
  Future<String?> getCachedPath(String url, AudioProcessConfig config) async {
    if (!config.enabled) return null;

    final cacheDir = await _cacheDir;
    final hash = url.hashCode.toRadixString(16);
    final cached = File(p.join(cacheDir.path, '$hash.processed.mp3'));

    if (await cached.exists()) {
      // 验证文件有效
      if (await cached.length() > 1024) {
        return cached.path;
      }
    }
    return null;
  }

  /// 下载 + 处理音频
  ///
  /// [url] 原始音频直链
  /// [trackId] 歌曲ID（用于缓存文件名）
  /// [config] 处理配置
  /// [onProgress] 进度回调
  ///
  /// 返回处理后的文件路径（用完可立即播放）
  Future<String?> processAudio({
    required String url,
    required String trackId,
    AudioProcessConfig config = AudioProcessConfig.standard,
    ProgressCallback? onProgress,
  }) async {
    // 先检查缓存
    final cached = await getCachedPath(url, config);
    if (cached != null) {
      onProgress?.call(ProcessState.done, 1.0, '命中缓存');
      return cached;
    }

    if (!config.enabled) {
      // 不处理：下载原始文件到临时目录
      onProgress?.call(ProcessState.downloading, 0.0, '下载中…');
      final tempDir = await _tempDir;
      final outPath = p.join(tempDir.path, '$trackId.original.mp3');
      await _downloadFile(url, outPath, (p) {
        onProgress?.call(ProcessState.downloading, p, '下载中… ${(p * 100).toInt()}%');
      });
      onProgress?.call(ProcessState.done, 1.0, '下载完成');
      return outPath;
    }

    // ════════════════════════════════════════════════════
    // 第一步：下载原始文件到临时目录
    // ════════════════════════════════════════════════════
    onProgress?.call(ProcessState.downloading, 0.0, '下载中…');
    final tempDir = await _tempDir;
    final rawPath = p.join(tempDir.path, '$trackId.raw.mp3');

    await _downloadFile(url, rawPath, (p) {
      onProgress?.call(ProcessState.downloading, p * 0.4, '下载中… ${(p * 100).toInt()}%');
    });

    final rawFile = File(rawPath);
    if (!await rawFile.exists()) {
      onProgress?.call(ProcessState.error, 0, '下载失败');
      return null;
    }

    // ════════════════════════════════════════════════════
    // 第二步：FFmpeg 处理
    // ════════════════════════════════════════════════════
    onProgress?.call(ProcessState.processing, 0.4, '处理音频…');

    final cacheDir = await _cacheDir;
    final outPath = p.join(cacheDir.path, '$trackId.processed.mp3');

    final cmd = _buildFFmpegCommand(rawPath, outPath, config);

    // 设置日志回调（静默）
    FFmpegKitConfig.enableLogCallback(null);
    FFmpegKitConfig.enableStatisticsCallback(null);

    final session = await FFmpegKit.execute(cmd);
    final returnCode = await session.getReturnCode();

    // 删除原始下载文件
    try { await rawFile.delete(); } catch (_) {}

    if (ReturnCode.isSuccess(returnCode)) {
      final outFile = File(outPath);
      if (await outFile.exists() && await outFile.length() > 1024) {
        onProgress?.call(ProcessState.done, 1.0, '处理完成');
        return outPath;
      }
    }

    // 处理失败，回退到原始文件
    final fallbackPath = p.join(tempDir.path, '$trackId.fallback.mp3');
    await _downloadFile(url, fallbackPath, null);
    onProgress?.call(ProcessState.error, 0, '处理失败，已用原始音频');
    return fallbackPath;
  }

  /// 构建 FFmpeg 命令
  String _buildFFmpegCommand(String inputPath, String outputPath, AudioProcessConfig config) {
    final lufs = config.targetLufs;
    final comp = config.compressLevel;

    // Compand 参数说明：
    // attack:0.003（毫秒，3ms快速响应）
    // decay:0.25（250ms缓慢释放）
    // points: -60/-60 -30/$comp -10/$comp 0/0
    //   → -60dB以下不变，-30dB开始压缩，-10dB压缩到-comp倍，0dB以上不变
    // soft-knee：2dB过渡
    // volume：0dB
    // gain：0dB最终增益
    final compandPoints = comp > 0
        ? 'attack 0.003,decay 0.25,points -60/-60|-30/${-comp.toStringAsFixed(2)}|-10/${-comp.toStringAsFixed(2)}|0/0,soft-knee 2,volume 0,gain 0'
        : '';

    // HP filter：移除 < 30Hz 低频（电话声、 rumble）
    // ar 44100：输出 44.1kHz
    // ac 2：双声道
    // b:a 192k：192kbps 码率（高于原始128k）

    return [
      '-y',                                // 覆盖输出
      '-i "$inputPath"',                   // 输入
      '-af',                               // 音频过滤器链
      comp > 0
        ? 'compand=$compandPoints,'
            'highpass=f=30,'               // 高通滤波（去低噪）
            'volume=3dB,'                  // 略微提升音量感
        : 'highpass=f=30,volume=3dB,',
      'loudnorm='                          // EBU R128 响度标准化
          'i=$lufs:'                       // 目标综合响度
          'lra=11:'                        // 响度范围 11LU（平衡）
          'tp=-2:'                         // 真峰值上限 -2dBTP
          'measured_I=-23:'               // 测量值（预置）
          'measured_TP=-3:'               // 测量真峰值
          'measured_LRA=10:'              // 测量LRA
          'measured_thresh=-34,'          // 测量阈值
          'linear=true',                  // 线性归一化
      '-ar 44100',                        // 输出采样率
      '-ac 2',                            // 双声道
      '-b:a 192k',                        // 输出码率 192kbps
      '-id3v2_version 3',                 // ID3v2.3 标签
      '-metadata', 'title="$trackId"',    // 保留元数据
      '"$outputPath"',
    ].join(' ');
  }

  /// 下载文件（带进度）
  Future<void> _downloadFile(
    String url,
    String savePath,
    void Function(double)? onProgress,
  ) async {
    await _dio.download(
      url,
      savePath,
      options: Options(
        headers: {
          'Referer': 'http://music.163.com/',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        },
        responseType: ResponseType.bytes,
      ),
      deleteOnError: true,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress?.call(received / total);
      },
    );
  }

  /// 清理缓存（启动时调用，保留最近50个）
  Future<void> trimCache({int keep = 50}) async {
    try {
      final cacheDir = await _cacheDir;
      final files = await cacheDir.list().toList();
      final mp3Files = files
          .whereType<File>()
          .where((f) => f.path.endsWith('.processed.mp3'))
          .toList();

      if (mp3Files.length <= keep) return;

      // 按修改时间排序，删旧的
      mp3Files.sort((a, b) {
        final ma = a.statSync().modified;
        final mb = b.statSync().modified;
        return ma.compareTo(mb);
      });

      for (var i = 0; i < mp3Files.length - keep; i++) {
        try {
          await mp3Files[i].delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// 获取缓存大小（MB）
  Future<double> getCacheSizeMB() async {
    try {
      final cacheDir = await _cacheDir;
      final files = await cacheDir.list().toList();
      int total = 0;
      for (final f in files) {
        if (f is File) total += await f.length();
      }
      return total / 1024 / 1024;
    } catch (_) {
      return 0;
    }
  }

  /// 清除全部缓存
  Future<void> clearCache() async {
    try {
      final cacheDir = await _cacheDir;
      await cacheDir.delete(recursive: true);
      await cacheDir.create();
    } catch (_) {}
  }
}
