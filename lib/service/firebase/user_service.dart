import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../model/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Collection des utilisateurs
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  /// Récupère l'utilisateur actuel depuis Firestore
  Future<UserModel?> getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _usersCollection.doc(user.uid).get();
      if (!doc.exists) return null;

      return UserModel.fromFirestore(doc, null);
    } catch (e) {
      print('Erreur lors de la récupération de l\'utilisateur: $e');
      return null;
    }
  }

  /// Crée ou met à jour un utilisateur
  Future<UserModel?> createOrUpdateUser({
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? profileImageUrl,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final now = DateTime.now();
      final userData = {
        'email': user.email,
        'firstName': firstName,
        'lastName': lastName,
        'phoneNumber': phoneNumber,
        'profileImageUrl': profileImageUrl,
        'updatedAt': Timestamp.fromDate(now),
      };

      // Vérifier si l'utilisateur existe déjà
      final existingDoc = await _usersCollection.doc(user.uid).get();
      
      if (!existingDoc.exists) {
        // Créer un nouvel utilisateur
        userData['createdAt'] = Timestamp.fromDate(now);
        await _usersCollection.doc(user.uid).set(userData);
      } else {
        // Mettre à jour l'utilisateur existant
        await _usersCollection.doc(user.uid).update(userData);
      }

      // Récupérer l'utilisateur mis à jour
      return await getCurrentUser();
    } catch (e) {
      print('Erreur lors de la création/mise à jour de l\'utilisateur: $e');
      return null;
    }
  }

  /// Met à jour uniquement certains champs
  Future<UserModel?> updateUserFields(Map<String, dynamic> fields) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      fields['updatedAt'] = Timestamp.fromDate(DateTime.now());
      
      await _usersCollection.doc(user.uid).update(fields);
      
      return await getCurrentUser();
    } catch (e) {
      print('Erreur lors de la mise à jour des champs: $e');
      return null;
    }
  }

  /// Supprime l'utilisateur
  Future<bool> deleteUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _usersCollection.doc(user.uid).delete();
      return true;
    } catch (e) {
      print('Erreur lors de la suppression de l\'utilisateur: $e');
      return false;
    }
  }

  /// Stream des changements de l'utilisateur actuel
  Stream<UserModel?> get currentUserStream {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _usersCollection
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc, null) : null);
  }
} 