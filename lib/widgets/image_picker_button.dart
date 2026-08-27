// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 图片选择按钮（已接入 image_picker）
//
// 触发：聊天输入区「＋」按钮
// 能力：从相册选择 / 拍照，选定后通过 onImagePicked 回调返回本地路径
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerButton extends StatelessWidget {
  const ImagePickerButton({super.key, this.onImagePicked});

  /// 选定图片后的回调（返回本地文件路径）
  final void Function(String path)? onImagePicked;

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.gallery, context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.camera, context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(ImageSource source, BuildContext context) async {
    try {
      final xfile = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (xfile != null) onImagePicked?.call(xfile.path);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('选择图片失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _showPicker(context),
      icon: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2A2A2A)
              : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(
          Icons.add_photo_alternate_outlined,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[400]
              : Colors.grey[600],
        ),
      ),
      tooltip: '添加图片',
    );
  }
}
