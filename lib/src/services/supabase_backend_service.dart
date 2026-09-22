part of '../../main.dart';

/// Owns Roostify's authenticated Supabase access.
///
/// Authentication is intentionally kept out of [SharedPreferences]. Supabase
/// Auth persists the session securely on its own; Postgres (via `profiles`)
/// stores the app-facing username, profile, role, and farm data under the
/// authenticated user id.
class SupabaseBackendService {
  SupabaseBackendService();

  SupabaseClient get _client => Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  String authenticationEmail(String usernameOrEmail) {
    final value = usernameOrEmail.trim().toLowerCase();
    return value.contains('@') ? value : '$value@roostify.local';
  }

  Future<AuthResponse> signInWithPassword({
    required String usernameOrEmail,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: authenticationEmail(usernameOrEmail),
      password: password,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<Map<String, dynamic>?> profileFor(String uid) {
    return _client.from('profiles').select().eq('id', uid).maybeSingle();
  }

  Future<List<Map<String, dynamic>>> allUserProfiles() {
    return _client.from('profiles').select();
  }

  Future<void> updateProfile(AppUser user) async {
    if (currentUser == null) return;
    // updated_at is set by the profiles_enforce_update_rules trigger, not
    // passed explicitly here.
    await _client
        .from('profiles')
        .update({
          'display_name': user.displayName,
          'email': user.email,
          'contact_number': user.contactNumber,
          'address': user.address,
          'facebook_contact': user.facebookContact,
          'farm_name': user.farmName,
          'short_bio': user.shortBio,
        })
        .eq('id', user.accountId);
  }

  Future<void> updateCameraAccess(String uid, bool enabled) async {
    await _client
        .from('profiles')
        .update({'camera_access_enabled': enabled})
        .eq('id', uid);
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AuthException('Sign in again before changing your password.');
    }
    // Supabase has no separate reauthenticate call - verifying the current
    // password by signing in again is the equivalent gate before allowing
    // the change.
    await _client.auth.signInWithPassword(
      email: email,
      password: currentPassword,
    );
    await _client.auth.updateUser(UserAttributes(password: newPassword));
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
    final response = await _client.functions.invoke(
      'create-roostify-user',
      body: {
        'username': username,
        'displayName': displayName,
        'email': email,
        'farmName': farmName,
        'contactNumber': contactNumber,
        'address': address,
        'temporaryPassword': temporaryPassword,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> deleteUser(String uid) async {
    await _client.functions.invoke('delete-roostify-user', body: {'uid': uid});
  }

  Future<void> resetUserPassword(String uid, String temporaryPassword) async {
    await _client.functions.invoke(
      'reset-roostify-user-password',
      body: {'uid': uid, 'temporaryPassword': temporaryPassword},
    );
  }

  /// Latest environment reading for one farm, written by the ESP32 itself
  /// over Wi-Fi (via the ingest-sensor-reading Edge Function) rather than by
  /// this app — the app only ever reads this stream, live via Realtime.
  SupabaseStreamFilterBuilder watchLatestSensor(String ownerUid) {
    return _client
        .from('farm_status')
        .stream(primaryKey: ['owner_uid'])
        .eq('owner_uid', ownerUid);
  }
}
