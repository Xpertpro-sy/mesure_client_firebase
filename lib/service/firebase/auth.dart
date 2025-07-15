import 'package:firebase_auth/firebase_auth.dart';

class Auth {

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // LOGIN WITH EMAIL AND PASSWORD
  Future<void> loginWithEmailAndPassworsd(String email, String password) async {
    await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
  }

  // LOGOUT
  Future<void> logout() async {
    await _firebaseAuth.signOut();
  }

  // CREATE USER WITH EMAIL AND PASSWORD
  Future<void> createUserWithEmailAndPassworsd(String email, String password) async {
    await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
  }
}