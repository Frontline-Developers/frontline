import '../../domain/entities/user_identity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthDatasource _datasource;
  AuthRepositoryImpl(this._datasource);

  @override
  Future<UserIdentity> signInAnonymously() => _datasource.signInAnonymously();

  @override
  Stream<UserIdentity?> watchAuthState() => _datasource.watchAuthState();

  @override
  Future<void> signOut() => _datasource.signOut();
}
