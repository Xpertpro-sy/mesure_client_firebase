import 'package:flutter/material.dart';

class AutrePage extends StatefulWidget {
  const AutrePage({super.key});

  @override
  State<AutrePage> createState() => _AutrePageState();
}

class _AutrePageState extends State<AutrePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Autre page"),),
      body: Center(
          child: Center(
            child:  Text("Bienvenue dans autre page"),
          )
      ),
    );
  }
}
