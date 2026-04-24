# CloudKit Sync (Phase 5)

Optional end-to-end encrypted sync across the user's own Apple devices.
Uses the private CloudKit database so data is only readable by iCloud
accounts that already belong to the user — no BA6 server involvement.

Design notes:

- Mirror only `conversations`, `messages`, and pinned `memories`.
  Don't sync raw embeddings or full `memories` rows — regenerate them
  locally from the messages each device sees.
- Use `CKSyncEngine` (iOS 17+) for state management.
- `DeviceIdentity` key stays local — never synced. Each device has its
  own identity, all tied to the same iCloud account.
