import 'package:client_mesure_firebase/pages/autre_page.dart';
import 'package:client_mesure_firebase/pages/home_page.dart';
import 'package:client_mesure_firebase/pages/personnalisation_page.dart';
import 'package:client_mesure_firebase/pages/profil_page.dart';
import 'package:flutter/material.dart';


class NavBarPage extends StatefulWidget {
  final int initialTabIndex;

  const NavBarPage({super.key, this.initialTabIndex = 0});

  @override
  State<NavBarPage> createState() => _NavBarPageState();
}

class _NavBarPageState extends State<NavBarPage> {
  late int _currentIndex;
  late final List<Widget> screens;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    screens = [
      // const SizedBox.shrink(),
      MyHomePage(),
      AutrePage(),
      PersonnalisationPage(),
      ProfilPage(),
    ];
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: Colors.transparent,
    body: screens[_currentIndex],
    bottomNavigationBar: SizedBox(
      // height: 90,
      child: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey.shade600,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Accueil'
          ),
          // BottomNavigationBarItem(icon: Icon(Icons.notifications_sharp), label: 'Notification'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_sharp), label: 'Autre'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Personnalisation'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          /*BottomNavigationBarItem(icon: CircleAvatar(
            backgroundImage: AssetImage(
              'assets/abdoull.jpg',
            ),
            maxRadius: 12,
          ), label: 'Profil'),*/
        ],

        onTap: (index) {
          setState(() => _currentIndex = index);
        },
      ),
    ),
  );
}
