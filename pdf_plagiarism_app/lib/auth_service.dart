import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current logged-in user
  User? get currentUser => _auth.currentUser;

  // Sign Up user and save profile to Firestore
  Future<UserModel?> registerUser({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    try {
      // 1. Create authentication account
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        String uid = credential.user!.uid;

        // 2. Build User Model
        UserModel newUser = UserModel(
          uid: uid,
          name: name,
          email: email,
          role: role,
          createdAt: DateTime.now(),
        );

        // 3. Store user details in Firestore under 'users' collection
        await _firestore.collection('users').doc(uid).set(newUser.toMap());

        return newUser;
      }
    } catch (e) {
      debugPrint("Error creating user profile: $e");
      rethrow;
    }
    return null;
  }

  // Log in existing user
  Future<UserCredential> loginUser(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Fetch current user details from Firestore
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
    }
    return null;
  }

  // Sign out user
  Future<void> signOut() async {
    await _auth.signOut();
  }
}