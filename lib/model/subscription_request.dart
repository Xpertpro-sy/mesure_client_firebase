import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'subscription_request.g.dart'; // Exécutez la commande build_runner pour générer ce fichier

@HiveType(typeId: 4)
class SubscriptionRequest {
  @HiveField(0)
  final String userId;
  @HiveField(1)
  final String email;
  @HiveField(2)
  final String? phoneNumber;
  @HiveField(3)
  final int amount;
  @HiveField(4)
  final String transactionId;
  @HiveField(5)
  final String subscriptionType;
  @HiveField(6)
  final DateTime submittedAt;
  @HiveField(7)
  final String status; // 'pending', 'approved', 'rejected'
  @HiveField(8)
  final String? adminComment;

  SubscriptionRequest({
    required this.userId,
    required this.email,
    this.phoneNumber,
    required this.amount,
    required this.transactionId,
    required this.subscriptionType,
    required this.submittedAt,
    required this.status,
    this.adminComment,
  });

  factory SubscriptionRequest.fromMap(Map<String, dynamic> map) {
    return SubscriptionRequest(
      userId: map['userId'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'],
      amount: map['amount'] ?? 0,
      transactionId: map['transactionId'] ?? '',
      subscriptionType: map['subscriptionType'] ?? '',
      submittedAt: (map['submittedAt'] is Timestamp)
          ? (map['submittedAt'] as Timestamp).toDate()
          : DateTime.now(),
      status: map['status'] ?? 'pending',
      adminComment: map['adminComment'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'email': email,
      'phoneNumber': phoneNumber,
      'amount': amount,
      'transactionId': transactionId,
      'subscriptionType': subscriptionType,
      'submittedAt': submittedAt,
      'status': status,
      'adminComment': adminComment,
    };
  }
} 