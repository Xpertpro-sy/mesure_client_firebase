import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../model/measurement_model.dart';

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
  final List<String> _availableLabels = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'
  ];
  List<MeasureInput> _currentMeasureInputs = [];
  bool _isLoading = false;
  bool _isDeleting = false;
  String? _deletingId;

  @override
  void initState() {
    super.initState();
    _resetForm();
    _searchController.addListener(() {
      _searchNotifier.value = _searchController.text;
    });
  }

  void _resetForm() {
    _nomCompletController.clear();
    for (var input in _currentMeasureInputs) {
      input.controller.dispose();
    }
    _currentMeasureInputs = [
      MeasureInput(
        label: 'T',
        controller: TextEditingController(text: '0'),
      ),
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nomCompletController.dispose();
    _searchNotifier.dispose();
    for (var input in _currentMeasureInputs) {
      input.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _createMeasurement() async {
    if (_nomCompletController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir le nom du client')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final mesures = <String, dynamic>{};
      for (final input in _currentMeasureInputs) {
        final value = input.controller.text.trim();
        final numericValue = double.tryParse(value);
        if (numericValue == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Valeur invalide pour ${input.label}')),
          );
          return;
        }
        mesures[input.label] = numericValue;
      }

      final newMeasurement = Measurement(
        clientName: _nomCompletController.text.trim(),
        createdAt: DateTime.now(),
        measurements: mesures,
      );

      await _firestore.collection('measurements').add(newMeasurement.toFirestore());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesures enregistrées avec succès!')),
      );
      if (mounted) Navigator.pop(context);
      _resetForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteMeasurement(String id) async {
    setState(() {
      _isDeleting = true;
      _deletingId = id;
    });

    try {
      await _firestore.collection('measurements').doc(id).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesure supprimée')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de suppression: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _deletingId = null;
        });
      }
    }
  }

  void _showLabelSelector(BuildContext context, MeasureInput measureInput) async {
    List<String> tempSelectedLabels = [];
    bool isUppercase = true;

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
                        const Text(
                          'Sélection des mesures',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                              isUppercase
                                  ? Icons.text_fields
                                  : Icons.text_fields_outlined,
                              color: const Color(0xFF63519F)),
                          onPressed: () => setState(() => isUppercase = !isUppercase),
                          tooltip: isUppercase
                              ? 'Passer en minuscules'
                              : 'Passer en majuscules',
                        ),
                      ],
                    ),
                  ),

                  if (tempSelectedLabels.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0x2463519E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF63519F),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Color(0xFF48BB78), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Sélection: ${tempSelectedLabels.join(" + ")}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF2D3748),
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
                      itemCount: _availableLabels.length,
                      itemBuilder: (context, index) {
                        final label = _availableLabels[index];
                        final isSelected = tempSelectedLabels.contains(label);
                        String displayLabel = label;
                        if (label.length == 1) {
                          displayLabel = isUppercase ? label.toUpperCase() : label.toLowerCase();
                        } else {
                          displayLabel = label;
                        }

                        return GestureDetector(
                          onLongPress: () {
                            if (label.length == 1) {
                              setState(() {
                                final newLabel = label == label.toUpperCase()
                                    ? label.toLowerCase()
                                    : label.toUpperCase();
                                final newIndex = _availableLabels.indexOf(label);
                                if (newIndex != -1) {
                                  _availableLabels[newIndex] = newLabel;
                                }
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
                                color: isSelected ? const Color(0xFF63519F) : const Color(0x2463519E),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                BoxShadow(
                                  color: const Color(0x2463519E).withOpacity(0.2),
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
                                          ? const Color(0xFF2B6CB0)
                                          : const Color(0xFF4A5568),
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
                          foregroundColor: const Color(0xFF718096),
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
                          Navigator.pop(context, combinedLabel);
                        }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF63519F),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
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
                      InkWell(
                        onTap: () => _showLabelSelector(context, input),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 2, horizontal: 8),
                          decoration: BoxDecoration(
                            color: const Color(0x2463519E),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            input.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            size: 20, color: Colors.red),
                        onPressed: () {
                          setStateLocal(() {
                            _currentMeasureInputs.remove(input);
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
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
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
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
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
                        controller: _nomCompletController,
                        decoration: InputDecoration(
                          hintText: 'Nom et prénom du client',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
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
                        childAspectRatio: 0.9,
                        children: _currentMeasureInputs
                            .map((input) => buildMeasureInput(input))
                            .toList(),
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: () {
                            setStateLocal(() {
                              final availableLabels = _availableLabels
                                  .where((label) => !_currentMeasureInputs
                                  .any((input) => input.label == label))
                                  .toList();

                              if (availableLabels.isNotEmpty) {
                                _currentMeasureInputs.add(MeasureInput(
                                  label: availableLabels.first,
                                  controller: TextEditingController(text: '0'),
                                ));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                      Text('Toutes les lettres sont utilisées')),
                                );
                              }
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF63519F),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Ajouter une mesure'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _createMeasurement,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF63519F),
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

  Stream<List<Measurement>> _getMeasurementsStream() {
    return _firestore
        .collection('measurements')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Measurement.fromFirestore(doc, null))
        .toList());
  }

  Widget _buildClientItem(Measurement measurement) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final formattedDate = dateFormat.format(measurement.createdAt);

    final measureKeys = measurement.measurements.keys.toList();
    final measureValues = measurement.measurements.values.toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#${measurement.id?.substring(0, 6) ?? 'N/A'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  formattedDate,
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              measurement.clientName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 16),
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
                        .take(7)
                        .map((label) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
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
                        .take(7)
                        .map((value) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      child: Text(
                        value.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF2D3748),
                        ),
                      ),
                    ))
                        .toList(),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Montant: - • Avance: -',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
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
                    icon: const Icon(Icons.delete_outline, size: 22),
                    color: Colors.red[400],
                    onPressed: () => _deleteMeasurement(measurement.id!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF63519F),
        onPressed: _showAddClientBottomSheet,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mesures clients',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Color(0xFFA0AEC0)),
                    hintText: 'Rechercher un client...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: StreamBuilder<List<Measurement>>(
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
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.map, size: 64, color: Color(0xFFCBD5E0)),
                            SizedBox(height: 16),
                            Text(
                              'Aucune mesure enregistrée',
                              style: TextStyle(
                                fontSize: 18,
                                color: Color(0xFF718096),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Commencez par ajouter un client',
                              style: TextStyle(color: Color(0xFFA0AEC0)),
                            ),
                          ],
                        ),
                      );
                    }

                    final measurements = snapshot.data!;

                    return ListView.separated(
                      itemCount: measurements.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        return _buildClientItem(measurements[index]);
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