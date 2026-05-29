import '../entities/user_identity.dart';

abstract class AuthRepository {
  Future<UserIdentity> signInAnonymously();
  Stream<UserIdentity?> watchAuthState();
  Future<void> signOut();
}
