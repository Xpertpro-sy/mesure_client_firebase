import 'package:client_mesure_firebase/model/measurement_config.dart';
import 'package:client_mesure_firebase/model/measurement_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class CreateMeasurementPage extends StatefulWidget {
  const CreateMeasurementPage({super.key});

  @override
  State<CreateMeasurementPage> createState() => _CreateMeasurementPageState();
}

class _CreateMeasurementPageState extends State<CreateMeasurementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _clientNameController = TextEditingController();
  late MeasurementConfig _config;
  final Map<String, TextEditingController> _measureControllers = {};

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
    if (_currentUser == null) return; // Vérifiez que l'utilisateur est connecté

    final doc = await _firestore
        .collection('measurement_configs')
        .doc(_currentUser!.uid) // Doit être l'UID utilisateur
        .get();

    if (doc.exists) {
      setState(() {
        _config = MeasurementConfig.fromFirestore(doc);
        // Initialiser les contrôleurs pour chaque mesure
        for (var measure in _config.measurements) {
          _measureControllers[measure.id] = TextEditingController(
            text: measure.defaultValue ?? '',
          );
        }
      });
    }
  }

  Future<void> _createMeasurement() async {
    final measurementsMap = <String, String>{};
    for (var measure in _config.measurements) {
      measurementsMap[measure.name] = _measureControllers[measure.id]!.text;
    }

    final newMeasurement = Measurement(
      clientName: _clientNameController.text,
      measurements: measurementsMap,
      createdAt: DateTime.now(),
      userId: _currentUser!.uid,
      uuid: const Uuid().v4(),
      configId: _currentUser!.uid, // Sauvegarde la config utilisée
      // ... autres champs
    );

    await _firestore.collection('measurements').add(newMeasurement.toFirestore());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nouvelle Mesure")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _clientNameController,
              decoration: const InputDecoration(
                labelText: 'Nom du client',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _config.measurements.length,
                itemBuilder: (context, index) {
                  final measure = _config.measurements[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: _measureControllers[measure.id],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: measure.name,
                        suffixText: measure.unit,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: _createMeasurement,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text("Créer la Mesure"),
            ),
          ],
        ),
      ),
    );
  }
}