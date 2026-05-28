import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  bool _isMockMode = false;
  MockUser? _mockUser;

  // StreamController persistente para mock mode — broadcast permite múltiplos listeners
  final StreamController<User?> _mockAuthController = StreamController<User?>.broadcast();

  void enableMockMode() {
    _isMockMode = true;
    _mockUser = MockUser();
    // Emite o estado inicial do mock user na stream
    _mockAuthController.add(_mockUser);
  }

  bool get isMockMode => _isMockMode;

  // Stream of auth state changes
  Stream<User?> get authStateChanges {
    if (_isMockMode) {
      // Retorna a stream persistente que emite alterações quando signIn/signOut ocorrem
      return _mockAuthController.stream;
    }
    try {
      return FirebaseAuth.instance.authStateChanges();
    } catch (_) {
      // Se der erro ao acessar FirebaseAuth (por ex: não inicializado), força mock mode
      enableMockMode();
      return _mockAuthController.stream;
    }
  }

  User? get currentUser {
    if (_isMockMode) {
      return _mockUser;
    }
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  Future<String?> get idToken async {
    if (_isMockMode) {
      return 'MOCK_JWT_TOKEN_FOR_LOCAL_DEV';
    }
    try {
      return await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (_) {
      return null;
    }
  }

  Future<User?> signInWithGoogle() async {
    if (_isMockMode) {
      _mockUser = MockUser(
        uid: 'local_dev_user',
        displayName: 'Usuário Local Dev',
        email: 'local_dev_user@example.com',
        photoURL: 'https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y',
      );
      // Emite o novo usuário na stream para que AppState reaja
      _mockAuthController.add(_mockUser);
      return _mockUser;
    }
    
    try {
      final googleProvider = GoogleAuthProvider();
      final userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
      return userCredential.user;
    } catch (e) {
      print('Erro ao autenticar com Firebase, ativando mock mode: $e');
      enableMockMode();
      return signInWithGoogle();
    }
  }

  Future<void> signOut() async {
    if (_isMockMode) {
      _mockUser = null;
      // Emite null na stream para sinalizar logout ao AppState
      _mockAuthController.add(null);
      return;
    }
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }
}

class MockUser implements User {
  @override
  final String uid;
  @override
  final String? displayName;
  @override
  final String? email;
  @override
  final String? photoURL;

  MockUser({
    this.uid = 'local_dev_user',
    this.displayName = 'Usuário Local Dev',
    this.email = 'local_dev_user@example.com',
    this.photoURL = 'https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y',
  });

  @override
  Future<String> getIdToken([bool forceRefresh = false]) async => 'MOCK_JWT_TOKEN_FOR_LOCAL_DEV';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
