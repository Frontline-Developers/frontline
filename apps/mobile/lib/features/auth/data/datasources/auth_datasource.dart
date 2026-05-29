import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/user_identity.dart';

abstract class AuthDatasource {
  Future<UserIdentity> signInAnonymously();
  Stream<UserIdentity?> watchAuthState();
  Future<void> signOut();
}

class AuthDatasourceImpl implements AuthDatasource {
  final FirebaseAuth _auth;
  AuthDatasourceImpl(this._auth);

  @override
  Future<UserIdentity> signInAnonymously() async {
    final cred = await _auth.signInAnonymously();
    return UserIdentity(uid: cred.user!.uid, isAnonymous: true);
  }

  @override
  Stream<UserIdentity?> watchAuthState() {
    return _auth.authStateChanges().map(
      (user) => user == null
          ? null
          : UserIdentity(uid: user.uid, isAnonymous: user.isAnonymous),
    );
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
