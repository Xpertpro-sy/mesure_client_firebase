import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'user_model.g.dart';

@HiveType(typeId: 10)
class UserModel {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String email;
  @HiveField(2)
  final String? firstName;
  @HiveField(3)
  final String? lastName;
  @HiveField(4)
  final String? phoneNumber;
  @HiveField(5)
  final String? profileImageUrl;
  @HiveField(6)
  final DateTime createdAt;
  @HiveField(7)
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.phoneNumber,
    this.profileImageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convertit un document Firestore en objet UserModel
  factory UserModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data()!;
    
    return UserModel(
      id: snapshot.id,
      email: data['email'] as String,
      firstName: data['firstName'] as String?,
      lastName: data['lastName'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      profileImageUrl: data['profileImageUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Convertit l'objet en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Copie l'objet avec des valeurs modifiées
  UserModel copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? profileImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Nom complet de l'utilisateur
  String get fullName {
    final firstName = this.firstName?.trim() ?? '';
    final lastName = this.lastName?.trim() ?? '';
    
    if (firstName.isNotEmpty || lastName.isNotEmpty) {
      return [firstName, lastName].where((name) => name.isNotEmpty).join(' ');
    }
    
    // Si aucun nom n'est défini, utiliser la partie locale de l'email
    return email.split('@')[0];
  }

  /// Vérifie si l'utilisateur a un profil complet
  bool get hasCompleteProfile {
    return firstName?.isNotEmpty == true && 
           lastName?.isNotEmpty == true && 
           phoneNumber?.isNotEmpty == true;
  }
} 