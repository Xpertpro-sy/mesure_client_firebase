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

  Future<void> _pickImage() async {
    try {
      setState(() => _isUploadingImage = true);
      
      final File? imageFile = await _storageService.pickImage();
      
      if (imageFile != null) {
        setState(() {
          _imageFile = imageFile;
          _selectedImagePath = imageFile.path;
        });
        print('Nouvelle image sélectionnée: ${imageFile.path}');
      }
    } catch (e) {
      _showErrorSnackBar('Erreur: ${e.toString()}');
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      print('🔄 Début de la sauvegarde du profil');
      
      String? newImageUrl = _currentImageUrl;
      final firstName = Validators.normalizeName(_firstNameController.text.trim());
      final lastName = Validators.normalizeName(_lastNameController.text.trim());
      final phoneNumber = _phoneController.text.trim();

      print('📝 Données à sauvegarder:');
      print('   - Prénom: "$firstName"');
      print('   - Nom: "$lastName"');
      print('   - Téléphone: "$phoneNumber"');
      print('   - Image actuelle: $_currentImageUrl');

      // 1. Uploader la nouvelle image SI elle existe
      if (_imageFile != null) {
        print('📤 Upload de la nouvelle image...');
        newImageUrl = await _storageService.uploadProfileImage(_imageFile!);
        print('✅ Nouvelle URL d\'image: $newImageUrl');
      } else {
        print('ℹ️ Aucune nouvelle image à uploader');
      }

      // 2. Mettre à jour le profil avec la nouvelle image
      print('💾 Mise à jour du profil dans Firestore...');
      final updatedUser = await _userService.createOrUpdateUser(
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        profileImageUrl: newImageUrl,
      );

      if (updatedUser == null) throw Exception('Échec de la mise à jour du profil');

      print('✅ Profil mis à jour avec succès:');
      print('   - Prénom: "${updatedUser.firstName}"');
      print('   - Nom: "${updatedUser.lastName}"');
      print('   - Téléphone: "${updatedUser.phoneNumber}"');
      print('   - Image: "${updatedUser.profileImageUrl}"');

      _showSuccessSnackBar('Profil mis à jour avec succès !');
      Navigator.pop(context, updatedUser);
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde: $e');
      _showErrorSnackBar('Erreur: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showImageUploadDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Image sélectionnée'),
        content: const Text(
          'Voulez-vous uploader l\'image maintenant ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _uploadImageNow();
            },
            child: const Text('Uploader'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadImageNow() async {
    if (_imageFile == null) return;

    setState(() => _isLoading = true);

    try {
      final newImageUrl = await _storageService.uploadProfileImage(_imageFile!);
      await _userService.updateUserFields({'profileImageUrl': newImageUrl});
      _showSuccessSnackBar('Image uploadée !');
    } catch (e) {
      _showErrorSnackBar('Erreur upload: $e');
    } finally {
      setState(() => _isLoading = false);
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
            onTap: () {},
            child: DraggableScrollableSheet(
              initialChildSize: 0.92,
              minChildSize: 0.6,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
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
                                const SizedBox(height: 32),
                                _buildProfileImageSection(),
                                const SizedBox(height: 32),
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
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        width: 48,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.grey.shade400,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, size: 28),
            ),
            const Text(
              'Modifier le profil',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 48), // Pour l'alignement
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Mettez à jour vos informations personnelles',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileImageSection() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.blue.shade100,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade100.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 4,
                  )
                ],
              ),
              child: ClipOval(
                child: _buildProfileImage(),
              ),
            ),
            Positioned(
              bottom: 6,
              right: 6,
              child: GestureDetector(
                onTap: _isUploadingImage ? null : _pickImage,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: _isUploadingImage
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.edit, size: 20, color: Colors.white),
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
      ],
    );
  }

  Widget _buildProfileImage() {
    if (_imageFile != null) {
      return Image.file(_imageFile!, fit: BoxFit.cover);
    } else if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
      return Image.network(
        _currentImageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => _buildDefaultProfileImage(),
      );
    } else {
      return _buildDefaultProfileImage();
    }
  }

  Widget _buildDefaultProfileImage() {
    return Container(
      color: Colors.grey.shade100,
      child: Icon(
        Icons.person,
        size: 60,
        color: Colors.grey.shade400,
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        _buildTextField(
          controller: _firstNameController,
          label: 'Prénom',
          hint: 'Votre prénom',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _lastNameController,
          label: 'Nom',
          hint: 'Votre nom de famille',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _phoneController,
          label: 'Téléphone',
          hint: 'Votre numéro',
          icon: Icons.phone_iphone_outlined,
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: InputBorder.none,
              prefixIcon: Icon(icon, color: Colors.grey.shade500),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
            style: const TextStyle(fontSize: 16),
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
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  )
                : const Text(
                    'SAUVEGARDER',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        if (_imageFile != null) ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : () {
                setState(() => _imageFile = null);
                _showSuccessSnackBar('Image supprimée');
              },
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text(
                'SUPPRIMER L\'IMAGE',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
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
              side: BorderSide(color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'ANNULER',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}