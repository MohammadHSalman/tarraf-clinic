import '../data/clinic_repository.dart';
import '../core/reminders.dart';

class AppointmentScheduler {
  static int notificationId(String id) =>
      id.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x3fffffff);
  static Future<void> reconcile(
    ClinicRepository repo,
    Reminders reminders,
  ) async {
    if (await repo.meta('reminders_need_reschedule') != '1') return;
    await reminders.cancelAll();
    for (final patient in await repo.patients()) {
      for (final appointment in await repo.documents(
        'appointments',
        patient: patient['patient_id'] as String,
      )) {
        final at = DateTime.parse(appointment['at'] as String),
            id = notificationId(appointment['id'] as String);
        await reminders.schedule(id, at.subtract(const Duration(days: 1)));
        await reminders.schedule(id + 1, at.subtract(const Duration(hours: 1)));
      }
    }
    await repo.db.update(
      'app_meta',
      {'value': '0'},
      where: 'key=?',
      whereArgs: ['reminders_need_reschedule'],
    );
  }
}
