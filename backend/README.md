# backend

Reserved for the MemoryMitra sync service (FastAPI). Nothing here yet.

The Flutter app is offline-first and fully functional without it: every user
action is written to a local Hive box and recorded in a durable outbox. This
service will become the destination for that outbox.

When it lands, the only Flutter-side change is a new implementation of
`SyncTransport` (`frontend/lib/core/services/sync_manager.dart`) — a single
`send(PendingOperation)` method. Nothing else in the app is aware of the
network.

See the "Offline-first persistence" section of the root `README.md` for the
queue's shape and the payloads each operation carries.
