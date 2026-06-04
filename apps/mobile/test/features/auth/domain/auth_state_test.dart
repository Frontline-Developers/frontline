import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/auth/domain/entities/user_identity.dart';
import 'package:frontline/features/auth/presentation/providers/auth_provider.dart';

void main() {
  group('UserIdentity', () {
    test('stores uid and isAnonymous', () {
      const identity = UserIdentity(uid: 'abc-123', isAnonymous: true);
      expect(identity.uid, 'abc-123');
      expect(identity.isAnonymous, isTrue);
    });

    test('non-anonymous flag is stored correctly', () {
      const identity = UserIdentity(uid: 'uid-456', isAnonymous: false);
      expect(identity.isAnonymous, isFalse);
    });
  });

  group('AuthState', () {
    test('default status is idle', () {
      const state = AuthState();
      expect(state.status, AuthStatus.idle);
    });

    test('default user and error are null', () {
      const state = AuthState();
      expect(state.user, isNull);
      expect(state.error, isNull);
    });

    test('copyWith updates status', () {
      const state = AuthState();
      final updated = state.copyWith(status: AuthStatus.loading);
      expect(updated.status, AuthStatus.loading);
    });

    test('copyWith preserves existing user when not overridden', () {
      const user = UserIdentity(uid: 'uid-1', isAnonymous: true);
      const state = AuthState(status: AuthStatus.authenticated, user: user);
      final updated = state.copyWith(status: AuthStatus.loading);
      expect(updated.user, user);
    });

    test('copyWith can clear error with explicit null', () {
      const state = AuthState(error: 'some error');
      final updated = state.copyWith(error: null);
      expect(updated.error, isNull);
    });

    test('copyWith without error arg preserves existing error', () {
      const state = AuthState(error: 'existing error');
      final updated = state.copyWith(status: AuthStatus.loading);
      expect(updated.error, 'existing error');
    });

    test('authenticated state holds user identity', () {
      const user = UserIdentity(uid: 'uid-xyz', isAnonymous: true);
      final state = AuthState(status: AuthStatus.authenticated, user: user);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user?.uid, 'uid-xyz');
    });
  });

  group('AuthStatus enum', () {
    test('has all expected values', () {
      expect(
        AuthStatus.values,
        containsAll([
          AuthStatus.idle,
          AuthStatus.loading,
          AuthStatus.authenticated,
          AuthStatus.unauthenticated,
        ]),
      );
    });
  });
}
