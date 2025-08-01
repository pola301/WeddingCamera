import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';

class MediaService {
  static final ImagePicker _picker = ImagePicker();

  static Future<XFile?> captureMedia({required bool isVideo}) async {
    return isVideo
        ? await _picker.pickVideo(source: ImageSource.camera)
        : await _picker.pickImage(source: ImageSource.camera);
  }

  static Future<void> saveToGallery(String path) async {
    if (path.endsWith(".mp4")) {
      await Gal.putVideo(path);
    } else {
      await Gal.putImage(path);
    }
  }
}
