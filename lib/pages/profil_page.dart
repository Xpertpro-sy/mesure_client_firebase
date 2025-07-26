// import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../service/firebase/auth.dart';
import '../service/firebase/user_service.dart';
import '../service/firebase/init_firestore.dart';
import '../model/user_model.dart';
import 'edit_profile_page.dart';
// import '../service/firebase/auth.dart';

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

// Modèle de données pour les items de menu
class MenuItem {
  final String title;
  final IconData icon;
  final Color color;

  MenuItem({required this.title, required this.icon, required this.color});
}

class _ProfilPageState extends State<ProfilPage> {
  final User? user = Auth().currentUser;
  final UserService _userService = UserService();
  final FirestoreInitializer _firestoreInitializer = FirestoreInitializer();
  final double profileHeight = 144;
  UserModel? _userModel;
  bool _isLoading = true;

  // Fonction pour afficher le pop-up de déconnexion
  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icône d'avertissement
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.logout,
                    size: 40,
                    color: Colors.red.shade700,
                  ),
                ),

                const SizedBox(height: 20),

                // Titre
                const Text(
                  "Déconnexion",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 12),

                // Message
                const Text(
                  "Êtes-vous sûr de vouloir vous déconnecter ?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 24),

                // Boutons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Bouton Annuler
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "Annuler",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Bouton Déconnexion
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Fermer le pop-up
                          Auth().logout(); // Déconnexion
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Déconnecter",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      // Initialiser Firestore et créer la collection users si nécessaire
      await _firestoreInitializer.initializeFirestore();
      await _firestoreInitializer.createUserIfNotExists();
      
      final userModel = await _userService.getCurrentUser();
      setState(() {
        _userModel = userModel;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des données utilisateur: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _openEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilePage(user: _userModel),
        fullscreenDialog: true,
      ),
    );

    if (result != null && result is UserModel) {
      setState(() {
        _userModel = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<MenuItem> menuItems = [
      MenuItem(
        title: 'Modifier le profil',
        icon: Icons.edit_outlined,
        color: Colors.blue.shade700,
      ),
      MenuItem(
        title: 'Conditions d\'utilisation',
        icon: Icons.description_outlined,
        color: Colors.grey.shade700,
      ),
      MenuItem(
        title: 'Confidentialité',
        icon: Icons.lock_outline,
        color: Colors.grey.shade700,
      ),
      MenuItem(
        title: 'Informations',
        icon: Icons.info_outline,
        color: Colors.grey.shade700,
      ),
      MenuItem(
        title: 'Déconnexion',
        icon: Icons.logout,
        color: Colors.red,
      ),
    ];

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white,
                        ]),
                  ),
                ),
                title: const Text(
                  'Profil',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black),
                ),
                centerTitle: true,
              ),
            ),
          ];
        },
        body: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 16),
              _buildProfileCard(),
              _buildMenuSection(menuItems),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                height: profileHeight + 8,
                width: profileHeight + 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade500,
                      Colors.blue.shade800,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Positioned(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: _userModel?.profileImageUrl != null && _userModel!.profileImageUrl!.isNotEmpty
                      ? Image.network(
                          _userModel!.profileImageUrl!,
                          height: profileHeight,
                          width: profileHeight,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              'assets/logoHy.png',
                              height: profileHeight,
                              width: profileHeight,
                              fit: BoxFit.cover,
                            );
                          },
                        )
                      : Image.asset(
                          'assets/logoHy.png',
                          height: profileHeight,
                          width: profileHeight,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            _userModel?.fullName ?? 'SY Diakaridia',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            user?.email ?? 'User email',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatItem('128', 'Clients'),
              _buildDivider(),
              _buildStatItem('31 Jours', 'Abonnements'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(List<MenuItem> menuItems) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: List.generate(
          menuItems.length,
              (index) => Column(
            children: [
              ListTile(
                leading: Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: menuItems[index].color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    menuItems[index].icon,
                    color: menuItems[index].color,
                  ),
                ),
                title: Text(
                  menuItems[index].title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: menuItems[index].title == 'Déconnexion'
                        ? Colors.red
                        : Colors.black87,
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
                onTap: () {
                  if (menuItems[index].title == 'Modifier le profil') {
                    _openEditProfile();
                  } else if (menuItems[index].title == 'Déconnexion') {
                    _showLogoutConfirmation(context);
                  }
                },
              ),
              if (index < menuItems.length - 1)
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Colors.grey.shade200,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.grey.shade300,
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}