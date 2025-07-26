import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../model/user_model.dart';
import 'package:hive/hive.dart';

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
      
      // Récupérer les données existantes
      final existingDoc = await _usersCollection.doc(user.uid).get();
      Map<String, dynamic> userData = {
        'email': user.email,
        'updatedAt': Timestamp.fromDate(now),
      };

      if (!existingDoc.exists) {
        // Créer un nouvel utilisateur
        userData['createdAt'] = Timestamp.fromDate(now);
        userData['firstName'] = firstName;
        userData['lastName'] = lastName;
        userData['phoneNumber'] = phoneNumber;
        userData['profileImageUrl'] = profileImageUrl;
        
        await _usersCollection.doc(user.uid).set(userData);
      } else {
        // Mettre à jour l'utilisateur existant - ne mettre à jour que les champs non-null
        Map<String, dynamic> updateData = {
          'updatedAt': Timestamp.fromDate(now),
        };
        
        if (firstName != null) updateData['firstName'] = firstName;
        if (lastName != null) updateData['lastName'] = lastName;
        if (phoneNumber != null) updateData['phoneNumber'] = phoneNumber;
        if (profileImageUrl != null) updateData['profileImageUrl'] = profileImageUrl;
        
        await _usersCollection.doc(user.uid).set(updateData, SetOptions(merge: true));
      }

      // Récupérer l'utilisateur mis à jour
      final updatedUser = await getCurrentUser();
      // Sauvegarder dans Hive
      if (updatedUser != null) {
        final userBox = await Hive.openBox<UserModel>('user_profile');
        await userBox.put(updatedUser.id, updatedUser);
      }
      return updatedUser;
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