import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// A service class to handle all Firestore database operations for users.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collectionPath = 'users';

  /// Saves user data to Firestore.
  ///
  /// This method is typically called after a user signs up.
  /// It saves the user's first name, last name, email, phone number, and birth date.
  /// Note: Passwords should NEVER be stored in Firestore. Firebase Authentication
  /// handles password storage securely.
  Future<void> saveUserData({
    required String uid,
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
    required String birthDate,
  }) async {
    final userData = {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': phoneNumber,
      'birthDate': birthDate,
      'translationCount': 0,
      'savedGlyphsCount': 0,
    };

    try {
      await _db.collection(_collectionPath).doc(uid).set(userData);
    } catch (e) {
      debugPrint('Error saving user data: $e');
      // Rethrowing the exception allows the UI to handle it and show feedback.
      rethrow;
    }
  }

  /// Returns true if a Firestore user document already exists for [uid].
  ///
  /// Used by the Google Sign-In flow to determine whether the user needs
  /// to complete their profile or can be sent straight to the app.
  Future<bool> userExists(String uid) async {
    try {
      final doc = await _db.collection(_collectionPath).doc(uid).get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking user existence: $e');
      return false;
    }
  }

  /// Fetches a user's data from Firestore.
  ///
  /// Returns a DocumentSnapshot containing the user's data, which can
  /// be accessed via the .data() method.
  Future<DocumentSnapshot> getUserData(String uid) async {
    try {
      return await _db.collection(_collectionPath).doc(uid).get();
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      rethrow;
    }
  }

  /// Updates user data in Firestore.
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      await _db
          .collection(_collectionPath)
          .doc(uid)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating user data: $e');
      rethrow;
    }
  }

  /// Increments the translation count for a user.
  Future<void> incrementTranslationCount(String uid) async {
    try {
      await _db.collection(_collectionPath).doc(uid).set({
        'translationCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error incrementing translation count: $e');
      rethrow;
    }
  }

  /// Increments the saved glyphs count for a user.
  Future<void> incrementSavedGlyphsCount(String uid) async {
    try {
      await _db.collection(_collectionPath).doc(uid).set({
        'savedGlyphsCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error incrementing saved glyphs count: $e');
      rethrow;
    }
  }

  /// Decrements the saved glyphs count for a user.
  Future<void> decrementSavedGlyphsCount(String uid) async {
    try {
      await _db.collection(_collectionPath).doc(uid).set({
        'savedGlyphsCount': FieldValue.increment(-1),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error decrementing saved glyphs count: $e');
      rethrow;
    }
  }

  /// Records a new translation entry for a user.
  Future<DocumentReference<Map<String, dynamic>>> recordTranslation(
    String uid,
    Map<String, dynamic> translationData,
  ) async {
    try {
      return await _db
          .collection(_collectionPath)
          .doc(uid)
          .collection('Translation data')
          .add(translationData);
    } catch (e) {
      debugPrint('Error recording translation: $e');
      rethrow;
    }
  }

  /// Fetches the translation history for a user, ordered by date descending.
  Stream<QuerySnapshot> getTranslationHistory(String uid) {
    debugPrint('Querying history for path: users/$uid/Translation data');
    return _db
        .collection(_collectionPath)
        .doc(uid)
        .collection('Translation data')
        .orderBy('Date', descending: true)
        .snapshots();
  }

  /// Saves the user's preferred UI language to Firestore.
  Future<void> saveUserLanguage(String uid, String language) async {
    try {
      await _db
          .collection(_collectionPath)
          .doc(uid)
          .set({'preferredLanguage': language}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving user language: $e');
      rethrow;
    }
  }

  /// Fetches the user's preferred UI language from Firestore.
  /// Returns 'English' as the default if none is saved.
  Future<String> getUserLanguage(String uid) async {
    try {
      final doc = await _db.collection(_collectionPath).doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['preferredLanguage'] as String? ?? 'English';
      }
      return 'English';
    } catch (e) {
      debugPrint('Error fetching user language: $e');
      return 'English';
    }
  }

  /// Deletes a specific translation entry for a user.
  Future<void> deleteTranslation(String uid, String docId) async {
    try {
      await _db
          .collection(_collectionPath)
          .doc(uid)
          .collection('Translation data')
          .doc(docId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting translation: $e');
      rethrow;
    }
  }

  /// Clones all user data and subcollections from an old UID to a new UID in Firestore.
  Future<void> cloneUserData(String oldUid, String newUid) async {
    try {
      // 1. Copy the main user document
      final oldDoc = await _db.collection(_collectionPath).doc(oldUid).get();
      if (oldDoc.exists) {
        final data = oldDoc.data() as Map<String, dynamic>;
        await _db.collection(_collectionPath).doc(newUid).set(data);
      }

      // 2. Copy the 'Translation data' subcollection
      final translationDataQuery = await _db
          .collection(_collectionPath)
          .doc(oldUid)
          .collection('Translation data')
          .get();

      final batch = _db.batch();
      for (var doc in translationDataQuery.docs) {
        final newDocRef = _db
            .collection(_collectionPath)
            .doc(newUid)
            .collection('Translation data')
            .doc(doc.id);
        batch.set(newDocRef, doc.data());
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error cloning user data from $oldUid to $newUid: $e');
      rethrow;
    }
  }

  /// Deletes all user data including subcollections from Firestore.
  Future<void> deleteUserData(String uid) async {
    try {
      // 1. Delete translation history subcollection
      final translationDataQuery = await _db
          .collection(_collectionPath)
          .doc(uid)
          .collection('Translation data')
          .get();

      final batch = _db.batch();
      for (var doc in translationDataQuery.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // 2. Delete the main document
      await _db.collection(_collectionPath).doc(uid).delete();
    } catch (e) {
      debugPrint('Error deleting user data for $uid: $e');
      rethrow;
    }
  }
}
