import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'measurement_model.g.dart';

@HiveType(typeId: 0)
class Measurement {
  @HiveField(0)
  final String? id;                // ID du document Firestore

  @HiveField(1)
  final String clientName;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  final String garmentImageUrl;

  @HiveField(4)
  final Map<String, dynamic> measurements;

  @HiveField(5)
  final String modeImageUrl;

  @HiveField(6)
  final String phoneNumber;

  @HiveField(7)
  final double? price;

  @HiveField(8)
  final double? advance;

  @HiveField(9)
  final String userId;

  @HiveField(10)
  final String status; // 'synced' ou 'pending'

  @HiveField(11)
  final DateTime? syncedAt;

  @HiveField(12)
  final String uuid;

  @HiveField(13)
  final String? configId;

  Measurement({
    this.id,
    required this.clientName,
    required this.createdAt,
    this.garmentImageUrl = "",
    required this.measurements,
    this.modeImageUrl = "",
    this.phoneNumber = "",
    this.price = 0.0,
    this.advance = 0.0,
    required this.userId,
    this.status = 'synced',
    this.syncedAt,
    required this.uuid,
    this.configId,
  });

  static String _generateSyncHash() {
    return '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1000)}';
  }

  /// Convertit un document Firestore en objet Measurement
  factory Measurement.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      SnapshotOptions? options,
      ) {
    final data = snapshot.data()!;
    // Récupération et conversion sécurisée des doubles
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return Measurement(
      id: snapshot.id,
      clientName: data['clientName'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      garmentImageUrl: data['garmentImageUrl'] as String? ?? "",
      measurements: Map<String, dynamic>.from(data['mesure'] as Map),
      modeImageUrl: data['modeImageUrl'] as String? ?? "",
      phoneNumber: data['phoneNumber'] as String? ?? "",
      price: parseDouble(data['price']),
      advance: parseDouble(data['advance']),
      userId: data['userId'] as String? ?? "",
      status: data['status'] as String? ?? 'synced',
      syncedAt: data['syncedAt'] != null
          ? (data['syncedAt'] as Timestamp).toDate()
          : null,
      uuid: data['uuid'] as String? ?? const Uuid().v4(),
      configId: data['configId'] as String? ?? "",
    );
  }

  /// Convertit l'objet en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'clientName': clientName,
      'createdAt': Timestamp.fromDate(createdAt),
      'garmentImageUrl': garmentImageUrl,
      'mesure': measurements,
      'modeImageUrl': modeImageUrl,
      'phoneNumber': phoneNumber,
      'price': price,
      'advance': advance,
      'userId': userId,
      'status': status,
      'syncedAt': syncedAt != null ? Timestamp.fromDate(syncedAt!) : null,
      'uuid': uuid,
      'configId': configId,
    };
  }

  /// Copie l'objet avec des valeurs modifiées
  Measurement copyWith({
    String? id,
    String? clientName,
    DateTime? createdAt,
    String? garmentImageUrl,
    Map<String, dynamic>? measurements,
    String? modeImageUrl,
    String? phoneNumber,
    double? price,
    double? advance,
    String? userId,
    String? status,
    DateTime? syncedAt,
    String? uuid,
    String? configId,
  }) {
    return Measurement(
      id: id ?? this.id,
      clientName: clientName ?? this.clientName,
      createdAt: createdAt ?? this.createdAt,
      garmentImageUrl: garmentImageUrl ?? this.garmentImageUrl,
      measurements: measurements ?? this.measurements,
      modeImageUrl: modeImageUrl ?? this.modeImageUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      price: price ?? this.price,
      advance: advance ?? this.advance,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      syncedAt: syncedAt ?? this.syncedAt,
      uuid: uuid ?? this.uuid,
      configId: configId ?? this.configId,
    );
  }
}
