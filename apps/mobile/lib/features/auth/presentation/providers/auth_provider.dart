import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/auth_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_identity.dart';

enum AuthStatus { idle, loading, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final UserIdentity? user;
  final String? error;
  const AuthState({this.status = AuthStatus.idle, this.user, this.error});

  AuthState copyWith({AuthStatus? status, UserIdentity? user, Object? error = _sentinel}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();

final _authDatasourceProvider = Provider((ref) => AuthDatasourceImpl(FirebaseAuth.instance));
final _authRepositoryProvider = Provider(
  (ref) => AuthRepositoryImpl(ref.watch(_authDatasourceProvider)),
);

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    ref.watch(_authRepositoryProvider).watchAuthState().listen((user) {
      if (user != null) {
        state = state.copyWith(status: AuthStatus.authenticated, user: user);
      } else {
        state = state.copyWith(status: AuthStatus.unauthenticated, user: null);
      }
    });
    return const AuthState(status: AuthStatus.idle);
  }

  Future<void> signInAnonymously() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final user = await ref.read(_authRepositoryProvider).signInAnonymously();
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = state.copyWith(status: AuthStatus.unauthenticated, error: e.toString());
    }
  }
}
