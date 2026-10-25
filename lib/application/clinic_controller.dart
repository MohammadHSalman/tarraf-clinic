import 'package:flutter/foundation.dart';
import '../data/clinic_repository.dart';

class ClinicController extends ChangeNotifier {
  final ClinicRepository repository;
  bool arabic = true;
  bool biometric = false;
  DateTime? lastBackup;
  int generation = 0;
  int _cacheGeneration = -1;
  Future<List<Map<String, dynamic>>>? _patients, _appointments;
  ClinicController(this.repository);

  /// True when no encrypted backup was exported in the last 7 days.
  bool get needsBackup =>
      lastBackup == null || DateTime.now().difference(lastBackup!).inDays >= 7;

  Future<void> loadPreferences() async {
    final settings = await repository.documents('settings');
    if (settings.isNotEmpty) {
      arabic = settings.first['ar'] as bool? ?? true;
      biometric = settings.first['bio'] as bool? ?? false;
      final bk = settings.first['bk'] as String?;
      lastBackup = bk == null ? null : DateTime.tryParse(bk);
    }
  }

  Future<void> preferences({
    bool? arabic,
    bool? biometric,
    DateTime? lastBackup,
  }) async {
    this.arabic = arabic ?? this.arabic;
    this.biometric = biometric ?? this.biometric;
    this.lastBackup = lastBackup ?? this.lastBackup;
    final old = await repository.documents('settings');
    await repository.document('settings', {
      'ar': this.arabic,
      'bio': this.biometric,
      if (this.lastBackup != null)
        'bk': this.lastBackup!.toUtc().toIso8601String(),
    }, documentId: old.isEmpty ? null : old.first['id'] as String);
    notifyListeners();
  }

  Future<void> markBackup() => preferences(lastBackup: DateTime.now());

  Future<T> mutate<T>(Future<T> Function() operation) async {
    final value = await operation();
    generation++;
    notifyListeners();
    return value;
  }

  void _syncCache() {
    if (_cacheGeneration != generation) {
      _cacheGeneration = generation;
      _patients = null;
      _appointments = null;
    }
  }

  /// Patients are decrypted once per data generation instead of on every
  /// rebuild (search keystrokes, tab switches, day selection).
  Future<List<Map<String, dynamic>>> patients() {
    _syncCache();
    final existing = _patients;
    if (existing != null) return existing;
    final future = repository.patients();
    future.then<void>((_) {}, onError: (Object _) {
      if (identical(_patients, future)) _patients = null;
    });
    return _patients = future;
  }

  /// All appointments of active patients, sorted by time (single query).
  Future<List<Map<String, dynamic>>> appointments() {
    _syncCache();
    final existing = _appointments;
    if (existing != null) return existing;
    final future = repository.appointments();
    future.then<void>((_) {}, onError: (Object _) {
      if (identical(_appointments, future)) _appointments = null;
    });
    return _appointments = future;
  }

  String tr(String ar, String en) => arabic ? ar : en;
}
