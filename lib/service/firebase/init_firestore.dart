import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../model/user_model.dart';

class FirestoreInitializer {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Initialise Firestore et crée la collection users si nécessaire
  Future<void> initializeFirestore() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('Aucun utilisateur connecté');
        return;
      }

      // Vérifier si la collection users existe
      final usersCollection = _firestore.collection('users');
      
      // Essayer de créer un document temporaire pour tester
      try {
        await usersCollection.doc('temp_check').get();
        print('Collection users existe déjà');
      } catch (e) {
        print('Collection users n\'existe pas, création...');
        await _createUsersCollection();
      }

      // Supprimer le document temporaire
      try {
        await usersCollection.doc('temp_check').delete();
      } catch (e) {
        // Ignorer l'erreur si le document n'existe pas
      }

    } catch (e) {
      print('Erreur lors de l\'initialisation de Firestore: $e');
    }
  }

  /// Crée la collection users avec un document d'exemple
  Future<void> _createUsersCollection() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Créer un document utilisateur d'exemple
      final userData = {
        'email': user.email,
        'firstName': null,
        'lastName': null,
        'phoneNumber': null,
        'profileImageUrl': null,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      await _firestore.collection('users').doc(user.uid).set(userData);
      print('Collection users créée avec succès');
    } catch (e) {
      print('Erreur lors de la création de la collection users: $e');
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

  /// Crée un utilisateur dans Firestore s'il n'existe pas
  Future<void> createUserIfNotExists() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final exists = await checkUserExists();
      if (!exists) {
        final userData = {
          'email': user.email,
          'firstName': null,
          'lastName': null,
          'phoneNumber': null,
          'profileImageUrl': null,
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
} 