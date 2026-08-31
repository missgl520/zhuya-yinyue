import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 角色换装状态（Riverpod）
//
// 状态结构：
//   gender   → 性别（male/female）
//   hairId   → 发型 ID（对应 GLB 文件名）
//   topId    → 上装 ID
//   bottomId → 下装 ID
//   shoesId  → 鞋子 ID
//   eyeColor → 瞳色 ID
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

enum Gender { male, female }

// ─── 状态 ─────────────────────────────────────
class AvatarState {
  final Gender gender;
  final String? hairId, topId, bottomId, shoesId;
  final String eyeColor; // brown|blue|green|black|grey
  final bool isWalking; // true = 正在播放走路动画

  const AvatarState({
    this.gender = Gender.male,
    this.hairId,
    this.topId,
    this.bottomId,
    this.shoesId,
    this.eyeColor = 'blue',
    this.isWalking = false,
  });

  String get genderStr => gender == Gender.male ? 'male' : 'female';

  /// Flutter Asset 路径
  String get basePath =>
      'assets/vrm_test/avatar_system/base_$genderStr.glb';
  String? get hairPath   => hairId   != null ? 'assets/vrm_test/avatar_system/hair_${genderStr}_$hairId.glb'   : null;
  String? get topPath    => topId    != null ? 'assets/vrm_test/avatar_system/top_${genderStr}_$topId.glb'    : null;
  String? get bottomPath => bottomId != null ? 'assets/vrm_test/avatar_system/bottom_${genderStr}_$bottomId.glb' : null;
  String? get shoesPath  => shoesId  != null ? 'assets/vrm_test/avatar_system/shoes_${genderStr}_$shoesId.glb'  : null;
  String get eyePath => 'assets/vrm_test/avatar_system/eye_$eyeColor.glb';

  AvatarState copyWith({
    Gender? gender,
    String? hairId, bool clearHairId = false,
    String? topId,  bool clearTopId  = false,
    String? bottomId,bool clearBottomId = false,
    String? shoesId, bool clearShoesId = false,
    String? eyeColor,
    bool? isWalking,
  }) {
    return AvatarState(
      gender:   gender   ?? this.gender,
      hairId:   clearHairId   ? null : (hairId   ?? this.hairId),
      topId:    clearTopId    ? null : (topId    ?? this.topId),
      bottomId: clearBottomId ? null : (bottomId ?? this.bottomId),
      shoesId:  clearShoesId  ? null : (shoesId  ?? this.shoesId),
      eyeColor: eyeColor ?? this.eyeColor,
      isWalking: isWalking ?? this.isWalking,
    );
  }
}

// ─── 状态管理 ───────────────────────────────────
class AvatarStateNotifier extends StateNotifier<AvatarState> {
  AvatarStateNotifier() : super(const AvatarState());

  void switchGender(Gender g) {
    state = AvatarState(
      gender: g,
      hairId: state.hairId,
      topId: state.topId,
      bottomId: state.bottomId,
      shoesId: state.shoesId,
      eyeColor: state.eyeColor,
    );
  }

  void setHair(String? id) {
    if (id == '🔚CLEAR🔚') { state = state.copyWith(clearHairId: true); return; }
    state = state.copyWith(hairId: id);
  }
  void setTop(String? id) {
    if (id == '🔚CLEAR🔚') { state = state.copyWith(clearTopId: true); return; }
    state = state.copyWith(topId: id);
  }
  void setBottom(String? id) {
    if (id == '🔚CLEAR🔚') { state = state.copyWith(clearBottomId: true); return; }
    state = state.copyWith(bottomId: id);
  }
  void setShoes(String? id) {
    if (id == '🔚CLEAR🔚') { state = state.copyWith(clearShoesId: true); return; }
    state = state.copyWith(shoesId: id);
  }
  void setEyeColor(String color) {
    state = state.copyWith(eyeColor: color);
  }
  void setWalking(bool w) {
    state = state.copyWith(isWalking: w);
  }

  void reset() => state = const AvatarState();
}

// ─── Provider ───────────────────────────────────
final avatarStateProvider =
    StateNotifierProvider<AvatarStateNotifier, AvatarState>((ref) {
  return AvatarStateNotifier();
});

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 资源清单（静态）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class AvatarCatalog {
  // ── 可选配件列表 ──────────────────────────────
  static const List<String> maleHair = [
    'black_short', 'brown_short', 'blonde_short', 'black_long', 'grey_short'
  ];
  static const List<String> femaleHair = [
    'black_long', 'brown_bob', 'blonde_long', 'pink_bob', 'black_bun'
  ];
  static const List<String> maleTops = [
    'tshirt_red', 'tshirt_blue', 'tshirt_white', 'tshirt_black',
    'hoodie_grey', 'sweater_beige'
  ];
  static const List<String> femaleTops = [
    'tshirt_white', 'tshirt_pink', 'dress_pink', 'dress_black',
    'hoodie_purple', 'sweater_beige'
  ];
  static const List<String> maleBottoms = [
    'jeans_blue', 'jeans_black', 'pants_grey', 'pants_khaki', 'shorts_green'
  ];
  static const List<String> femaleBottoms = [
    'jeans_blue', 'skirt_red', 'skirt_black', 'shorts_green', 'pants_khaki'
  ];
  static const List<String> maleShoes = [
    'sneaker_white', 'sneaker_black', 'boots_brown', 'boots_black'
  ];
  static const List<String> femaleShoes = [
    'sneaker_white', 'sneaker_black', 'boots_brown', 'sandal_beige'
  ];
  static const List<String> eyeColors = [
    'brown', 'blue', 'green', 'black', 'grey'
  ];

  // ── 中文名称映射 ──────────────────────────────
  static const Map<String, String> hairNames = {
    'black_short': '黑色短发',   'brown_short': '棕色短发',
    'blonde_short': '金色短发',  'black_long':  '黑色长发',
    'grey_short':  '灰色短发',   'black_long':  '黑色长发',
    'brown_bob':   '棕色波波头', 'blonde_long': '金色长发',
    'pink_bob':    '粉色波波头', 'black_bun':   '黑色丸子头',
  };
  static const Map<String, String> topNames = {
    'tshirt_red':    '红色T恤',    'tshirt_blue':  '蓝色T恤',
    'tshirt_white':  '白色T恤',    'tshirt_black': '黑色T恤',
    'tshirt_pink':   '粉色T恤',    'hoodie_grey':  '灰色卫衣',
    'hoodie_purple': '紫色卫衣',   'sweater_beige':'米色毛衣',
    'dress_pink':    '粉色连衣裙', 'dress_black':  '黑色连衣裙',
  };
  static const Map<String, String> bottomNames = {
    'jeans_blue':   '蓝色牛仔裤', 'jeans_black':  '黑色牛仔裤',
    'pants_grey':   '灰色长裤',   'pants_khaki':  '卡其长裤',
    'shorts_green': '绿色短裤',   'skirt_red':     '红色短裙',
    'skirt_black':  '黑色短裙',
  };
  static const Map<String, String> shoesNames = {
    'sneaker_white': '白色运动鞋', 'sneaker_black': '黑色运动鞋',
    'boots_brown':   '棕色靴子',   'boots_black':   '黑色靴子',
    'sandal_beige':  '米色凉鞋',
  };
  static const Map<String, String> eyeNames = {
    'brown': '🌰 棕色', 'blue': '🔵 蓝色',
    'green':'🟢 绿色', 'black':'⚫ 黑色', 'grey': '⚪ 灰色',
  };

  // ── 瞳色色值（Flutter Color）─────────────────
  static const Map<String, Color> eyeColorSwatch = {
    'brown': Color(0xFF502815),
    'blue':  Color(0xFF1E50C8),
    'green': Color(0xFF268A3A),
    'black': Color(0xFF080808),
    'grey':  Color(0xFF76767A),
  };

  static String name(String category, String id) {
    if (id.isEmpty || id == '🔚CLEAR🔚') return '无';
    switch (category) {
      case 'hair':   return hairNames[id]   ?? id;
      case 'top':    return topNames[id]     ?? id;
      case 'bottom': return bottomNames[id]  ?? id;
      case 'shoes':  return shoesNames[id]   ?? id;
      case 'eye':    return eyeNames[id]     ?? id;
      default: return id;
    }
  }
}
