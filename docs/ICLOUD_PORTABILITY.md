# Optional iCloud portability

Implemented September 10, 2026 on `codex/magiccuts-pro-instruments`. This follow-up supports the user's existing Apple Account and keeps MagicCuts free of an owner-operated backend. It is a development implementation, not a claim of production or two-device CloudKit acceptance.

## User contract

Sync is off by default on each installation. Enabling it merges saved sessions, baselines, workflows, groups, field reports and Bluetooth setup references with the user's private iCloud library. These include saved source metadata, readings, marks, notes and original Bluetooth test history. Edits and deletions sync. Turning it off keeps both copies; it does not delete an iCloud library. Local measurement, saving and exports continue independently.

There is no MagicCuts registration, password, account service, server, analytics collector, paid sync SDK or custom push provider. The app uses StoreKit for purchase restoration and CloudKit for optional data portability; those are separate Apple services. Normal Apple developer membership, app/schema maintenance and user support remain. Support does not receive library data unless a user explicitly shares it.

| State | Behavior |
|---|---|
| Never enabled | No CloudKit client creation or Apple Account lookup by the sync component. |
| Enabled, same account | Save locally first; Apple schedules uploads/downloads. Sync now requests a fetch then send. |
| Offline, quota full, temporarily unavailable | Keep local data and show recovery text. Pending revisions remain durable; retry when the service is available. |
| Disabled | Stop scheduling and cancel current operations. Keep local and cloud copies; a request already accepted by Apple may already have completed. |
| Account signed out or changed | Disable sync and preserve local copies. Enabling again explicitly may merge those copies into the selected account. |
| Restored device backup or new installation | Excluded installation identity and paired local preference prevent inherited opt-in. Hardware evidence needs fresh validation. |
| Record or zone removed outside the app | Pause/off with an explanation. Do not silently recreate deleted cloud contents. An explicit re-enable uploads retained local data again. |
| Invalid or newer record format | Keep existing evidence; show update/retry guidance. |

## Data and hardware boundaries

Saved records include original provenance. Baselines from another installation can be inspected but cannot drive live comparison until recaptured locally. Bluetooth references carry original thresholds and history; they do not recreate a CoreBluetooth connection or select a peripheral by advertised name. The user identifies and saves hardware on the current device, then explicitly connects the reference. Workflows resolve the local radio identity; groups use its current threshold. Missing connections remain unavailable/unknown. Tests in the destination setup remain necessary before relying on a result.

Permissions, App Store entitlements, iCloud consent, selected live instrument, in-progress recordings, recovery drafts, local Bluetooth connections and Shortcut confirmations are excluded from cloud records. An ordinary OS device backup is separate from this app-controlled sync. The installation UUID and CloudKit checkpoints are excluded from that backup. Restored SwiftData setups receive a new portability ID and validation-reset timestamp; the previous reference remains historical evidence.

## Implementation

`InstrumentArchive` continues to own the coordinated local index and sample files. Each saved item gets a Lamport counter plus installation/revision UUIDs. Concurrent edits to different items merge; concurrent edits to the same item resolve deterministically by revision order. This is item-level resolution, not collaborative field merging. A deletion receipt wins over a stale/offline edit and prevents resurrection of that item ID. Users must create a new item to keep a later copy.

CloudKit stores one record per item. `CKSyncEngine` handles system scheduling and subscriptions; the app persists engine state and saved record system fields, tracks acknowledged revisions, and sends at most 16 items per batch. Custom sample/report payloads use `CKAsset` files. There is no CloudKit public database or sharing feature. SwiftData configurations explicitly use `cloudKitDatabase: .none` so enabling the entitlement does not silently mirror the legacy device model.

Incoming payloads validate before local mutation. A report may arrive before its attached sessions. The editor retains unavailable attachment IDs and requires either a completed download or deliberate removal before saving. A remotely deleted session's bytes remain while a local report still references them; removing that attachment permits cleanup. Relevant sync changes invalidate an already prepared export so it cannot be shared as an up-to-date report.

| CloudKit configuration | Value |
|---|---|
| Container | `iCloud.com.bradZellman.MagicCuts` |
| Database | Private |
| Custom zone | `MagicCutsLibrary` |
| Record type | `LibraryItem` |
| Record name | Kind plus UUID, for example `session:<UUID>` |
| `format` | Int64, currently `1` |
| `revision` | Bytes containing the encoded `LibraryVersion` |
| `payload` | Asset containing JSON; absent for deletion receipts |
| Capabilities | CloudKit, push notifications, remote-notification background mode |

## Validation and release acceptance

The portable result receipt is [icloud-evidence.json](validation/icloud-evidence.json); UI captures are in [screenshots/icloud](screenshots/icloud/README.md). Automated tests exchange real encoded library records between separate local archives. UI tests use a deliberately unavailable account reader and labeled fixture data. They do not upload to the developer's personal Apple Account.

The signed development app and its Apple-generated provisioning profile include the exact CloudKit container and push entitlement. Signature/provisioning success proves build configuration, not network synchronization. The existing [Pro validation](PRO_VALIDATION.md) still governs sensors, StoreKit and physical Shortcuts acceptance.

| Check | Result and scope |
|---|---|
| Unit regression | 47 pass, including 15 portability tests and the original measurement, storage, report and proximity checks. Local record exchange, account/consent isolation, conflict/deletion, delayed report attachments and restored hardware validation are covered. |
| iPhone UI | Five selected journeys pass: default off/account unavailable, explicit Bluetooth reference connection/group run, largest text/accessibility, baseline/record/export/report, and workflow create/run. |
| iPad UI | Two journeys pass: largest-text settings/navigation and retained device threshold/history. The tablet settings capture includes the initial scroll position; the test scrolls to and opens Bluetooth references afterward. |
| Builds | Release app/extension and signed Debug device build pass with no application warnings. The final test harness also compiles with a fail-fast fixture check. |
| SDK diagnostics | A clean iPad test compile emits an Apple StoreKitTest header deprecation for `SKPaymentTransactionState`; app source does not use that type. The Apple SDK is unchanged and compiler warnings are not suppressed. |
| Live CloudKit | Not verified. No personal account was enrolled in sync. Signing and local archive exchange do not establish server or recipient-device acceptance. |

Earlier UI runs failed because a switch query tapped its label, a back button was ambiguous, or Xcode's first app launch lacked the fixture arguments. The harness now taps the actual switch, scopes the navigation bar, and requires the Sample session marker before account interaction. Only the corrected passing results are used as success evidence; the earlier failing runs are not represented as green. StoreKit commerce was not rerun for this change; the prior verified local lifecycle result remains separately scoped in Pro validation.

Before releasing this feature:

1. Use two authorized test devices/installations with the same test Apple Account and explicitly enable sync on each. Confirm first upload/download, offline edits, deletion, relaunch, error recovery, disable/re-enable, account switch and Bluetooth re-identification. Compare saved reading bytes and notes on the recipient, not only a successful status label.
2. Inspect the development schema above and deploy it to Production in CloudKit Console. Verify the production schema and TestFlight behavior before App Store release. Automatic development signing does not perform this deployment.
3. Update and verify the public privacy policy and App Store privacy answers for optional private iCloud storage. The current public policy could not be verified from this environment (HTTP 403); repository disclosure has been updated.

Apple references checked September 10, 2026: [CKSyncEngine documentation](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5), [Apple's CKSyncEngine sample](https://github.com/apple/sample-cloudkit-sync-engine), [system scheduling and account changes](https://developer.apple.com/videos/play/wwdc2023/10188/), [development-to-production schema deployment](https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema), and [CoreBluetooth peer identity](https://developer.apple.com/documentation/corebluetooth/cbpeer/identifier).
