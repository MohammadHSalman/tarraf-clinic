import 'package:flutter/foundation.dart';
import '../data/clinic_repository.dart';

class ClinicController extends ChangeNotifier {
  final ClinicRepository repository;
  bool arabic = true;
  bool biometric = false;
  int generation = 0;
  ClinicController(this.repository);
  Future<void> loadPreferences() async {
    final settings = await repository.documents('settings');
    if (settings.isNotEmpty) {
      arabic = settings.first['ar'] as bool? ?? true;
      biometric = settings.first['bio'] as bool? ?? false;
    }
  }

  Future<void> preferences({bool? arabic, bool? biometric}) async {
    this.arabic = arabic ?? this.arabic;
    this.biometric = biometric ?? this.biometric;
    final old = await repository.documents('settings');
    await repository.document('settings', {
      'ar': this.arabic,
      'bio': this.biometric,
    }, documentId: old.isEmpty ? null : old.first['id'] as String);
    notifyListeners();
  }

  Future<T> mutate<T>(Future<T> Function() operation) async {
    final value = await operation();
    generation++;
    notifyListeners();
    return value;
  }

  String tr(String ar, String en) => arabic ? ar : en;
}
