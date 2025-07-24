import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../common/color_extention.dart';
import '../model/build-model-screen.dart';
import '../model/measurement_model.dart';

class MeasurementDetailPage extends StatefulWidget {
  final Measurement measurement;

  const MeasurementDetailPage({super.key, required this.measurement});

  @override
  State<MeasurementDetailPage> createState() => _MeasurementDetailPageState();
}

class _MeasurementDetailPageState extends State<MeasurementDetailPage> {
  int _currentIndex = 0;
  late Measurement _currentMeasurement;
  bool _isOnline = true;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  Box<Measurement>? _pendingBox;

  @override
  void initState() {
    super.initState();
    _currentMeasurement = widget.measurement;
    _initConnectivity();
    _initHive();
  }

  Future<void> _initHive() async {
    try {
      _pendingBox = await Hive.openBox<Measurement>('pending_measurements');
    } catch (e) {
      print("Erreur d'initialisation Hive: $e");
    }
  }

  Future<void> _initConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() => _isOnline = result != ConnectivityResult.none);

    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      setState(() {
        _isOnline = results.any(
              (result) => result != ConnectivityResult.none,
        );
      });
    });
  }

  Future<void> _saveOrUpdateInPendingBox(Measurement measurement) async {
    if (_pendingBox == null) return;

    final existingKeys = _pendingBox!.keys.toList();
    int? existingKey;

    for (final key in existingKeys) {
      final m = _pendingBox!.get(key);
      if (m != null && m.uuid == measurement.uuid) {
        existingKey = key;
        break;
      }
    }

    if (existingKey != null) {
      await _pendingBox!.put(existingKey, measurement);
    } else {
      await _pendingBox!.add(measurement);
    }
  }

  Future<void> _updateMeasurementInFirestore(Measurement measurement) async {
    try {
      await FirebaseFirestore.instance
          .collection('measurements')
          .doc(measurement.uuid)
          .update(measurement.toFirestore());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesure mise à jour avec succès!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de mise à jour: $e')),
      );
    }
  }

  void _saveChanges(String newName, Map<String, String> updatedMeasures) {
    final newMeasures = <String, dynamic>{};
    updatedMeasures.forEach((key, value) {
      newMeasures[key] = double.tryParse(value) ?? 0.0;
    });

    final updatedMeasurement = _currentMeasurement.copyWith(
      clientName: newName,
      measurements: newMeasures,
    );

    setState(() => _currentMeasurement = updatedMeasurement);

    if (_currentMeasurement.status == 'synced') {
      if (_isOnline) {
        _updateMeasurementInFirestore(updatedMeasurement);
      } else {
        _saveOrUpdateInPendingBox(updatedMeasurement.copyWith(status: 'pending'));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Modifications enregistrées localement. Synchronisation à venir.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else if (_currentMeasurement.status == 'pending') {
      _saveOrUpdateInPendingBox(updatedMeasurement);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesure mise à jour dans les modifications en attente')),
      );
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentMeasurement.clientName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, size: 26),
            onPressed: () => _showEditDialog(context),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _buildCurrentScreen(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            elevation: 15,
            backgroundColor: Theme.of(context).colorScheme.surface,
            selectedItemColor: TColor.principal1,
            unselectedItemColor: Colors.grey[600],
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(Icons.description_outlined),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(Icons.description),
                ),
                label: 'Détails',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(Icons.dashboard_customize_outlined),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(Icons.dashboard_customize),
                ),
                label: 'Modèle',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return _buildDetailsScreen();
      case 1:
        return _buildInvoiceScreen();
      default:
        return _buildDetailsScreen();
    }
  }

  Widget _buildDetailsScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusIndicator(),
          const SizedBox(height: 20),
          _buildMesuresSection(),
          const SizedBox(height: 25),
          _buildMontantSection(),
          const SizedBox(height: 25),
          _buildInfoSection()
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    if (_currentMeasurement.status == 'pending') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.amber[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber),
        ),
        child: Row(
          children: [
            Icon(Icons.sync_problem, color: Colors.amber[800]),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'En attente de synchronisation',
                style: TextStyle(
                  color: Colors.amber[800],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildInfoSection() {
    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm');
    final formattedDate = dateFormat.format(_currentMeasurement.createdAt);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline,
                    size: 24, color: TColor.principal1),
                const SizedBox(width: 12),
                Text(
                  'Informations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: TColor.principal1Label,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 18),
            _buildInfoRow('Nom complet', _currentMeasurement.clientName, Icons.person),
            const SizedBox(height: 16),
            _buildInfoRow('Date d\'enregistrement', formattedDate, Icons.calendar_today),
            const SizedBox(height: 16),
            _buildInfoRow('Statut', _currentMeasurement.status == 'synced' ? 'Synchronisé' : 'En attente', Icons.sync),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String title, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: Colors.grey[600]),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMesuresSection() {
    final measurements = _currentMeasurement.measurements;
    final measureKeys = measurements.keys.toList();
    final measureValues = measurements.values.toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.straighten_outlined,
                    size: 24, color: TColor.principal1),
                const SizedBox(width: 12),
                Text(
                  'Mesures',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: TColor.principal1Label,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 18),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 5,
              childAspectRatio: 1.0,
              crossAxisSpacing: 10,
              mainAxisSpacing: 15,
              children: List.generate(measurements.length, (index) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: TColor.principal1.withOpacity(0.08),
                    border: Border.all(
                      color: TColor.principal1.withOpacity(0.4),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        measureKeys[index],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: TColor.noir,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        measureValues[index].toString(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: TColor.principal1,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMontantSection() {
    final prix = _currentMeasurement.price ?? 0;
    final avance = _currentMeasurement.advance ?? 0;
    final reste = prix - avance;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.attach_money_outlined,
                    size: 24, color: TColor.principal1),
                const SizedBox(width: 12),
                Text(
                  'Transactions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: TColor.principal1Label,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 18),
            _buildMontantItem('Prix total', prix.toStringAsFixed(2), false),
            _buildMontantItem('Avance', avance.toStringAsFixed(2), false),
            _buildMontantItem(
              'Reste à payer',
              reste.toStringAsFixed(2),
              true,
              color: reste > 0 ? Colors.red[700] : TColor.principal2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMontantItem(String label, String value, bool isHighlighted, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
              color: isHighlighted ? color : TColor.noir,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
            decoration: BoxDecoration(
              color: isHighlighted ? color?.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isHighlighted
                  ? Border.all(color: color!.withOpacity(0.3))
                  : null,
            ),
            child: Text(
              '$value CFA',
              style: TextStyle(
                fontSize: isHighlighted ? 13 : 12,
                fontWeight: isHighlighted ? FontWeight.w800 : FontWeight.w700,
                color: isHighlighted ? color : TColor.principal1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceScreen() {
    // Implémentation le model
    return BuildModelScreen();
    // return Center(
    //   child: Text(
    //     'Modèle pour le client ${_currentMeasurement.clientName}',
    //     style: const TextStyle(fontSize: 18),
    //   ),
    // );
  }

  void _showEditDialog(BuildContext context) {
    final TextEditingController nameController =
    TextEditingController(text: _currentMeasurement.clientName);

    final Map<String, TextEditingController> measureControllers = {};
    for (var entry in _currentMeasurement.measurements.entries) {
      measureControllers[entry.key] =
          TextEditingController(text: entry.value.toString());
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _EditMeasurementForm(
          nameController: nameController,
          measureControllers: measureControllers,
          onSave: (newName, updatedMeasures) {
            _saveChanges(newName, updatedMeasures);
            Navigator.pop(context);
          },
        );
      },
    );
  }
}

class _EditMeasurementForm extends StatefulWidget {
  final TextEditingController nameController;
  final Map<String, TextEditingController> measureControllers;
  final Function(String, Map<String, String>) onSave;

  const _EditMeasurementForm({
    required this.nameController,
    required this.measureControllers,
    required this.onSave,
  });

  @override
  State<_EditMeasurementForm> createState() => __EditMeasurementFormState();
}

class __EditMeasurementFormState extends State<_EditMeasurementForm> {
  final List<String> _availableLabels = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'
  ];

  void _addNewMeasure() {
    final available = _availableLabels.firstWhere(
          (label) => !widget.measureControllers.containsKey(label),
      orElse: () => '',
    );

    if (available.isNotEmpty) {
      setState(() {
        widget.measureControllers[available] = TextEditingController(text: '0');
      });
    }
  }

  void _removeMeasure(String label) {
    setState(() {
      widget.measureControllers[label]?.dispose();
      widget.measureControllers.remove(label);
    });
  }

  void _updateMeasureLabel(String oldLabel, String newLabel) {
    if (widget.measureControllers.containsKey(oldLabel)) {
      final controller = widget.measureControllers[oldLabel]!;
      setState(() {
        widget.measureControllers.remove(oldLabel);
        widget.measureControllers[newLabel] = controller;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Modifier la mesure',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: widget.nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom complet',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (var entry in widget.measureControllers.entries)
                      _MeasureRow(
                        label: entry.key,
                        controller: entry.value,
                        availableLabels: _availableLabels,
                        onLabelChanged: (newLabel) =>
                            _updateMeasureLabel(entry.key, newLabel),
                        onRemove: () => _removeMeasure(entry.key),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _addNewMeasure,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter une mesure'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final updatedMeasures = <String, String>{};
                  for (var entry in widget.measureControllers.entries) {
                    updatedMeasures[entry.key] = entry.value.text;
                  }

                  widget.onSave(
                      widget.nameController.text.trim(),
                      updatedMeasures
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: TColor.principal1,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Enregistrer les modifications',
                    style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeasureRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final List<String> availableLabels;
  final Function(String) onLabelChanged;
  final VoidCallback onRemove;

  const _MeasureRow({
    required this.label,
    required this.controller,
    required this.availableLabels,
    required this.onLabelChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          _LabelSelector(
            currentLabel: label,
            availableLabels: availableLabels,
            onLabelChanged: onLabelChanged,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _LabelSelector extends StatelessWidget {
  final String currentLabel;
  final List<String> availableLabels;
  final Function(String) onLabelChanged;

  const _LabelSelector({
    required this.currentLabel,
    required this.availableLabels,
    required this.onLabelChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showLabelSelector(context),
      child: Container(
        width: 50,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: TColor.principal1.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: TColor.principal1),
        ),
        child: Text(
          currentLabel,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: TColor.principal1,
          ),
        ),
      ),
    );
  }

  void _showLabelSelector(BuildContext context) async {
    List<String> tempSelectedLabels = [currentLabel];
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
                            color: TColor.principal1,
                          ),
                          onPressed: () {
                            setState(() => isUppercase = !isUppercase);
                          },
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
                          vertical: 8,
                          horizontal: 12
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEBF8FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: TColor.principal1,
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
                      itemCount: availableLabels.length,
                      itemBuilder: (context, index) {
                        final label = availableLabels[index];
                        final isSelected = tempSelectedLabels.contains(label);
                        String displayLabel = label;

                        if (label.length == 1) {
                          displayLabel = isUppercase ? label.toUpperCase() : label.toLowerCase();
                        }

                        return GestureDetector(
                          onLongPress: () {
                            setState(() {
                              if (label.length == 1) {
                                final newLabel = displayLabel == displayLabel.toUpperCase()
                                    ? displayLabel.toLowerCase()
                                    : displayLabel.toUpperCase();

                                // Mettre à jour dans la sélection
                                if (isSelected) {
                                  final indexInSelection = tempSelectedLabels.indexOf(label);
                                  if (indexInSelection != -1) {
                                    tempSelectedLabels[indexInSelection] = newLabel;
                                  }
                                }
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFEBF8FF) : const Color(0xFFF7FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? TColor.principal1 : const Color(0x2463519E),
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
                          Navigator.pop(context, combinedLabel);
                        }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TColor.principal1,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12
                          ),
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

    if (selectedLabel != null) {
      onLabelChanged(selectedLabel);
    }
  }
}