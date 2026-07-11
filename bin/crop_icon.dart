import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/icons/icon.png');
  if (!file.existsSync()) {
    print('Error: icon.png not found');
    return;
  }
  
  final bytes = file.readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) {
    print('Error: failed to decode image');
    return;
  }
  
  print('Original size: ${image.width}x${image.height}');
  
  // Apply a fixed crop of 65 pixels on all sides
  const cropMargin = 65;
  final cropX = cropMargin;
  final cropY = cropMargin;
  final size = image.width - (cropMargin * 2);
  
  print('Cropping fixed square: X: $cropX, Y: $cropY, Size: $size');
  
  final cropped = img.copyCrop(image, x: cropX, y: cropY, width: size, height: size);
  
  final croppedBytes = img.encodePng(cropped);
  
  // Overwrite icon.png with the new cropped version!
  File('assets/icons/icon.png').writeAsBytesSync(croppedBytes);
  print('Successfully cropped and updated assets/icons/icon.png!');
}
