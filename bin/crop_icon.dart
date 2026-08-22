// ignore_for_file: avoid_print
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/icons/icon.png');
  if (!file.existsSync()) {
    print('❌ Error: assets/icons/icon.png not found!');
    return;
  }

  print('🔄 Reading original icon...');
  final bytes = file.readAsBytesSync();
  final src = img.decodeImage(bytes);

  if (src == null) {
    print('❌ Error: Failed to decode image!');
    return;
  }

  print('📏 Original Size: ${src.width}x${src.height}');

  print('✂️ Trimming transparent borders...');
  // Trim transparent pixels from all sides
  final trimmed = img.trim(
    src,
    mode: img.TrimMode.transparent,
    sides: img.Trim.all,
  );

  // We add a tiny bit of padding (about 5% of the width) to make it look clean
  final padding = (trimmed.width * 0.05).round();
  print('➕ Adding padding of $padding pixels around the cropped logo...');

  final paddedWidth = trimmed.width + (padding * 2);
  final paddedHeight = trimmed.height + (padding * 2);

  // Create a new blank transparent image with padding
  final finalImage = img.Image(
    width: paddedWidth,
    height: paddedHeight,
    numChannels: 4,
  );
  // Fill with transparency
  finalImage.clear(img.ColorRgba8(0, 0, 0, 0));

  // Copy trimmed image into the center of finalImage
  img.compositeImage(
    finalImage,
    trimmed,
    dstX: padding,
    dstY: padding,
  );

  print('💾 Saving cropped and padded icon to assets/icons/icon.png...');
  file.writeAsBytesSync(img.encodePng(finalImage));
  print('✅ Done! New Size: ${finalImage.width}x${finalImage.height}');
}
