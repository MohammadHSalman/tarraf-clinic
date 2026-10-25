# Safe 0.1.1 → 0.2.0 migration

Entry: AppDatabase.open → LegacyMigration.run. Original clinic.db is opened read-only using sqflite; its vault-key-v1 is read from the existing secure storage. Missing keys cause an explicit stop, never silent replacement. A separate clinic-v020.db is opened using SQLCipher and fresh device keys.

1. User confirms the real legacy currency and decimal precision. The original application stored neither reliably. Values with excess nonzero decimal precision cause rollback instead of rounding/truncation.
2. A single read snapshot fetches original records. AES-GCM authentication/decryption must succeed for every record before destination mutation.
3. A destination transaction archives EVERY raw record plus its decoded payload, re-encrypted with new AES-256-GCM and archive-specific AAD. New UUIDs and provenance links are generated.
4. Patients are imported first. Visits become legacy sessions, with original procedure dates preserved as UTC instants interpreted on the device. Exact original date strings remain in the archive. Transferring timezone-naive legacy files across timezones requires review of the original local timezone.
5. Maps become separate historical sessions. The old format did not reliably link maps to visits, so migration never invents that relationship. Every point preserves its coordinates, quantity, unit and Lot. Free-text materials are NOT merged by similar spelling. Imported historical materials are archived; the new default catalog is seeded separately.
6. Charges come from original visit totals. Payments retain their own paid_at. Known valid visit links create allocations up to the charge balance; overpayments remain unallocated credit. A zero legacy payment is retained in the lossless archive rather than turned into a positive receipt.
7. Images, signatures, appointments, templates, settings, custom procedure lists and unknown collection kinds are preserved as encrypted documents/archive records. Financial/clinical data unavailable in the old source is flagged unknown rather than invented. Archived full payloads retain hospital/team/equipment and all other legacy fields.
8. Row count and foreign_key_check are verified; only then is migration_complete committed. An interrupted/failed transaction leaves the old source intact and the destination uncommitted. Re-running after successful completion does nothing.
9. Future local reminders are reconciled against the migrated appointment IDs after notification initialization; failures keep the reschedule marker pending.

The legacy file and key are deliberately retained. Do not uninstall 0.1.1 or clear its data before an in-place update and an external password backup. Application ID and signing identity are preserved in the source. This migration reads an installed 0.1.1 database; it does not silently treat a v0.1 encrypted backup file as a v0.2 backup. Portable backup v2 import is a separate validated path.

Synthetic tests cover correct migration, raw record retention, precision failure rollback, unknown costs, historical maps, overpayment credit and idempotence. Actual patient data was not available and was not used. No finite test suite is an absolute guarantee against hardware/OS failures; device backup and acceptance testing remain necessary.
