import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreInitializer {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Crée un utilisateur dans Firestore s'il n'existe pas
  Future<void> createUserIfNotExists() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        final userData = {
          'email': user.email,
          'createdAt': Timestamp.fromDate(DateTime.now()),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        };
        await _firestore.collection('users').doc(user.uid).set(userData);
        print('Utilisateur créé dans Firestore');
      }
    } catch (e) {
      print('Erreur lors de la création de l\'utilisateur: $e');
    }
  }

  /// Vérifie si l'utilisateur actuel existe dans Firestore
  Future<bool> checkUserExists() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      return doc.exists;
    } catch (e) {
      print('Erreur lors de la vérification de l\'utilisateur: $e');
      return false;
    }
  }
} 