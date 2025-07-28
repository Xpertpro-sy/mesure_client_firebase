import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  /// Taille maximale de l'image (1MB)
  static const int maxImageSize = 1 * 1024 * 1024;

  /// Sélectionne et compresse une image
  Future<File?> pickAndCompressImage({
    ImageSource source = ImageSource.gallery,
    int maxWidth = 800,
    int maxHeight = 800,
    int quality = 70,
  }) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
      );

      if (pickedFile == null) return null;

      File imageFile = File(pickedFile.path);

      // Compression de l'image
      imageFile = await _compressImage(imageFile, quality: quality);

      // Vérifier la taille du fichier
      final int fileSize = await imageFile.length();
      if (fileSize > maxImageSize) {
        // Compression supplémentaire si nécessaire
        return await _compressImage(imageFile, quality: quality - 10);
      }

      return imageFile;
    } catch (e) {
      print('Erreur lors de la sélection de l\'image: $e');
      rethrow;
    }
  }

  /// Compresse une image
  Future<File> _compressImage(File file, {int quality = 70}) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/compressed_${path.basename(file.path)}';

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: quality,
    );

    if (result == null) {
      throw Exception('Échec de la compression de l\'image');
    }

    return File(result.path);
  }

  /// Upload une image vers Firebase Storage
  Future<String> uploadProfileImage(File imageFile, {String? oldImageUrl}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      // Vérifier la taille du fichier
      final int fileSize = await imageFile.length();
      if (fileSize > maxImageSize) {
        throw Exception('L\'image est trop volumineuse. Taille maximale: 1MB');
      }

      // Générer un nom de fichier unique
      final String fileName = 'profile_${user.uid}';
      final String extension = path.extension(imageFile.path);
      final String fullFileName = '$fileName$extension';

      // Référence vers le dossier des images de profil
      final Reference storageRef = _storage
          .ref()
          .child('profile_images')
          .child(fullFileName);

      // Upload du fichier
      final UploadTask uploadTask = storageRef.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/${extension.replaceAll('.', '')}',
          customMetadata: {'userId': user.uid},
        ),
      );

      // Attendre la fin de l'upload
      final TaskSnapshot snapshot = await uploadTask;

      // Récupérer l'URL de téléchargement
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // Supprimer l'ancienne image si elle existe
      if (oldImageUrl != null && oldImageUrl.isNotEmpty) {
        await deleteProfileImage(oldImageUrl);
      }

      return downloadUrl;
    } catch (e) {
      print('❌ Erreur lors de l\'upload de l\'image: $e');
      rethrow;
    }
  }

  /// Supprime une image du Storage
  Future<bool> deleteProfileImage(String imageUrl) async {
    try {
      // Extraire le chemin du fichier depuis l'URL
      final Uri uri = Uri.parse(imageUrl);
      final String filePath = uri.pathSegments.last;

      final Reference storageRef = _storage.ref(filePath);
      await storageRef.delete();
      return true;
    } catch (e) {
      print('Erreur lors de la suppression de l\'image: $e');
      return false;
    }
  }
}