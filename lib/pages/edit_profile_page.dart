import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../model/user_model.dart';
import '../service/firebase/user_service.dart';
import '../service/firebase/storage_service.dart';
import '../common/validators.dart';

class EditProfilePage extends StatefulWidget {
  final UserModel? user;
  
  const EditProfilePage({
    super.key,
    this.user,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  final UserService _userService = UserService();
  final StorageService _storageService = StorageService();
  
  bool _isLoading = false;
  bool _isUploadingImage = false;
  String? _selectedImagePath;
  String? _currentImageUrl;
  File? _imageFile;
  
  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    if (widget.user != null) {
      _firstNameController.text = widget.user!.firstName ?? '';
      _lastNameController.text = widget.user!.lastName ?? '';
      _phoneController.text = widget.user!.phoneNumber ?? '';
      _currentImageUrl = widget.user!.profileImageUrl;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Sélectionne une image depuis la galerie
  Future<void> _pickImage() async {
    try {
      setState(() {
        _isUploadingImage = true;
      });

      // Utiliser directement le service alternatif pour éviter les problèmes avec flutter_image_compress
      final File? imageFile = await _storageService.pickImage();
      
      if (imageFile != null) {
        setState(() {
          _imageFile = imageFile;
          _selectedImagePath = imageFile.path;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors de la sélection de l\'image: $e');
    } finally {
      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  /// Sauvegarde les modifications du profil
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Sauvegarder d'abord les données sans image
      print('Début de la mise à jour du profil...');
      final updatedUser = await _userService.createOrUpdateUser(
        firstName: Validators.normalizeName(_firstNameController.text.trim()),
        lastName: Validators.normalizeName(_lastNameController.text.trim()),
        phoneNumber: _phoneController.text.trim(),
        profileImageUrl: _currentImageUrl, // Garder l'ancienne image pour l'instant
      );

      if (updatedUser == null) {
        print('Erreur lors de la mise à jour du profil');
        _showErrorSnackBar('Erreur lors de la mise à jour du profil');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Si une nouvelle image est sélectionnée, proposer de l'uploader plus tard
      if (_imageFile != null) {
        print('Image sélectionnée mais upload différé pour éviter le timeout');
        _showImageUploadDialog();
      }

      print('Profil mis à jour avec succès');
      _showSuccessSnackBar('Profil mis à jour avec succès !');
      Navigator.pop(context, updatedUser);
    } catch (e) {
      print('Erreur lors de la sauvegarde: $e');
      _showErrorSnackBar('Erreur: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showImageUploadDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Image sélectionnée'),
          content: const Text(
            'Votre profil a été sauvegardé avec succès !\n\n'
            'L\'image sélectionnée n\'a pas pu être uploadée à cause d\'un problème de connexion.\n\n'
            'Voulez-vous réessayer l\'upload de l\'image maintenant ?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Fermer la page de modification
              },
              child: const Text('Plus tard'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _uploadImageNow();
              },
              child: const Text('Uploader maintenant'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _uploadImageNow() async {
    if (_imageFile == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print('Tentative d\'upload de l\'image...');
      final String newImageUrl = await _storageService.uploadProfileImage(_imageFile!);
      print('Upload de l\'image terminé: $newImageUrl');
      
      // Mettre à jour l'URL de l'image
      await _userService.updateUserFields({
        'profileImageUrl': newImageUrl,
      });
      
      print('URL de l\'image mise à jour');
      _showSuccessSnackBar('Image uploadée avec succès !');
      Navigator.pop(context); // Fermer la page de modification
    } catch (e) {
      print('Erreur lors de l\'upload de l\'image: $e');
      _showErrorSnackBar('Erreur lors de l\'upload de l\'image: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {}, // Empêche la fermeture lors du tap sur le contenu
            child: DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      _buildHandle(),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHeader(),
                                const SizedBox(height: 24),
                                _buildProfileImageSection(),
                                const SizedBox(height: 24),
                                _buildFormFields(),
                                const SizedBox(height: 32),
                                _buildActionButtons(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                shape: const CircleBorder(),
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Modifier le profil',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Mettez à jour vos informations personnelles',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileImageSection() {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 3),
              ),
              child: ClipOval(
                child: _buildProfileImage(),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: IconButton(
                  onPressed: _isUploadingImage ? null : _pickImage,
                  icon: _isUploadingImage
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.camera_alt, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: const CircleBorder(),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Photo de profil',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        if (_imageFile != null) ...[
          const SizedBox(height: 8),
          Text(
            'Nouvelle image sélectionnée',
            style: TextStyle(
              fontSize: 14,
              color: Colors.green.shade600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProfileImage() {
    if (_imageFile != null) {
      return Image.file(
        _imageFile!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultProfileImage();
        },
      );
    } else if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
      return Image.network(
        _currentImageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultProfileImage();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
      );
    } else {
      return _buildDefaultProfileImage();
    }
  }

  Widget _buildDefaultProfileImage() {
    return Container(
      color: Colors.grey.shade200,
      child: const Icon(
        Icons.person,
        size: 60,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        _buildTextField(
          controller: _firstNameController,
          label: 'Prénom',
          hint: 'Entrez votre prénom',
          validator: Validators.validateName,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _lastNameController,
          label: 'Nom',
          hint: 'Entrez votre nom',
          validator: Validators.validateName,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _phoneController,
          label: 'Numéro de téléphone',
          hint: 'Entrez votre numéro de téléphone',
          validator: null, // Pas de validation
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Sauvegarder',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        if (_imageFile != null) ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: _isLoading ? null : () {
                setState(() {
                  _imageFile = null;
                  _selectedImagePath = null;
                });
                _showSuccessSnackBar('Image supprimée');
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.orange.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Supprimer l\'image',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.orange,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Annuler',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
} 