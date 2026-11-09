import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

class CameraCaptureService {
  static final ImagePicker _picker = ImagePicker();

  static Future<Uint8List?> capturePhotoFromLiveCamera() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 95,
      maxWidth: 2048,
      maxHeight: 2048,
    );

    if (photo == null) return null;
    return await photo.readAsBytes();
  }
}
