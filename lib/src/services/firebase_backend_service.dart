part of '../../main.dart';

/// Owns Roostify's authenticated Firebase access.
///
/// Authentication is intentionally kept out of [SharedPreferences]. Firebase
/// Auth persists the credential securely; Firestore stores the app-facing
/// username, profile, role, and farm data under the authenticated UID.
class FirebaseBackendService {
  FirebaseBackendService();

  DateTime? _lastHistoricalSensorWrite;

  bool get isReady => Firebase.apps.isNotEmpty;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseFunctions get _functions => FirebaseFunctions.instance;

  User? get currentUser => isReady ? _auth.currentUser : null;

  String authenticationEmail(String usernameOrEmail) {
    final value = usernameOrEmail.trim().toLowerCase();
    return value.contains('@') ? value : '$value@roostify.local';
  }

  Future<UserCredential> signInWithPassword({
    required String usernameOrEmail,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: authenticationEmail(usernameOrEmail),
      password: password,
    );
  }

  Future<UserCredential> signInWithGoogle(GoogleSignInAccount account) async {
    final tokens = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: tokens.accessToken,
      idToken: tokens.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<void> signOut() => _auth.signOut();

  Future<Map<String, dynamic>?> profileFor(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    return snapshot.data();
  }

  Future<Map<String, dynamic>> ensureStandardUserProfile(
    User firebaseUser, {
    required String preferredUsername,
  }) async {
    final reference = _firestore.collection('users').doc(firebaseUser.uid);
    final existing = await reference.get();
    final existingData = existing.data();
    if (existingData != null) return existingData;

    final username = _safeUsername(
      preferredUsername.isEmpty
          ? firebaseUser.email?.split('@').first ?? 'user'
          : preferredUsername,
    );
    final displayName = firebaseUser.displayName?.trim();
    final data = <String, dynamic>{
      'uid': firebaseUser.uid,
      'username': username,
      'displayName': displayName == null || displayName.isEmpty
          ? username
          : displayName,
      'email': firebaseUser.email ?? '',
      'role': UserRole.user.name,
      'cameraAccessEnabled': true,
      'contactNumber': '',
      'address': '',
      'facebookContact': '',
      'farmName': '',
      'shortBio': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await reference.set(data);
    final created = await reference.get();
    return created.data() ?? data;
  }

  Future<List<Map<String, dynamic>>> allUserProfiles() async {
    final snapshot = await _firestore.collection('users').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['uid'] = doc.id;
      return data;
    }).toList();
  }

  Future<void> updateProfile(AppUser user) async {
    if (currentUser == null) return;
    await _firestore.collection('users').doc(user.accountId).update({
      'displayName': user.displayName,
      'email': user.email,
      'contactNumber': user.contactNumber,
      'address': user.address,
      'facebookContact': user.facebookContact,
      'farmName': user.farmName,
      'shortBio': user.shortBio,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCameraAccess(String uid, bool enabled) async {
    await _firestore.collection('users').doc(uid).update({
      'cameraAccessEnabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw FirebaseAuthException(
        code: 'requires-recent-login',
        message: 'Sign in again before changing your password.',
      );
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: currentPassword),
    );
    await user.updatePassword(newPassword);
  }

  Future<UserCredential> linkGoogleAccount(
    GoogleSignInAccount googleAccount,
  ) async {
    final user = currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Sign in before connecting a Google account.',
      );
    }
    final tokens = await googleAccount.authentication;
    return user.linkWithCredential(
      GoogleAuthProvider.credential(
        accessToken: tokens.accessToken,
        idToken: tokens.idToken,
      ),
    );
  }

  Future<void> unlinkGoogleAccount() async {
    final user = currentUser;
    if (user == null) return;
    final hasPasswordProvider = user.providerData.any(
      (provider) => provider.providerId == EmailAuthProvider.PROVIDER_ID,
    );
    if (!hasPasswordProvider) {
      throw FirebaseAuthException(
        code: 'last-provider',
        message:
            'Add a password before disconnecting your only sign-in method.',
      );
    }
    await user.unlink(GoogleAuthProvider.PROVIDER_ID);
  }

  Future<Map<String, dynamic>> createUser({
    required String username,
    required String displayName,
    required String email,
    required String farmName,
    required String contactNumber,
    required String address,
    required String temporaryPassword,
  }) async {
    final result = await _functions.httpsCallable('createRoostifyUser').call({
      'username': username,
      'displayName': displayName,
      'email': email,
      'farmName': farmName,
      'contactNumber': contactNumber,
      'address': address,
      'temporaryPassword': temporaryPassword,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> deleteUser(String uid) async {
    await _functions.httpsCallable('deleteRoostifyUser').call({'uid': uid});
  }

  Future<void> resetUserPassword(String uid, String temporaryPassword) async {
    await _functions.httpsCallable('resetRoostifyUserPassword').call({
      'uid': uid,
      'temporaryPassword': temporaryPassword,
    });
  }

  Future<void> saveSensorReading({
    required String ownerUid,
    required Esp32SensorReading reading,
  }) async {
    final farm = _firestore.collection('farms').doc(ownerUid);
    final values = <String, dynamic>{
      'ownerUid': ownerUid,
      'temperature': reading.temperatureC,
      'humidity': reading.humidityPercent,
      'airPpm': reading.airQualityPpm,
      'dhtAvailable': reading.dhtAvailable,
      'airAvailable': reading.airAvailable,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await farm.collection('status').doc('latest').set(values);

    final now = DateTime.now();
    final lastWrite = _lastHistoricalSensorWrite;
    if (lastWrite != null &&
        now.difference(lastWrite) < const Duration(minutes: 1)) {
      return;
    }
    _lastHistoricalSensorWrite = now;
    await farm.collection('sensorReadings').add({
      ...values,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchLatestSensor(
    String ownerUid,
  ) {
    return _firestore
        .collection('farms')
        .doc(ownerUid)
        .collection('status')
        .doc('latest')
        .snapshots();
  }

  static String _safeUsername(String value) {
    final sanitized = value.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9._-]'),
      '_',
    );
    return sanitized.isEmpty ? 'user' : sanitized;
  }
}
