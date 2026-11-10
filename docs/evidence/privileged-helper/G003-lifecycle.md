# G003 lifecycle verification

2026-09-27, current development Mac. This records source/unit and read-only host evidence; it does not establish signed installation or descendant cleanup after a real daemon termination.

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'ProductionHelperLifecycleTests|P02|J25|J23'`: 43 tests passed before composition/inventory follow-up.
- Follow-up `swift test --filter ProductionHelperLifecycleTests`: 9 tests passed, including normal launch composition, persisted receipts, asynchronous removal ambiguity, disconnected removal, build-specific update evidence, process-name fallback, and current executable presence.
- Read-only host probe executed the exact `HelperProcessInventory` enum extracted from `Services/ProductionHelperLifecycle.swift` under the installed Swift toolchain. Output:

```text
currentPathAvailable=true
currentExecutableAbsent=false
impossibleHelperAbsent=true
```

The impossible helper path was `/nonexistent/watt-inventory-probe/WattHelper`. The current executable path came from `proc_pidpath(getpid())`. Inventory enumerates at most 32,767 PIDs with a 128-entry margin and rejects saturated/truncated enumeration. A missing executable path falls back to `proc_name`: known unrelated process names may be skipped; missing/ambiguous names and either `WattHelper` or `powermetrics` prevent proof of absence. Any `/usr/bin/powermetrics` blocks proof conservatively without attributing ownership. No process is spawned, signalled, or removed by the inventory.

Production removal still requires awaited ServiceManagement unregister completion, persisted receipt state, absent registration, and the separate read-only process inventory. Actual signed helper removal, OS ownership semantics, and kill-mid-sample descendant cleanup remain installed-host verification gates.
