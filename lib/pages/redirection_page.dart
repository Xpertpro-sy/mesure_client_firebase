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
    return StreamBuilder(
        stream: Auth().authStateChanges,
        builder: (context, snapshot) {
          if(snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          } else if (snapshot.hasData) {
            return const NavBarPage();
          } else {
            return const LoginPage();
          }
        }
    );
  }
}
