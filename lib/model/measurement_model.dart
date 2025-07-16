import 'package:cloud_firestore/cloud_firestore.dart';

class Measurement {
  final String? id;                // ID du document Firestore
  final String clientName;
  final DateTime createdAt;
  final String garmentImageUrl;
  final Map<String, dynamic> measurements;
  final String modeImageUrl;
  final String phoneNumber;
  final double? price;
  final double? advance;
  final String userId;

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
  });

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
    );
  }
}
