import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'measurement_config.g.dart';

@HiveType(typeId: 1)
class MeasurementConfig {
  @HiveField(0)
  final String userId;

  @HiveField(1)
  final List<CustomMeasurement> measurements;

  @HiveField(2)
  final DateTime updatedAt;

  MeasurementConfig({
    required this.userId,
    required this.measurements,
    required this.updatedAt,
  });

  // Méthode copyWith ajoutée ici
  MeasurementConfig copyWith({
    String? userId,
    List<CustomMeasurement>? measurements,
    DateTime? updatedAt,
  }) {
    return MeasurementConfig(
      userId: userId ?? this.userId,
      measurements: measurements ?? this.measurements,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory MeasurementConfig.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MeasurementConfig(
      userId: data['userId'],
      measurements: (data['measurements'] as List)
          .map((e) => CustomMeasurement.fromMap(e))
          .toList(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'measurements': measurements.map((m) => m.toMap()).toList(),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

@HiveType(typeId: 2)
class CustomMeasurement {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String unit;

  @HiveField(3)
  final String? defaultValue;

  CustomMeasurement({
    required this.id,
    required this.name,
    this.unit = "cm",
    this.defaultValue,
  });

  factory CustomMeasurement.fromMap(Map<String, dynamic> map) {
    return CustomMeasurement(
      id: map['id'],
      name: map['name'],
      unit: map['unit'] ?? "cm",
      defaultValue: map['defaultValue'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
      'defaultValue': defaultValue,
    };
  }

  // Optionnel: Ajoutez aussi copyWith pour CustomMeasurement si besoin
  CustomMeasurement copyWith({
    String? id,
    String? name,
    String? unit,
    String? defaultValue,
  }) {
    return CustomMeasurement(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      defaultValue: defaultValue ?? this.defaultValue,
    );
  }
}