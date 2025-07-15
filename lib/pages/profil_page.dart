// import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../service/firebase/auth.dart';
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
  final double profileHeight = 144;

  @override
  Widget build(BuildContext context) {
    final List<MenuItem> menuItems = [
      MenuItem(
        title: 'Modifier le profil',
        icon: Icons.edit_outlined,
        color: Colors.blue.shade700,
      ),
      // MenuItem(
      //   title: 'Paramètres',
      //   icon: Icons.settings_outlined,
      //   color: Colors.grey.shade700,
      // ),
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
              // expandedHeight: 220,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white,
                        ]
                    ),
                  ),
                ),
                title: const Text(
                  'Profil',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black
                  ),
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

              // Carte de profil
              _buildProfileCard(),

              // Section menu
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
              // Cercle d'arrière-plan avec dégradé
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

              // Image de profil
              Positioned(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: Image.asset(
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

          // Nom d'utilisateur
          const Text(
            'SY Diakaridia',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 8),

          // Identifiant
          Text(
            user?.email ?? 'User email',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 16),

          // Statistiques
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatItem('128', 'Clients'),
              // _buildDivider(),
              // _buildStatItem('2.4K', 'Abonnés'),
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
                  if (menuItems[index].title == 'Déconnexion') {
                    // Logique de déconnexion
                    Auth().logout();
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