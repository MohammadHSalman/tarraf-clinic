# Database architecture and invariants

Canonical DDL: lib/data/schema.dart. Generated equivalent: docs/schema.sql. All application tables use STRICT typing. SQLite/SQLCipher must support STRICT (SQLite >=3.37); failure is explicit, never a fallback to weaker/plaintext storage. Every connection enables foreign_keys; WAL is encrypted by SQLCipher.

## Relationships

patients → sessions → session_materials → injection_points.
materials → material_versions; materials → material_batches.
session_materials references both version/material and batch/material using composite FKs, preventing mismatched materials/batches.
sessions → charges; patients → payments; payment_allocations links payments and charges.

All primary entity IDs, including internal metadata IDs, are UUID TEXT. Administrative app_meta.key is a unique lookup value, not a reference key. Migration/audit metadata retain legacy IDs only for provenance, never as clinical FKs.

materials.current_version_id identifies the current immutable version; created_at is not used to guess it. Initial material insertion and version/pointer update occur in the same transaction. Renaming/repricing creates a new version. Archive toggles is_archived; no historical versions are deleted. Version rows reject UPDATE and DELETE.

## Exact quantities and finance

Money is INTEGER minor units in the single selected currency. Decimal parsing uses BigInt before range checks, never double. Precision 0–6 is configured explicitly once. Maximum stored monetary value is 900000000000000 minor units. Units/CC quantities are INTEGER milli-units (scale 1000), and drawing coordinates alone are REAL in [0,1].

Consumption cost = round_half_up(sum(point milli-quantities) * version.unit_cost_minor / 1000), once per session-material/version/batch line. BigInt checks precede multiplication; SQLite approval guards independently check totals and overflow. Materials from different product formulations are never automatically unit-converted.

Seeded catalog costs are UNKNOWN until configured. A zero explicitly entered by the doctor is distinct from an unknown cost. Old visits have cost_unresolved=1 because the original application did not record complete material consumption/cost. Unknown quantities use unit Unknown only in archived legacy material versions; no guessing of Units vs CC.

## Transactions and edit rules

savePoint/deletePoint: compare expected session revision, mutate point/batch/usage, recalculate quantities and cost, append encrypted audit entry, COMMIT. Any exception rolls back all steps, including revision increments. Repository calls only the transaction executor inside a transaction.

Drafts can be edited. Approval checks charges, known costs, point aggregates and cost arithmetic. Final/legacy dates and clinical values are immutable; revision timestamps do not replace performed_at. Draft deletion removes charges first, then session and cascading usage/points. Approved sessions are cancelled without deletion; live allocated payments must be voided first. Payments and allocations are immutable; corrections use void-and-replace, and historical allocations remain recorded.

Allocation guards enforce matching patients, approved active sessions, payment total ceiling and charge balance ceiling. Financial reports pre-aggregate fees, material costs and allocations before joins, avoiding cross-product duplication.

## Report semantics

Accrual uses performed_at >= from AND < until, independent of receipt date. Cash uses paid_at with the same half-open bounds, independent of session date. UI date selection constructs next local midnight before converting to UTC, avoiding 24-hour/DST assumptions.

Without procedure/status filters, each whole non-voided payment is counted once. With those filters, cash includes matching allocated portions only. Unallocated receipts remain a separate whole-period indicator. Payment-status filters use CURRENT settlement state, not an as-of historical balance. Margins are incomplete when historical costs are unknown. This is fees less material costs, not clinic net profit after all operating expenses.

## Encryption

SQLCipher protects the complete on-disk relational database, its money columns and WAL. SQLCipher page encryption is distinct from AES-GCM; it is not described as GCM. The application additionally seals patient payloads, clinical notes, photos, consents, audit payloads and legacy archives with AES-256-GCM. Record-specific AAD prevents substitution across IDs. Independent random device keys reside in FlutterSecureStorage.

Portable backups are PBKDF2-HMAC-SHA256 (600000 iterations, random salt) + AES-256-GCM. The field key is carried only INSIDE the password-authenticated envelope. Restore verifies in a separate encrypted database, re-encrypts field payloads with the receiving device key, validates FKs and allocations, retains voided history, then atomically replaces the active file after checkpoint/close. An encrypted pre-restore copy is retained. File activation, Android keystore and power-loss behavior need device acceptance tests.
