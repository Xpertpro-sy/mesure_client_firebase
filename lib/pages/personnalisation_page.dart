import 'package:flutter/material.dart';

class PersonnalisationPage extends StatefulWidget {
  const PersonnalisationPage({super.key});

  @override
  State<PersonnalisationPage> createState() => _PersonnalisationPageState();
}

class _PersonnalisationPageState extends State<PersonnalisationPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Personnalisation page"),),
      body: Center(
        child: Center(
          child:  Text("Personnalisation page"),
        )
      ),
    );
  }
}
