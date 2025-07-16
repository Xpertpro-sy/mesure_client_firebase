import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../nav_bar_page.dart';
import '../service/firebase/auth.dart';
import 'home_page.dart';
import 'login_page.dart';

class RedirectionPage extends StatefulWidget {
  const RedirectionPage({super.key});

  @override
  State<RedirectionPage> createState() => _RedirectionPageState();
}

class _RedirectionPageState extends State<RedirectionPage> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
        stream: Auth().authStateChanges,
        builder: (context, snapshot) {
          // État de chargement
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          // Utilisateur connecté
          else if (snapshot.hasData && snapshot.data != null) {
            return const NavBarPage();
          }

          // Non authentifié
          else {
            return const LoginPage();
          }
        }
    );
  }
}
