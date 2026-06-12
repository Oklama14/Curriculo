import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/job_model.dart';
import '../models/history_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class AppState extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  AppState() {
    // Escuta alterações de autenticação
    AuthService().authStateChanges.listen((user) {
      setAuthUser(user);
    });
  }

  // Estado de Autenticação
  User? _currentUser;
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  // Estado do Perfil
  String? _profileName;
  String? get profileName => _profileName;

  String? _profileEmail;
  String? get profileEmail => _profileEmail;

  String? _linkedinUrl;
  String? get linkedinUrl => _linkedinUrl;

  String? _gupyUrl;
  String? get gupyUrl => _gupyUrl;

  String? _photoUrl;
  String? get photoUrl => _photoUrl;

  bool _isLoadingProfile = false;
  bool get isLoadingProfile => _isLoadingProfile;

  String? _profileError;
  String? get profileError => _profileError;

  // Estado de Candidatura
  ScrapedJob? _applyJob;
  ScrapedJob? get applyJob => _applyJob;

  Map<String, dynamic>? _lastApplyPrepareResponse;
  Map<String, dynamic>? get lastApplyPrepareResponse => _lastApplyPrepareResponse;

  bool _isPreparingApply = false;
  bool get isPreparingApply => _isPreparingApply;

  String? _applyError;
  String? get applyError => _applyError;

  // Estado de Navegação
  int _currentTabIndex = 0;
  int get currentTabIndex => _currentTabIndex;

  void setTab(int index) {
    _currentTabIndex = index;
    notifyListeners();
  }

  // Listas de Dados
  List<ScrapedJob> _jobs = [];
  List<ScrapedJob> get jobs => _jobs;

  List<HistoryItem> _history = [];
  List<HistoryItem> get history => _history;

  // Estados de Carregamento
  bool _isLoadingJobs = false;
  bool get isLoadingJobs => _isLoadingJobs;

  bool _isLoadingHistory = false;
  bool get isLoadingHistory => _isLoadingHistory;

  bool _isScraping = false;
  bool get isScraping => _isScraping;

  bool _isTailoring = false;
  bool get isTailoring => _isTailoring;

  // Estados de Erro
  String? _jobsError;
  String? get jobsError => _jobsError;

  String? _historyError;
  String? get historyError => _historyError;

  String? _scrapeError;
  String? get scrapeError => _scrapeError;

  String? _tailorError;
  String? get tailorError => _tailorError;

  // Estado do Tailor em Execução
  String _tailorInputDescription = '';
  String get tailorInputDescription => _tailorInputDescription;

  Map<String, dynamic>? _lastTailorResponse;
  Map<String, dynamic>? get lastTailorResponse => _lastTailorResponse;

  void updateTailorInputDescription(String val) {
    _tailorInputDescription = val;
    notifyListeners();
  }

  // Prepara o formulário do Tailor a partir de uma vaga coletada e navega
  void selectJobForTailoring(String description) {
    _tailorInputDescription = description;
    _lastTailorResponse = null; // Reseta o último resultado para iniciar limpo
    _currentTabIndex = 1; // Vai para a aba Tailor
    notifyListeners();
  }

  // Prepara a candidatura a partir de uma vaga e navega
  void selectJobForApply(ScrapedJob job) {
    _applyJob = job;
    _lastApplyPrepareResponse = null;
    _currentTabIndex = 6; // Vai para a aba Candidatar-se
    notifyListeners();
  }

  // Configura o usuário autenticado
  void setAuthUser(User? user) {
    _currentUser = user;
    if (user != null) {
      _profileName = user.displayName;
      _profileEmail = user.email;
      _photoUrl = user.photoURL;
      // Carrega dados específicos do usuário
      loadProfile().then((_) => loadAll());
    } else {
      _profileName = null;
      _profileEmail = null;
      _photoUrl = null;
      _linkedinUrl = null;
      _gupyUrl = null;
      _jobs = [];
      _history = [];
    }
    notifyListeners();
  }

  // Carrega o perfil do usuário
  Future<void> loadProfile() async {
    _isLoadingProfile = true;
    _profileError = null;
    notifyListeners();

    try {
      final data = await _apiService.fetchProfile();
      _profileName = data['name'] ?? _profileName;
      _profileEmail = data['email'] ?? _profileEmail;
      _linkedinUrl = data['linkedin_url'];
      _gupyUrl = data['gupy_url'];
      _photoUrl = data['photo_url'] ?? _photoUrl;
    } catch (e) {
      _profileError = e.toString();
    } finally {
      _isLoadingProfile = false;
      notifyListeners();
    }
  }

  // Atualiza o perfil do usuário
  Future<bool> updateUserProfile({
    String? name,
    String? linkedinUrl,
    String? gupyUrl,
    String? photoUrl,
  }) async {
    _isLoadingProfile = true;
    _profileError = null;
    notifyListeners();

    try {
      final reqData = <String, dynamic>{};
      if (name != null) reqData['name'] = name;
      if (linkedinUrl != null) reqData['linkedin_url'] = linkedinUrl;
      if (gupyUrl != null) reqData['gupy_url'] = gupyUrl;
      if (photoUrl != null) reqData['photo_url'] = photoUrl;

      final data = await _apiService.updateProfile(reqData);
      _profileName = data['name'] ?? _profileName;
      _profileEmail = data['email'] ?? _profileEmail;
      _linkedinUrl = data['linkedin_url'];
      _gupyUrl = data['gupy_url'];
      _photoUrl = data['photo_url'] ?? _photoUrl;
      return true;
    } catch (e) {
      _profileError = e.toString();
      return false;
    } finally {
      _isLoadingProfile = false;
      notifyListeners();
    }
  }

  // Reseta o estado de candidatura para permitir recomeçar sem recarregar tudo
  void resetApplyState() {
    _lastApplyPrepareResponse = null;
    _applyError = null;
    notifyListeners();
  }

  // Prepara candidatura
  Future<bool> prepareApplication({
    required String jobUrl,
    required String tailorRunId,
  }) async {
    _isPreparingApply = true;
    _applyError = null;
    _lastApplyPrepareResponse = null;
    notifyListeners();

    try {
      final data = await _apiService.prepareApplication(
        jobUrl: jobUrl,
        tailorRunId: tailorRunId,
      );
      _lastApplyPrepareResponse = data;
      return true;
    } catch (e) {
      _applyError = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isPreparingApply = false;
      notifyListeners();
    }
  }

  // Carrega todas as vagas coletadas
  Future<void> loadJobs() async {
    _isLoadingJobs = true;
    _jobsError = null;
    notifyListeners();

    try {
      _jobs = await _apiService.fetchJobs();
    } catch (e) {
      _jobsError = e.toString();
    } finally {
      _isLoadingJobs = false;
      notifyListeners();
    }
  }

  // Carrega o histórico de otimizações
  Future<void> loadHistory() async {
    _isLoadingHistory = true;
    _historyError = null;
    notifyListeners();

    try {
      _history = await _apiService.fetchHistory();
    } catch (e) {
      _historyError = e.toString();
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  // Dispara coleta de vaga via scraper
  Future<ScrapedJob?> scrapeJob(String url) async {
    _isScraping = true;
    _scrapeError = null;
    notifyListeners();

    try {
      final newJob = await _apiService.scrapeJob(url);
      // Recarrega a lista de vagas para refletir a nova inserção
      await loadJobs();
      return newJob;
    } catch (e) {
      _scrapeError = e.toString().replaceAll('Exception: ', '');
      return null;
    } finally {
      _isScraping = false;
      notifyListeners();
    }
  }

  // Dispara o processo de tailoring no backend
  Future<bool> runTailor({
    required String jobDescription,
    bool tailorSkills = true,
    bool compilePdf = true,
  }) async {
    _isTailoring = true;
    _tailorError = null;
    _lastTailorResponse = null;
    notifyListeners();

    try {
      final result = await _apiService.tailorResume(
        jobDescription: jobDescription,
        tailorSkills: tailorSkills,
        compilePdf: compilePdf,
      );
      _lastTailorResponse = result;
      // Recarrega o histórico para incluir a nova execução
      await loadHistory();
      return result['success'] ?? false;
    } catch (e) {
      _tailorError = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isTailoring = false;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════
  // Estado do Currículo Base (.tex)
  // ══════════════════════════════════════════════════════

  Map<String, dynamic>? _resumeInfo;
  Map<String, dynamic>? get resumeInfo => _resumeInfo;

  String? _resumePreview;
  String? get resumePreview => _resumePreview;

  bool _isLoadingResume = false;
  bool get isLoadingResume => _isLoadingResume;

  bool _isUploadingResume = false;
  bool get isUploadingResume => _isUploadingResume;

  String? _resumeError;
  String? get resumeError => _resumeError;

  String? _resumeUploadSuccess;
  String? get resumeUploadSuccess => _resumeUploadSuccess;

  // Carrega informações do currículo atual
  Future<void> loadResumeInfo() async {
    _isLoadingResume = true;
    _resumeError = null;
    notifyListeners();

    try {
      _resumeInfo = await _apiService.fetchResumeInfo();
    } catch (e) {
      _resumeError = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoadingResume = false;
      notifyListeners();
    }
  }

  // Carrega o preview do conteúdo .tex
  Future<void> loadResumePreview() async {
    _isLoadingResume = true;
    _resumeError = null;
    notifyListeners();

    try {
      _resumePreview = await _apiService.fetchResumePreview();
    } catch (e) {
      _resumeError = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoadingResume = false;
      notifyListeners();
    }
  }

  // Faz upload de um novo currículo .tex
  Future<bool> uploadResume(List<int> fileBytes, String fileName) async {
    _isUploadingResume = true;
    _resumeError = null;
    _resumeUploadSuccess = null;
    notifyListeners();

    try {
      final result = await _apiService.uploadResume(fileBytes, fileName);
      _resumeUploadSuccess = result['message'] ?? 'Upload realizado com sucesso!';
      // Recarrega as informações e o preview
      await loadResumeInfo();
      await loadResumePreview();
      return true;
    } catch (e) {
      _resumeError = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isUploadingResume = false;
      notifyListeners();
    }
  }

  // Limpa o feedback de upload
  void clearResumeMessages() {
    _resumeError = null;
    _resumeUploadSuccess = null;
    notifyListeners();
  }

  // Função utilitária para carregar tudo (usada no bootstrap do app)
  Future<void> loadAll() async {
    await Future.wait([
      loadJobs(),
      loadHistory(),
      loadResumeInfo(),
    ]);
  }
}

