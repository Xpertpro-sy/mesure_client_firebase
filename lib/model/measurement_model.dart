

import 'package:cloud_firestore/cloud_firestore.dart';

class Measurement {
  final String? id; // ID du document Firestore
  final String clientName;
  final DateTime createdAt;
  final String garmentImageUrl;
  final Map<String, dynamic> measurements;
  final String modeImageUrl;
  final String phoneNumber;

  Measurement({
    this.id,
    required this.clientName,
    required this.createdAt,
    this.garmentImageUrl = "",
    required this.measurements,
    this.modeImageUrl = "",
    this.phoneNumber = "",
  });

  // Convertir un document Firestore en objet Measurement
  factory Measurement.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      SnapshotOptions? options,
      ) {
    final data = snapshot.data()!;
    return Measurement(
      id: snapshot.id,
      clientName: data['clientName'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      garmentImageUrl: data['garmentImageUrl'] as String? ?? "",
      measurements: Map<String, dynamic>.from(data['mesure']),
      modeImageUrl: data['modeImageUrl'] as String? ?? "",
      phoneNumber: data['phoneNumber'] as String? ?? "",
    );
  }

  // Convertir l'objet en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'clientName': clientName,
      'createdAt': Timestamp.fromDate(createdAt),
      'garmentImageUrl': garmentImageUrl,
      'mesure': measurements,
      'modeImageUrl': modeImageUrl,
      'phoneNumber': phoneNumber,
    };
  }

  // Copier l'objet avec des valeurs modifiées (pattern builder)
  Measurement copyWith({
    String? id,
    String? clientName,
    DateTime? createdAt,
    String? garmentImageUrl,
    Map<String, dynamic>? measurements,
    String? modeImageUrl,
    String? phoneNumber,
  }) {
    return Measurement(
      id: id ?? this.id,
      clientName: clientName ?? this.clientName,
      createdAt: createdAt ?? this.createdAt,
      garmentImageUrl: garmentImageUrl ?? this.garmentImageUrl,
      measurements: measurements ?? this.measurements,
      modeImageUrl: modeImageUrl ?? this.modeImageUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}