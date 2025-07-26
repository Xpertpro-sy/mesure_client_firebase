import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../common/color_extention.dart';
import '../model/measurement_config.dart';
import '../model/measurement_model.dart';

import 'package:rxdart/rxdart.dart';

import 'MeasurementDetailPage.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _nomCompletController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _searchNotifier = ValueNotifier('');
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  final List<String> _availableLabels = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'
  ];
  List<MeasureInput> _currentMeasureInputs = [];
  bool _isLoading = false;
  bool _isDeleting = false;
  String? _deletingId;
  double? _prix;
  double? _avance;

  bool _isOnline = true;
  final _syncController = StreamController<void>();
  bool _isHiveInitialized = false;
  bool _isInitialSyncDone = false;

  bool _isSyncing = false;
  final Set<String> _syncedUuids = {};
  Box<Measurement>? _pendingBox;
  bool _hadPendingMeasurements = false;


  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resetForm();
      _initHive().then((_) {
        _initConnectivity();
        _setupOfflineListener();
        _startConnectivityCheck(); // Démarrer la vérification périodique
      });
    });

    _searchController.addListener(() {
      _searchNotifier.value = _searchController.text;
    });
  }

  // Simplifier _init Hive
  Future<void> _initHive() async {
    try {
      // Initialiser Hive pour Flutter - AJOUTER CETTE LIGNE
      await Hive.initFlutter();

      // Vérifier si Hive est déjà initialisé
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(MeasurementAdapter());
      }

      // Ouvrir la boîte
      _pendingBox = await Hive.openBox<Measurement>('pending_measurements');

      // Migration des anciennes données - VÉRIFIER NULLITÉ
      if (_pendingBox != null) {
        final keys = _pendingBox!.keys.toList();
        for (var key in keys) {
          final m = _pendingBox!.get(key);
          if (m != null && m.uuid.isEmpty) {
            await _pendingBox!.put(key, m.copyWith(uuid: const Uuid().v4()));
          }
        }
      }

      setState(() => _isHiveInitialized = true);
    } catch (e) {
      print("Erreur d'initialisation Hive: $e");
      setState(() => _isHiveInitialized = true);
    }
  }

  Future<void> _initConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    final hasNetwork = result != ConnectivityResult.none;

    // Tester la vraie connectivité Firebase si on a un réseau
    bool online = false;
    if (hasNetwork) {
      online = await _testFirebaseConnectivity();
    }

    if (mounted) setState(() => _isOnline = online);

    // Ajouter ceci pour déclencher la sync immédiatement
    if (online && _isHiveInitialized) {
      await _syncPendingMeasurements();
    }
  }

  Future<bool> _testFirebaseConnectivity() async {
    try {
      // Vérifier d'abord si l'utilisateur est connecté
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('🔴 Test de connectivité: Aucun utilisateur connecté');
        return false;
      }

      // Test de connectivité Firestore en utilisant une collection autorisée
      await FirebaseFirestore.instance
          .collection('measurement_configs')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 5));
      
      print('✅ Test de connectivité Firebase réussi');
      return true;
    } catch (e) {
      print('🔴 Test de connectivité Firebase échoué: $e');
      return false;
    }
  }

  // Méthode pour tester périodiquement la connectivité
  void _startConnectivityCheck() {
    Timer.periodic(const Duration(minutes: 2), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      final currentStatus = _isOnline;
      final newStatus = await _testFirebaseConnectivity();
      
      if (currentStatus != newStatus && mounted) {
        setState(() => _isOnline = newStatus);
        print('🔄 Statut de connectivité changé: ${currentStatus ? 'en ligne' : 'hors ligne'} -> ${newStatus ? 'en ligne' : 'hors ligne'}');
        
        if (newStatus) {
          // Synchroniser les mesures en attente
          Future.delayed(const Duration(seconds: 1), () {
            _syncPendingMeasurements();
          });
        }
      }
    });
  }

  void _setupOfflineListener() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      final hasNetwork = results.any(
              (result) => result != ConnectivityResult.none
      );

      bool newStatus = false;
      if (hasNetwork) {
        newStatus = await _testFirebaseConnectivity();
      }

      if (newStatus != _isOnline) {
        setState(() => _isOnline = newStatus);
        if (newStatus) {
          // Ajouter un délai pour laisser la connexion s'établir
          Future.delayed(const Duration(seconds: 2), () {
            _syncPendingMeasurements();
          });
        }
      }
    });
  }

  Future<void> _syncPendingMeasurements() async {
    final user = FirebaseAuth.instance.currentUser;

    // Vérification des pré-conditions essentielles
    if (user == null) {
      print('🔴 Sync impossible: Aucun utilisateur connecté');
      return;
    }

    if (!_isHiveInitialized || _pendingBox == null) {
      print('🔴 Sync impossible: Hive non initialisé');
      return;
    }

    if (!_isOnline) {
      print('🔴 Sync impossible: Hors ligne');
      return;
    }

    if (_isSyncing) {
      print('🔄 Sync déjà en cours');
      return;
    }

    // Début de la synchronisation
    if (mounted) setState(() => _isSyncing = true);

    try {
      final keys = _pendingBox!.keys.toList();
      final int initialCount = keys.length;
      int syncedCount = 0; // Compteur de mesures synchronisées

      print('🔎 ${initialCount} mesures en attente de synchronisation');
      _hadPendingMeasurements = initialCount > 0;

      for (final key in keys) {
        if (!mounted) {
          print('⚠️ Synchronisation interrompue: Widget démonté');
          return;
        }

        final measurement = _pendingBox!.get(key);

        if (measurement == null) {
          print('🗑️ Suppression clé $key: Mesure null');
          await _pendingBox!.delete(key);
          continue;
        }

        if (measurement.userId != user.uid) {
          print('👥 Suppression mesure ${measurement.uuid}: Mauvais utilisateur');
          await _pendingBox!.delete(key);
          continue;
        }

        try {
          if (measurement.userId.isEmpty) {
            print('❌ Mesure ${measurement.uuid} invalide: userID manquant');
            await _pendingBox!.delete(key);
            continue;
          }

          await _pendingBox!.delete(key); // <-- Ajout crucial
          print('🗑️ Suppression locale après synchro: ${measurement.uuid}');

          // Vérifier que l'UUID est valide
          if (measurement.uuid.isEmpty || !RegExp(r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$').hasMatch(measurement.uuid)) {
            print('❌ UUID invalide: ${measurement.uuid}');
            await _pendingBox!.delete(key);
            continue;
          }

          // Créer une nouvelle mesure avec le statut mis à jour
          final syncedMeasurement = measurement.copyWith(
            status: 'synced',
            syncedAt: DateTime.now(),
          );

          final docRef = _firestore.collection('measurements').doc(syncedMeasurement.uuid);
          final data = syncedMeasurement.toFirestore();

          try {
            // Essayer de créer le document
            await docRef.set(data, SetOptions(merge: false));
            print('✅ Création réussie pour ${syncedMeasurement.uuid}');
          } on FirebaseException catch (e) {
            if (e.code == 'already-exists') {
              // METTRE À JOUR AVEC LA VERSION SYNCHRONISÉE
              await docRef.update(syncedMeasurement.toFirestore()); // <-- Modification ici
              print('✅ Mise à jour réussie pour ${syncedMeasurement.uuid}');
            } else {
              rethrow;
            }
          }

          await _pendingBox!.delete(key);
          syncedCount++;
          print('🗑️ Mesure ${syncedMeasurement.uuid} supprimée du stockage local');

        } on FirebaseException catch (e) {
          // Gestion des erreurs Firebase
          if (e.code == 'permission-denied') {
            print('🔒 Erreur permission pour ${measurement.uuid}: ${e.message}');
            await Future.delayed(const Duration(milliseconds: 100));

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Permission refusée pour ${measurement.clientName}'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 5),
                  )
              );
            }
          }
          else if (e.code == 'invalid-argument') {
            print('❌ Données invalides pour ${measurement.uuid}: ${e.message}');
          }
          else {
            print('🔥 Erreur Firebase [${e.code}]: ${e.message}');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur ${e.code}: ${e.message}'),
                    backgroundColor: Colors.orange,
                  )
              );
            }
          }

          // Conserver la mesure dans Hive pour une prochaine tentative
          print('📦 Conservation de ${measurement.uuid} pour re-synchronisation');
        } catch (e) {
          print('❌ Erreur générale: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erreur inattendue: ${e.toString()}'),
                  backgroundColor: Colors.deepOrange,
                )
            );
          }
          // Conserver la mesure dans Hive
          print('📦 Conservation de ${measurement.uuid} pour re-synchronisation');
        }
      }

      if (syncedCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: _buildSyncedAnimation(syncedCount),
            backgroundColor: TColor.principal2,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
      print('🛑 Synchronisation terminée');
    }
  }

  // Future<void> _syncPendingMeasurements() async {
  //   final user = FirebaseAuth.instance.currentUser;
  //
  //   // Vérification des pré-conditions essentielles
  //   if (user == null) {
  //     print('🔴 Sync impossible: Aucun utilisateur connecté');
  //     return;
  //   }
  //
  //   if (!_isHiveInitialized || _pendingBox == null) {
  //     print('🔴 Sync impossible: Hive non initialisé');
  //     return;
  //   }
  //
  //   if (!_isOnline) {
  //     print('🔴 Sync impossible: Hors ligne');
  //     return;
  //   }
  //
  //   if (_isSyncing) {
  //     print('🔄 Sync déjà en cours');
  //     return;
  //   }
  //
  //   // Début de la synchronisation
  //   if (mounted) setState(() => _isSyncing = true);
  //
  //   try {
  //     final keys = _pendingBox!.keys.toList();
  //     final int initialCount = keys.length;
  //     int syncedCount = 0; // Compteur de mesures synchronisées
  //
  //     print('🔎 ${initialCount} mesures en attente de synchronisation');
  //     _hadPendingMeasurements = initialCount > 0;
  //
  //     for (final key in keys) {
  //       if (!mounted) {
  //         print('⚠️ Synchronisation interrompue: Widget démonté');
  //         return;
  //       }
  //
  //       final measurement = _pendingBox!.get(key);
  //
  //       if (measurement == null) {
  //         print('🗑️ Suppression clé $key: Mesure null');
  //         await _pendingBox!.delete(key);
  //         continue;
  //       }
  //
  //       if (measurement.userId != user.uid) {
  //         print('👥 Suppression mesure ${measurement.uuid}: Mauvais utilisateur');
  //         await _pendingBox!.delete(key);
  //         continue;
  //       }
  //
  //       try {
  //         if (measurement.userId.isEmpty) {
  //           print('❌ Mesure ${measurement.uuid} invalide: userID manquant');
  //           await _pendingBox!.delete(key);
  //           continue;
  //         }
  //
  //         // Vérifier que l'UUID est valide
  //         if (measurement.uuid.isEmpty ||
  //             !RegExp(r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$')
  //                 .hasMatch(measurement.uuid)) {
  //           print('❌ UUID invalide: ${measurement.uuid}');
  //           await _pendingBox!.delete(key);
  //           continue;
  //         }
  //
  //         // Créer une nouvelle mesure avec le statut mis à jour
  //         final syncedMeasurement = measurement.copyWith(
  //           status: 'synced',
  //           syncedAt: DateTime.now(),
  //         );
  //
  //         final docRef = _firestore.collection('measurements').doc(syncedMeasurement.uuid);
  //         final data = syncedMeasurement.toFirestore();
  //
  //         try {
  //           // Essayer de créer le document
  //           await docRef.set(data, SetOptions(merge: false));
  //           print('✅ Création réussie pour ${syncedMeasurement.uuid}');
  //         } on FirebaseException catch (e) {
  //           if (e.code == 'already-exists') {
  //             // Mettre à jour avec la version synchronisée
  //             await docRef.update(syncedMeasurement.toFirestore());
  //             print('✅ Mise à jour réussie pour ${syncedMeasurement.uuid}');
  //           } else {
  //             rethrow;
  //           }
  //         }
  //
  //         await _pendingBox!.delete(key);
  //         syncedCount++;
  //         print('🗑️ Mesure ${syncedMeasurement.uuid} supprimée du stockage local');
  //
  //       } on FirebaseException catch (e) {
  //         // Gestion des erreurs Firebase
  //         if (e.code == 'permission-denied') {
  //           print('🔒 Erreur permission pour ${measurement.uuid}: ${e.message}');
  //           await Future.delayed(const Duration(milliseconds: 100));
  //
  //           if (mounted) {
  //             ScaffoldMessenger.of(context).showSnackBar(
  //                 SnackBar(
  //                   content: Text('Permission refusée pour ${measurement.clientName}'),
  //                   backgroundColor: Colors.red,
  //                   duration: const Duration(seconds: 5),
  //                 )
  //             );
  //           }
  //         }
  //         else if (e.code == 'invalid-argument') {
  //           print('❌ Données invalides pour ${measurement.uuid}: ${e.message}');
  //         }
  //         else {
  //           print('🔥 Erreur Firebase [${e.code}]: ${e.message}');
  //           if (mounted) {
  //             ScaffoldMessenger.of(context).showSnackBar(
  //                 SnackBar(
  //                   content: Text('Erreur ${e.code}: ${e.message}'),
  //                   backgroundColor: Colors.orange,
  //                 )
  //             );
  //           }
  //         }
  //
  //         // Conserver la mesure dans Hive pour une prochaine tentative
  //         print('📦 Conservation de ${measurement.uuid} pour re-synchronisation');
  //       } catch (e) {
  //         print('❌ Erreur générale: $e');
  //         if (mounted) {
  //           ScaffoldMessenger.of(context).showSnackBar(
  //               SnackBar(
  //                 content: Text('Erreur inattendue: ${e.toString()}'),
  //                 backgroundColor: Colors.deepOrange,
  //               )
  //           );
  //         }
  //         // Conserver la mesure dans Hive
  //         print('📦 Conservation de ${measurement.uuid} pour re-synchronisation');
  //       }
  //     }
  //
  //     if (syncedCount > 0 && mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: _buildSyncedAnimation(syncedCount),
  //           backgroundColor: TColor.principal2,
  //           duration: const Duration(seconds: 3),
  //           behavior: SnackBarBehavior.floating,
  //           shape: RoundedRectangleBorder(
  //             borderRadius: BorderRadius.circular(10),
  //           ),
  //         ),
  //       );
  //     }
  //   } finally {
  //     if (mounted) {
  //       setState(() => _isSyncing = false);
  //     }
  //     print('🛑 Synchronisation terminée');
  //   }
  // }

  void _resetForm() {
    _nomCompletController.clear();

    // Dispose les anciens contrôleurs
    for (var input in _currentMeasureInputs) {
      input.controller.dispose();
    }

    _currentMeasureInputs = [
      MeasureInput(
        label: 'T',
        controller: TextEditingController(text: '0'),
      ),
    ];
    _prix = null;
    _avance = null;
  }

  @override
  void dispose() {
    // Dispose une seule fois chaque objet
    _searchNotifier.dispose();
    _syncController.close();
    _connectivitySubscription.cancel();

    // Dispose les contrôleurs de mesure
    for (var input in _currentMeasureInputs) {
      input.controller.dispose();
    }

    // Dispose les autres contrôleurs
    _nomCompletController.dispose();
    _searchController.dispose();

    super.dispose();
  }

  Future<void> _createMeasurement({
    required String clientName,
    required Map<String, dynamic> mesures,
    double? prix,
    double? avance,
  }) async {
    if (clientName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez saisir le nom du client')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Vérifier les valeurs numériques
      for (final entry in mesures.entries) {
        if (entry.value is! double) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Valeur invalide pour ${entry.key}')),
          );
          return;
        }
      }

      final user = FirebaseAuth.instance.currentUser;
      final isReallyOnline = _isOnline && user != null;

      final newMeasurement = Measurement(
        clientName: clientName.trim(),
        createdAt: DateTime.now(),
        measurements: mesures,
        price: prix,
        advance: avance,
        userId: user?.uid ?? '',
        status: isReallyOnline ? 'synced' : 'pending',
        syncedAt: isReallyOnline ? DateTime.now() : null,
        uuid: const Uuid().v4(),
        isSynced: isReallyOnline,
      );

      if (!isReallyOnline) {
        await _pendingBox?.add(newMeasurement);
      } else {
        await _firestore
            .collection('measurements')
            .doc(newMeasurement.uuid)
            .set(newMeasurement.toFirestore());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mesures enregistrées avec succès!')),
        );
      }

      // Mettre à jour l'interface
      _resetForm();
      if (mounted) setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateMontant(String id, double? prix, double? avance) async {
    try {
      await _firestore.collection('measurements').doc(id).update({
        'price': prix,
        'advance': avance,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de mise à jour: $e')),
      );
    }
  }

  // Future<void> _deleteMeasurement(String id) async {
  //   setState(() {
  //     _isDeleting = true;
  //     _deletingId = id;
  //   });
  //
  //   try {
  //     if (id.startsWith('pending_')) {
  //       final key = int.parse(id.split('_')[1]);
  //       await _pendingBox?.delete(key); // Suppression par clé Hive
  //     } else {
  //       // Supprimer de Firestore
  //       await _firestore.collection('measurements').doc(id).delete();
  //     }
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Mesure supprimée')),
  //     );
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Erreur de suppression: $e')),
  //     );
  //   } finally {
  //     if (mounted) {
  //       setState(() {
  //         _isDeleting = false;
  //         _deletingId = null;
  //       });
  //     }
  //   }
  // }

  Future<void> _deleteMeasurement(String id) async {
    if (id.startsWith('pending_')) {
      final uuid = id.replaceFirst('pending_', ''); // <-- Extraction UUID
      final key = _findHiveKeyByUuid(uuid); // <-- Nouvelle méthode helper
      if (key != null) await _pendingBox?.delete(key);
    } else {
      await _firestore.collection('measurements').doc(id).delete();
    }
  }

  // Helper pour trouver la clé Hive via UUID
  int? _findHiveKeyByUuid(String uuid) {
    for (final key in _pendingBox!.keys) {
      final m = _pendingBox!.get(key);
      if (m != null && m.uuid == uuid) return key;
    }
    return null;
  }

  void _showLabelSelector(BuildContext context, MeasureInput measureInput) async {
    List<String> tempSelectedLabels = [];
    bool isUppercase = true;

    // Crée une copie des labels disponibles pour éviter de modifier la liste originale
    List<String> workingLabels = List.from(_availableLabels);

    final selectedLabel = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sélection des mesures',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: TColor.noir,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            isUppercase ? Icons.text_fields : Icons.text_fields_outlined,
                            color: TColor.principal1,
                          ),
                          onPressed: () => setState(() => isUppercase = !isUppercase),
                          tooltip: isUppercase ? 'Passer en minuscules' : 'Passer en majuscules',
                        ),
                      ],
                    ),
                  ),

                  if (tempSelectedLabels.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: TColor.principal1Opacity,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: TColor.principal1,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: TColor.principal2, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Sélection: ${tempSelectedLabels.join(" + ")}',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: TColor.principal1,
                            ),
                          ),
                        ],
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Appuyez longuement pour changer la casse',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                  Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: workingLabels.length,
                      itemBuilder: (context, index) {
                        final label = workingLabels[index];
                        final isSelected = tempSelectedLabels.contains(label);
                        String displayLabel = label;

                        // Appliquer la casse actuelle
                        if (label.length == 1) {
                          displayLabel = isUppercase ? label.toUpperCase() : label.toLowerCase();
                        }

                        return GestureDetector(
                          key: ValueKey(label), // Clé unique
                          onLongPress: () {
                            if (label.length == 1) {
                              setState(() {
                                final newLabel = displayLabel == displayLabel.toUpperCase()
                                    ? displayLabel.toLowerCase()
                                    : displayLabel.toUpperCase();

                                // Mettre à jour la liste de travail
                                workingLabels[index] = newLabel;

                                // Mettre à jour la sélection si nécessaire
                                if (isSelected) {
                                  tempSelectedLabels[tempSelectedLabels.indexOf(label)] = newLabel;
                                }
                              });
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFEBF8FF) : const Color(0xFFF7FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? TColor.principal1 : TColor.principal1Label,
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                BoxShadow(
                                  color: TColor.principal1.withOpacity(0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ]
                                  : null,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      tempSelectedLabels.remove(label);
                                    } else if (tempSelectedLabels.length < 2) {
                                      tempSelectedLabels.add(label);
                                    }
                                  });
                                },
                                child: Center(
                                  child: Text(
                                    displayLabel,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? TColor.principal1
                                          : Colors.black38,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: TColor.principal1,
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.close, size: 18),
                            SizedBox(width: 4),
                            Text('Annuler'),
                          ],
                        ),
                      ),

                      ElevatedButton(
                        onPressed: tempSelectedLabels.isNotEmpty
                            ? () {
                          final combinedLabel = tempSelectedLabels.join();
                          Navigator.of(context).pop(combinedLabel);
                        }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TColor.principal1,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check, size: 18),
                            SizedBox(width: 6),
                            Text('Valider'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (selectedLabel != null && mounted) {
      setState(() {
        measureInput.label = selectedLabel;
      });
    }
  }

  void _showAddClientBottomSheet() {
    // Créer des contrôleurs locaux basés sur l'état actuel
    final localNomController = TextEditingController(text: _nomCompletController.text);
    final localMeasureInputs = _currentMeasureInputs.map((input) {
      return MeasureInput(
        label: input.label,
        controller: TextEditingController(text: input.controller.text),
      );
    }).toList();

    final localPrixController = TextEditingController(text: _prix?.toString() ?? '');
    final localAvanceController = TextEditingController(text: _avance?.toString() ?? '');
    final localResteController = TextEditingController();

    void updateReste() {
      final prix = double.tryParse(localPrixController.text) ?? 0;
      final avance = double.tryParse(localAvanceController.text) ?? 0;
      final reste = prix - avance;
      localResteController.text = reste.toStringAsFixed(2);
    }

    updateReste();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateLocal) {
            Widget buildMeasureInput(MeasureInput input) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _showLabelSelector(context, input),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                            decoration: BoxDecoration(
                              color: TColor.principal1Opacity,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              input.label,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: TColor.principal1,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: Colors.red),
                        onPressed: () {
                          setStateLocal(() {
                            localMeasureInputs.remove(input);
                            input.controller.dispose();
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: input.controller,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: TColor.principal1, width: 2),
                      ),
                    ),
                  ),
                ],
              );
            }

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                    left: 15,
                    right: 15,
                    top: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Nouveau client',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              // Fermer simplement le bottom sheet
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Nom complet',
                        style: TextStyle(fontSize: 16, color: Colors.black),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: localNomController,
                        decoration: InputDecoration(
                          hintText: 'Nom et prénom du client',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Mesures',
                        style: TextStyle(fontSize: 16, color: Colors.black),
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 4,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 16,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 0.8,
                        children: localMeasureInputs
                            .map((input) => buildMeasureInput(input))
                            .toList(),
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.center,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.45),
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        final user = FirebaseAuth.instance.currentUser;
                                        if (user == null) return;

                                        try {
                                          final doc = await FirebaseFirestore.instance
                                              .collection('measurement_configs')
                                              .doc(user.uid)
                                              .get();

                                          if (!doc.exists) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Aucune configuration trouvée')),
                                            );
                                            return;
                                          }

                                          final config = MeasurementConfig.fromFirestore(doc);

                                          setStateLocal(() {
                                            // Ajouter chaque mesure personnalisée
                                            for (final measure in config.measurements) {
                                              final exists = localMeasureInputs.any(
                                                      (input) => input.label == measure.name
                                              );

                                              if (!exists) {
                                                localMeasureInputs.add(MeasureInput(
                                                  label: measure.name,
                                                  controller: TextEditingController(
                                                      text: measure.defaultValue ?? '0'
                                                  ),
                                                ));
                                              }
                                            }
                                          });

                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('${config.measurements.length} mesures importées')),
                                          );
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Erreur d\'importation: $e')),
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: TColor.principal2,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: const Text(
                                        'Importer mes mesures',
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.45),
                                    child: ElevatedButton(
                                      onPressed: () {
                                        setStateLocal(() {
                                          final availableLabels = _availableLabels
                                              .where((label) => !localMeasureInputs
                                              .any((input) => input.label == label))
                                              .toList();

                                          if (availableLabels.isNotEmpty) {
                                            localMeasureInputs.add(MeasureInput(
                                              label: availableLabels.first,
                                              controller: TextEditingController(text: '0'),
                                            ));
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                  content: Text('Toutes les lettres sont utilisées')),
                                            );
                                          }
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: TColor.principal1,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: const Text(
                                        'Ajouter une mesure',
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Montants',
                        style: TextStyle(fontSize: 16, color: Colors.black),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5)),
                        color: const Color(0x17000000),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Prix",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                              SizedBox(
                                width: 100,
                                child: TextField(
                                  controller: localPrixController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: TColor.principal1,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                    hintText: '0',
                                  ),
                                  onChanged: (_) {
                                    setStateLocal(updateReste);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5)),
                        color: const Color(0x17000000),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Avance",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                              SizedBox(
                                width: 100,
                                child: TextField(
                                  controller: localAvanceController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: TColor.principal1,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                    hintText: '0',
                                  ),
                                  onChanged: (_) {
                                    setStateLocal(updateReste);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5)),
                        color: const Color(0x17000000),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Reste a payer",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                localResteController.text,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: (double.tryParse(localResteController.text) ?? 0) > 0
                                      ? Colors.red
                                      : TColor.principal2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () async {
                          // Préparer les données AVANT de fermer le bottom sheet
                          final clientName = localNomController.text;
                          final mesures = <String, dynamic>{};

                          for (final input in localMeasureInputs) {
                            final value = input.controller.text.trim();
                            final numericValue = double.tryParse(value);
                            if (numericValue != null) {
                              mesures[input.label] = numericValue;
                            }
                          }

                          final prix = double.tryParse(localPrixController.text);
                          final avance = double.tryParse(localAvanceController.text);

                          // Fermer le bottom sheet
                          Navigator.of(context).pop();

                          // NE PAS DISPOSER LES CONTRÔLEURS ICI
                          // Appeler la création directement
                          await _createMeasurement(
                              clientName: clientName,
                              mesures: mesures,
                              prix: prix,
                              avance: avance
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TColor.principal1,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Enregistrer', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showMontantBottomSheet(Measurement measurement) {
    final TextEditingController _prixController = TextEditingController(
        text: measurement.price?.toString() ?? '');
    final TextEditingController _avanceController = TextEditingController(
        text: measurement.advance?.toString() ?? '');
    final TextEditingController _resteController = TextEditingController();

    void _updateReste() {
      final prix = double.tryParse(_prixController.text) ?? 0;
      final avance = double.tryParse(_avanceController.text) ?? 0;
      final reste = prix - avance;
      _resteController.text = reste.toStringAsFixed(2);
    }

    _updateReste();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Les montants',
                        style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                    color: const Color(0x17000000),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Prix",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: _prixController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: TColor.principal1,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                hintText: '0',
                              ),
                              onChanged: (_) => setModalState(_updateReste),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                    color: const Color(0x17000000),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Avance",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: _avanceController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: TColor.principal1,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                hintText: '0',
                              ),
                              onChanged: (_) => setModalState(_updateReste),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                    color: const Color(0x17000000),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Reste a payer",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            _resteController.text,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: (double.tryParse(_resteController.text) ??
                                  0) >
                                  0
                                  ? Colors.red
                                  : TColor.principal2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      final prix = double.tryParse(_prixController.text);
                      final avance = double.tryParse(_avanceController.text);
                      _updateMontant(measurement.id!, prix, avance);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TColor.principal1,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Valider',
                        style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _normalize(String input) {
    const diacritics =
        'ÀÁÂÃÄÅàáâãäåÒÓÔÕÕÖØòóôõöøÈÉÊËèéêëðÇçÐÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž';
    const without =
        'AAAAAAaaaaaaOOOOOOOooooooEEEEeeeeeCcDIIIIiiiiUUUUuuuuNnSsYyyZz';

    return input.split('').map((char) {
      final index = diacritics.indexOf(char);
      return index != -1 ? without[index] : char;
    }).join('');
  }

  RichText _buildHighlightedText(String text, String query) {
    if (query.isEmpty) {
      return RichText(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: TColor.principal1,
          ),
        ),
      );
    }

    final normalizedText = _normalize(text.toLowerCase());
    final normalizedQuery = _normalize(query.toLowerCase());

    List<TextSpan> spans = [];
    int start = 0;

    while (start < text.length) {
      final matchIndex = normalizedText.indexOf(normalizedQuery, start);

      if (matchIndex == -1) {
        spans.add(TextSpan(
          text: text.substring(start),
          style: TextStyle(color: TColor.principal1Opacity),
        ));
        break;
      }

      if (matchIndex > start) {
        spans.add(TextSpan(
          text: text.substring(start, matchIndex),
          style: TextStyle(color: TColor.principal1Opacity),
        ));
      }

      final matchEnd = matchIndex + query.length;
      final matchedText = text.substring(
          matchIndex, matchEnd < text.length ? matchEnd : text.length);

      spans.add(TextSpan(
        text: matchedText,
        style: TextStyle(
          color: TColor.principal1,
          fontWeight: FontWeight.bold,
        ),
      ));

      start = matchEnd;
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        children: spans,
      ),
    );
  }

  Stream<List<Measurement>> _getMeasurementsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    final firestoreStream = _firestore
        .collection('measurements')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Measurement.fromFirestore(doc, null))
        .toList());

    if (!_isHiveInitialized) return firestoreStream;

    final hiveStream = Stream.value(_getPendingMeasurements());

    return Rx.combineLatest2(
      firestoreStream,
      hiveStream,
          (List<Measurement> firestore, List<Measurement> pending) {
        // Filtrer les pending déjà synchronisées
        final pendingFiltered = pending.where((p) => !p.isSynced).toList();

        final all = [...firestore, ...pendingFiltered];
        all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return all;
      },
    );

    // return Rx.combineLatest2(
    //   firestoreStream,
    //   hiveStream,
    //       (List<Measurement> firestore, List<Measurement> pending) {
    //     final all = [...firestore, ...pending];
    //     all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    //     return all;
    //   },
    // );
  }

  List<Measurement> _getPendingMeasurements() {
    if (!_isHiveInitialized || _pendingBox == null) return [];

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];

    return _pendingBox!.values
        .where((m) => m.userId == userId) // Filtre crucial
        // .map((m) => m.copyWith(id: 'pending_${m.uuid}'))
        .map((m) => m)
        .toList();
  }

  Widget _buildSyncedAnimation(int count) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Synchronisation réussie!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$count ${count == 1 ? 'mesure' : 'mesures'} synchronisée(s)',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20),
                  color: Colors.white,
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildClientItem(Measurement measurement, int index) {
    final isPending = measurement.id?.startsWith('pending_') ?? false;
    final dateFormat = DateFormat('dd/MM/yyyy');
    final formattedDate = dateFormat.format(measurement.createdAt);
    final measureKeys = measurement.measurements.keys.toList();
    final measureValues = measurement.measurements.values.toList();
    final maxDisplayed = 7;
    final hasExtraMeasures = measurement.measurements.length > maxDisplayed;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MeasurementDetailPage(
              measurement: measurement,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFEAEAEA)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // if (isPending)
                  if (measurement.status == 'pending')
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sync_disabled, size: 14, color: Colors.amber[800]),
                          const SizedBox(width: 4),
                          Text(
                            'Synchronisation en attente',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber[800],
                            ),
                          ),
                        ],
                      ),
                    ),
      
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            '#${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildHighlightedText(
                              measurement.clientName, _searchController.text),
                        ],
                      ),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (measurement.measurements.isNotEmpty)
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1.0),
                        1: FlexColumnWidth(1.0),
                        2: FlexColumnWidth(1.0),
                        3: FlexColumnWidth(1.0),
                        4: FlexColumnWidth(1.0),
                        5: FlexColumnWidth(1.0),
                        6: FlexColumnWidth(1.0),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9F9F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          children: measureKeys
                              .take(maxDisplayed)
                              .map((label) => Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 4),
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4A5568),
                              ),
                            ),
                          ))
                              .toList(),
                        ),
                        TableRow(
                          children: measureValues
                              .take(maxDisplayed)
                              .map((value) => Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 4),
                            child: Text(
                              value.toString(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: TColor.principal1TableRow,
                              ),
                            ),
                          ))
                              .toList(),
                        ),
                      ],
                    ),
                  if (hasExtraMeasures)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: TColor.principal1Opacity,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '+${measurement.measurements.length - maxDisplayed} mesures',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: TColor.principal1,
                          ),
                        ),
                      ),
                    ),
                  // const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => _showMontantBottomSheet(measurement),
                        child: Text(
                          measurement.price != null
                              ? 'Montant: ${measurement.price} (Avance: ${measurement.advance ?? 0})'
                              : 'Ajouter montant',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (_isDeleting && _deletingId == measurement.id)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.delete_forever, size: 22),
                          color: Colors.red[400],
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Confirmer la suppression'),
                                content: Text(
                                    'Voulez-vous vraiment supprimer "${measurement.clientName}" ?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Annuler'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _deleteMeasurement(measurement.id!);
                                    },
                                    child: const Text('Supprimer',
                                        style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // if (isPending)
            if (measurement.status == 'pending')
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning, size: 16, color: Colors.white),
                ),
              ),
            // if (measurement.isSyncing)
            //   Positioned.fill(
            //     child: Container(
            //       color: Colors.black54,
            //       child: Center(
            //         child: Container(
            //           padding: const EdgeInsets.all(20),
            //           decoration: BoxDecoration(
            //             color: Colors.white,
            //             borderRadius: BorderRadius.circular(10),
            //           ),
            //           child: const Column(
            //             mainAxisSize: MainAxisSize.min,
            //             children: [
            //               CircularProgressIndicator(),
            //               SizedBox(height: 10),
            //               Text('Synchronisation...'),
            //             ],
            //           ),
            //         ),
            //       ),
            //     ),
            //   ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // floatingActionButton: FloatingActionButton(
      //   backgroundColor: const Color(0xFF63519F),
      //   onPressed: _showAddClientBottomSheet,
      //   child: const Icon(Icons.add, color: Colors.white, size: 28),
      // ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (!_isOnline && (_pendingBox?.isNotEmpty ?? false))
            FloatingActionButton(
              heroTag: 'syncBtn',
              backgroundColor: Colors.orange,
              onPressed: _syncPendingMeasurements,
              child: const Icon(Icons.sync),
            ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'addBtn',
            backgroundColor: TColor.principal1,
            onPressed: _showAddClientBottomSheet,
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Align(
                alignment: Alignment.center,
                child: Text(
                  'Mesures des clients',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ValueListenableBuilder<String>(
                  valueListenable: _searchNotifier,
                  builder: (context, value, child) {
                    return TextField(
                      controller: _searchController,
                      onChanged: (v) => _searchNotifier.value = v,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Rechercher un client...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),

              if (!_isOnline)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.amber[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off, color: Colors.amber[800]),
                      const SizedBox(width: 10),
                      Text(
                        'Mode hors ligne - Les données seront \nsynchronisées une fois que vous \nêtre connecter',
                        style: TextStyle(color: Colors.amber[800]),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              Expanded(
                child: !_isHiveInitialized
                    ? const Center(child: CircularProgressIndicator())
                    : StreamBuilder<List<Measurement>>(
                  stream: _getMeasurementsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Erreur de chargement\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.people_alt_outlined,
                                size: 60, color: Colors.grey),
                            const SizedBox(height: 20),
                            const Text(
                              'Aucun client enregistré',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Appuyez sur le bouton + pour ajouter un nouveau client',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final measurements = snapshot.data!;
                    final query = _searchController.text.toLowerCase();
                    final filteredMeasurements = query.isEmpty
                        ? measurements
                        : measurements.where((m) {
                      return _normalize(m.clientName)
                          .toLowerCase()
                          .contains(_normalize(query));
                    }).toList();

                    if (filteredMeasurements.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off,
                                size: 60, color: Colors.grey),
                            const SizedBox(height: 20),
                            Text(
                              'Aucun résultat pour "$query"',
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Vérifiez l\'orthographe ou essayez un autre terme',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: filteredMeasurements.length,
                      itemBuilder: (context, index) {
                        return _buildClientItem(
                            filteredMeasurements[index], index);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class MeasureInput {
  String label;
  TextEditingController controller;

  MeasureInput({required this.label, required this.controller});
}