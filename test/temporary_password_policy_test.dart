import 'package:coolapp/main.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _user() {
  return AppUser(
    accountId: 'user-id',
    username: 'farmer',
    displayName: 'Farmer',
    role: UserRole.user,
    cameraAccessEnabled: true,
    monitor: MonitorSnapshot.empty(),
    cctvs: const [],
  );
}

void main() {
  group('temporary password policy', () {
    test(
      'uses server policy timestamps to calculate the remaining lock time',
      () {
        final user = _user();
        user.applyTemporaryPasswordPolicy({
          'created_at': '2026-10-01T12:00:00.000Z',
          'temporary_password_issued_at': '2026-10-01T12:00:00.000Z',
          'temporary_password_first_login_at': '2026-10-10T12:00:00.000Z',
          'password_change_available_at': '2026-10-17T12:00:00.000Z',
          'temporary_password_changed_at': null,
        });

        final now = DateTime.utc(2026, 10, 11, 12);
        expect(user.hasPendingTemporaryPassword, isTrue);
        expect(user.isTemporaryPasswordLocked(now), isTrue);
        expect(user.temporaryPasswordStatusLabel(now), '6d 0h remaining');
        expect(user.accountCreatedAt, DateTime.utc(2026, 10, 1, 12));
        expect(
          user.temporaryPasswordFirstLoginAt,
          DateTime.utc(2026, 10, 10, 12),
        );
      },
    );

    test('reports an awaiting state until the first server-recorded login', () {
      final user = _user();
      user.applyTemporaryPasswordPolicy({
        'temporaryPasswordIssuedAt': '2026-10-10T12:00:00.000Z',
        'temporaryPasswordFirstLoginAt': null,
        'passwordChangeAvailableAt': null,
        'temporaryPasswordChangedAt': null,
      });

      expect(
        user.temporaryPasswordStatusLabel(DateTime.utc(2026, 10, 11)),
        'Waiting for first login',
      );
    });

    test('clears the temporary-password label once replacement succeeds', () {
      final user = _user();
      user.applyTemporaryPasswordPolicy({
        'temporaryPasswordIssuedAt': '2026-10-01T12:00:00.000Z',
        'temporaryPasswordFirstLoginAt': '2026-10-01T12:00:00.000Z',
        'passwordChangeAvailableAt': null,
        'temporaryPasswordChangedAt': '2026-10-08T12:00:00.000Z',
      });

      expect(user.hasPendingTemporaryPassword, isFalse);
      expect(
        user.temporaryPasswordStatusLabel(DateTime.utc(2026, 10, 9)),
        isNull,
      );
    });
  });
}
