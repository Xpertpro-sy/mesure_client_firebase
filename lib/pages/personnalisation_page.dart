import 'package:client_mesure_firebase/model/measurement_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class PersonnalisationPage extends StatefulWidget {
  const PersonnalisationPage({super.key});

  @override
  State<PersonnalisationPage> createState() => _PersonnalisationPageState();
}

class _PersonnalisationPageState extends State<PersonnalisationPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  late MeasurementConfig _config;
  final TextEditingController _newMeasureController = TextEditingController();
  final TextEditingController _unitController = TextEditingController(text: "cm");

  @override
  void initState() {
    super.initState();
    _config = MeasurementConfig(
      userId: _currentUser!.uid,
      measurements: [],
      updatedAt: DateTime.now(),
    );
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final doc = await _firestore
        .collection('measurement_configs')
        .doc(_currentUser!.uid)
        .get();

    if (doc.exists) {
      setState(() {
        _config = MeasurementConfig.fromFirestore(doc);
      });
    }
  }

  Future<void> _saveConfig() async {
    final updatedConfig = _config.copyWith(updatedAt: DateTime.now());
    await _firestore
        .collection('measurement_configs')
        .doc(_currentUser!.uid)
        .set(updatedConfig.toFirestore());
  }

  void _addMeasurement() {
    if (_newMeasureController.text.isEmpty) return;

    setState(() {
      _config.measurements.add(
        CustomMeasurement(
          id: const Uuid().v4(),
          name: _newMeasureController.text,
          unit: _unitController.text,
        ),
      );
      _newMeasureController.clear();
    });
    _saveConfig();
  }

  void _removeMeasurement(int index) {
    setState(() {
      _config.measurements.removeAt(index);
    });
    _saveConfig();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          "Mesures Personnalisées",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveConfig,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _newMeasureController,
                    decoration: const InputDecoration(
                      labelText: 'Nouvelle mesure',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _unitController,
                    decoration: const InputDecoration(
                      labelText: 'Unité',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addMeasurement,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _config.measurements.length,
              itemBuilder: (context, index) {
                final measure = _config.measurements[index];
                return ListTile(
                  title: Text(measure.name),
                  subtitle: Text("Unité: ${measure.unit}"),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeMeasurement(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}