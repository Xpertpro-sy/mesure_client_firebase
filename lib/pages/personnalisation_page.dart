import 'dart:async';

import 'package:client_mesure_firebase/model/measurement_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:uuid/uuid.dart';

import '../common/color_extention.dart';

class PersonnalisationPage extends StatefulWidget {
  const PersonnalisationPage({super.key});

  @override
  State<PersonnalisationPage> createState() => _PersonnalisationPageState();
}

class _PersonnalisationPageState extends State<PersonnalisationPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _newMeasureController = TextEditingController();
  final TextEditingController _unitController = TextEditingController(text: "cm");
  bool _isSaving = false;
  bool _isLoading = true;
  bool _isOnline = true;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  late Box<MeasurementConfig> _configBox;
  bool _hiveInitialized = false;
  late ValueNotifier<MeasurementConfig> _configNotifier;

  @override
  void initState() {
    super.initState();
    // Initialiser avec une configuration par défaut
    _configNotifier = ValueNotifier(MeasurementConfig(
      userId: _currentUser!.uid,
      measurements: [],
      updatedAt: DateTime.now(),
    ));
    _initHive();
    _initConnectivity();
  }

  Future<void> _initHive() async {
    try {
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(MeasurementConfigAdapter());
        Hive.registerAdapter(CustomMeasurementAdapter());
      }

      _configBox = await Hive.openBox<MeasurementConfig>('measurement_configs');
      setState(() => _hiveInitialized = true);

      // Charger la configuration initiale
      if (_configBox.containsKey(_currentUser!.uid)) {
        final config = _configBox.get(_currentUser!.uid)!;
        _configNotifier.value = config;
      }

      setState(() => _isLoading = false); // Déplacez ici

      // Appeler la synchronisation après le chargement initial
      if (_isOnline) {
        _syncWithFirestore();
      }
    } catch (e) {
      print("Erreur d'initialisation Hive: $e");
      setState(() {
        _hiveInitialized = true;
        _isLoading = false;
      });
    }
  }

  void _initConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) setState(() => _isOnline = result.any((r) => r != ConnectivityResult.none));

    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final newStatus = results.any((r) => r != ConnectivityResult.none);

      if (newStatus != _isOnline && mounted) {
        setState(() => _isOnline = newStatus);
        if (newStatus) {
          _syncWithFirestore();
        }
      }
    });
  }

  Future<void> _syncWithFirestore() async {
    try {
      final doc = await _firestore
          .collection('measurement_configs')
          .doc(_currentUser!.uid)
          .get();

      if (doc.exists) {
        final remoteConfig = MeasurementConfig.fromFirestore(doc);
        final localConfig = _configBox.get(_currentUser!.uid);
        final mergedConfig = _mergeConfigs(localConfig, remoteConfig);

        // Mettre à jour le cache local
        await _configBox.put(_currentUser!.uid, mergedConfig);

        // Mettre à jour le ValueNotifier
        if (mounted) {
          _configNotifier.value = mergedConfig;
        }

        if (localConfig != null &&
            localConfig.updatedAt.isAfter(remoteConfig.updatedAt)) {
          await _saveToFirestore(localConfig);
        }
      } else if (_configBox.containsKey(_currentUser!.uid)) {
        final config = _configBox.get(_currentUser!.uid)!;
        await _saveToFirestore(config);
      }
    } catch (e) {
      print("Erreur de synchronisation: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  MeasurementConfig _mergeConfigs(
      MeasurementConfig? local,
      MeasurementConfig remote
      ) {
    if (local == null) return remote;

    // Fusionner les mesures
    final allMeasurements = {...remote.measurements};

    for (final localMeasure in local.measurements) {
      // Garder la version la plus récente
      final remoteMeasure = allMeasurements.firstWhere(
            (m) => m.id == localMeasure.id,
        orElse: () => localMeasure,
      );

      if (remoteMeasure.updatedAt.isBefore(localMeasure.updatedAt)) {
        allMeasurements.remove(remoteMeasure);
        allMeasurements.add(localMeasure);
      }
    }

    return remote.copyWith(measurements: allMeasurements.toList());
  }

  Future<void> _saveToFirestore(MeasurementConfig config) async {
    await _firestore
        .collection('measurement_configs')
        .doc(_currentUser!.uid)
        .set(config.toFirestore());
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _configNotifier.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      // Cette partie est déjà faite dans les méthodes d'ajout/suppression
      // final updatedConfig = _configNotifier.value.copyWith(updatedAt: DateTime.now());
      // await _configBox.put(_currentUser!.uid, updatedConfig);
      // _configNotifier.value = updatedConfig;

      if (_isOnline) {
        // Sauvegarder la configuration actuelle dans Firestore
        await _saveToFirestore(_configNotifier.value);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Configuration sauvegardée"),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            )
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Configuration sauvegardée localement"),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            )
        );
      }
    } catch (e) {
      print("Erreur: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _addMeasurement() {
    if (_newMeasureController.text.isEmpty) return;

    final newMeasure = CustomMeasurement(
      id: const Uuid().v4(),
      name: _newMeasureController.text,
      unit: _unitController.text,
      updatedAt: DateTime.now(),
    );

    // Créer une nouvelle configuration avec la mesure ajoutée
    final updatedConfig = _configNotifier.value.copyWith(
      measurements: [..._configNotifier.value.measurements, newMeasure],
      updatedAt: DateTime.now(),
    );

    // Sauvegarder dans Hive
    _configBox.put(_currentUser!.uid, updatedConfig);

    // Mettre à jour le ValueNotifier IMMÉDIATEMENT
    _configNotifier.value = updatedConfig;

    _newMeasureController.clear();
    _saveConfig(); // Cette méthode sauvegardera aussi dans Firestore si en ligne
  }

  void _removeMeasurement(int index) {
    final updatedMeasurements = List<CustomMeasurement>.from(_configNotifier.value.measurements);
    updatedMeasurements.removeAt(index);

    final updatedConfig = _configNotifier.value.copyWith(
      measurements: updatedMeasurements,
      updatedAt: DateTime.now(),
    );

    // Sauvegarder dans Hive
    _configBox.put(_currentUser!.uid, updatedConfig);

    // Mettre à jour le ValueNotifier IMMÉDIATEMENT
    _configNotifier.value = updatedConfig;

    _saveConfig();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            "Mesures Personnalisées",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: _isSaving
                  ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(TColor.principal1),
                ),
              )
                  : Icon(Icons.save, color: TColor.principal1),
              onPressed: _isSaving ? null : _saveConfig,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ValueListenableBuilder<MeasurementConfig>(
          valueListenable: _configNotifier,
          builder: (context, config, _) {
            return Column(
              children: [
                _buildInputSection(),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text(
                        "Mesures existantes",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: TColor.principal1Opacity,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          config.measurements.length.toString(),
                          style: TextStyle(
                            color: TColor.principal1,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: config.measurements.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.straighten_outlined,
                            size: 60,
                            color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text(
                          "Aucune mesure créée",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Ajoutez votre première mesure",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: config.measurements.length,
                    itemBuilder: (context, index) {
                      return _buildMeasurementItem(
                          config.measurements[index], index);
                    },
                  ),
                ),
              ],
            );
          },
        )
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Ajouter une nouvelle mesure",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newMeasureController,
                  decoration: InputDecoration(
                    labelText: 'Nom de la mesure',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    prefixIcon: Icon(Icons.edit, color: Colors.grey.shade500),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _unitController,
                  decoration: InputDecoration(
                    labelText: 'Unité',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FloatingActionButton(
                mini: true,
                onPressed: _addMeasurement,
                backgroundColor: TColor.principal1,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementItem(CustomMeasurement measure, int index) {
    return Dismissible(
      key: Key(measure.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white, size: 30),
      ),
      onDismissed: (direction) => _removeMeasurement(index),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: TColor.principal1.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.straighten_outlined, color: TColor.principal1),
          ),
          title: Text(
            measure.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text("Unité: ${measure.unit}"),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _removeMeasurement(index),
          ),
        ),
      ),
    );
  }
}