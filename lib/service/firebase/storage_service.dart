import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  /// Taille maximale de l'image (5MB)
  static const int maxImageSize = 5 * 1024 * 1024;

  /// Sélectionne une image depuis la galerie avec compression basique
  Future<File?> pickImage({
    ImageSource source = ImageSource.gallery,
    int maxWidth = 1024,
    int maxHeight = 1024,
  }) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: 80, // Compression basique via imageQuality
      );

      if (pickedFile == null) return null;

      final File imageFile = File(pickedFile.path);
      
      // Vérifier la taille du fichier
      final int fileSize = await imageFile.length();
      if (fileSize > maxImageSize) {
        throw Exception('L\'image est trop volumineuse. Taille maximale: 5MB');
      }

      return imageFile;
    } catch (e) {
      print('Erreur lors de la sélection de l\'image: $e');
      rethrow;
    }
  }

  /// Upload une image vers Firebase Storage
  Future<String> uploadProfileImage(File imageFile) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      print('Début de l\'upload pour l\'utilisateur: ${user.uid}');

      // Vérifier la taille du fichier
      final int fileSize = await imageFile.length();
      if (fileSize > maxImageSize) {
        throw Exception('L\'image est trop volumineuse. Taille maximale: 5MB');
      }

      // Générer un nom de fichier unique
      final String fileName = 'profile_${user.uid}_${_uuid.v4()}';
      final String extension = path.extension(imageFile.path);
      final String fullFileName = '$fileName$extension';

      print('Nom du fichier: $fullFileName');

      // Référence vers le dossier des images de profil
      final Reference storageRef = _storage
          .ref()
          .child('profile_images')
          .child(fullFileName);

      print('Référence Storage créée');

      // Upload du fichier avec timeout réduit
      final UploadTask uploadTask = storageRef.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/${extension.replaceAll('.', '')}',
          customMetadata: {
            'userId': user.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      print('Upload task créé, attente...');

      // Attendre la fin de l'upload avec timeout de 30 secondes (réduit)
      final TaskSnapshot snapshot = await uploadTask.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout lors de l\'upload de l\'image (30 secondes). Vérifiez votre connexion internet.');
        },
      );

      print('Upload terminé, récupération de l\'URL...');
      
      // Récupérer l'URL de téléchargement
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('URL récupérée: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Erreur lors de l\'upload de l\'image: $e');
      rethrow;
    }
  }

  /// Supprime une image du Storage
  Future<bool> deleteProfileImage(String imageUrl) async {
    try {
      // Extraire le chemin du fichier depuis l'URL
      final Uri uri = Uri.parse(imageUrl);
      final String filePath = uri.pathSegments.last;
      
      final Reference storageRef = _storage
          .ref()
          .child('profile_images')
          .child(filePath);

      await storageRef.delete();
      return true;
    } catch (e) {
      print('Erreur lors de la suppression de l\'image: $e');
      return false;
    }
  }

  /// Vérifie si une URL est valide
  bool isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    
    try {
      final Uri uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Récupère la taille d'un fichier
  Future<int> getFileSize(File file) async {
    try {
      return await file.length();
    } catch (e) {
      print('Erreur lors de la récupération de la taille du fichier: $e');
      return 0;
    }
  }

  /// Formate la taille d'un fichier en format lisible
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
} 