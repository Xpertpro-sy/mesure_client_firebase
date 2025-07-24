import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class BuildModelScreen extends StatefulWidget {
  const BuildModelScreen({super.key});

  @override
  State<BuildModelScreen> createState() => _BuildModelScreenState();
}

class _BuildModelScreenState extends State<BuildModelScreen> {
  final ImagePicker _picker = ImagePicker();

  Uint8List? _modelImageBytes;
  Uint8List? _habitImageBytes;
  bool _isModelLoading = false;
  bool _isHabitLoading = false;
  Timer? _loadingTimer;

  // Variables pour l'affichage plein écran
  bool _isFullScreen = false;
  Uint8List? _fullScreenImage;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }


  Future<void> _pickImage(ImageSource source, bool isModel) async {
    try {
      setState(() {
        if (isModel) {
          _isModelLoading = true;
          _modelImageBytes = null;
        } else {
          _isHabitLoading = true;
          _habitImageBytes = null;
        }
      });

      final XFile? image = await _picker.pickImage(
        source: source,
        requestFullMetadata: kIsWeb,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();

        setState(() {
          if (isModel) {
            _modelImageBytes = bytes;
            _isModelLoading = false;
          } else {
            _habitImageBytes = bytes;
            _isHabitLoading = false;
          }
        });

      } else {
        setState(() {
          if (isModel) {
            _isModelLoading = false;
          } else {
            _isHabitLoading = false;
          }
        });
      }
    } catch (e) {
      print("Erreur: $e");
      setState(() {
        if (isModel) {
          _isModelLoading = false;
        } else {
          _isHabitLoading = false;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: $e")),
      );
    }
  }

  Future<void> _updateClientImage() async {}

  void _showFullScreenImage(Uint8List imageBytes) {
    setState(() {
      _isFullScreen = true;
      _fullScreenImage = imageBytes;
    });
  }

  Widget _buildImageCard(Uint8List? imageBytes, String label, bool isModel, bool isLoading) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: isLoading ? null : () {
                if (imageBytes != null) {
                  _showFullScreenImage(imageBytes);
                } else {
                  _showImagePickerModal(isModel);
                }
              },
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                color: const Color(0xFFD6D6D7),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Afficher l'image ou l'icône
                    if (imageBytes != null && !isLoading)
                      GestureDetector(
                        onTap: () => _showFullScreenImage(imageBytes),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.memory(
                            imageBytes,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    else if (!isLoading)
                      Center(
                        child: Icon(
                          Icons.camera_alt,
                          size: 50,
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                        ),
                      ),

                    // Indicateur de chargement
                    if (isLoading)
                      Container(
                        color: Colors.black.withOpacity(0.3),
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),

                    // Bouton d'édition (caché pendant le chargement)
                    if (!isLoading)
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white, size: 15,),
                              onPressed: () => _showImagePickerModal(isModel),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  void _showImagePickerModal(bool isModel) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, isModel);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Appareil photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, isModel);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    children: [
                      Icon(Icons.account_tree_rounded,
                          size: 60,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 20),
                      Text(
                        'Modèle Client',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'Vous pouvez joindre au maximum deux photos par client: l’une présentant le modèle, \nl’autre l\'habit.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              GridView.builder(
                  itemCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 0,
                      mainAxisExtent: 250,
                      mainAxisSpacing: 15
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    final isModel = index == 0;
                    final imageBytes = isModel ? _modelImageBytes : _habitImageBytes;
                    final isLoading = isModel ? _isModelLoading : _isHabitLoading;
                    final label = isModel ? "Modèle" : "Habit";

                    return _buildImageCard(imageBytes, label, isModel, isLoading);
                  }
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),

        // Overlay plein écran
        if (_isFullScreen && _fullScreenImage != null)
          Container(
            color: Colors.black87,
            child: Stack(
              children: [
                // Image en plein écran
                Center(
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.memory(_fullScreenImage!),
                  ),
                ),

                // Bouton de fermeture en haut à droite
                // Positioned(
                //   top: 40,
                //   right: 20,
                //   child: IconButton(
                //     icon: const Icon(Icons.close, size: 30, color: Colors.white),
                //     onPressed: () => setState(() => _isFullScreen = false),
                //   ),
                // ),

                // Bouton de fermeture en bas au centre
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.close, color: Colors.white),
                      label: const Text('Fermer', style: TextStyle(color: Colors.white)),
                      onPressed: () => setState(() => _isFullScreen = false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black54,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
      ],
    );
  }
}