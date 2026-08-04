# KILO Live Activity extension sources

These Swift files are intentionally kept outside the generated Runner target so
Windows CI can build Android without pretending to run Xcode. Add them to a
Widget Extension target named `KiloLiveActivity` on macOS, enable **Live
Activities** and **App Groups**, and select `group.com.kilostrength` for both
the Runner and extension targets.

The compact, minimal, expanded Dynamic Island regions and lock-screen view are
all defined in `KiloLiveActivityWidget.swift`. `KiloTimerIntents.swift` exposes
pause, skip-rest and finish-workout actions. The App Group dictionary is the
only shared payload; Flutter state remains authoritative and the extension never
reads Flutter memory.

The Flutter `MethodChannel('kilo.platform.timer')` is the cross-platform bridge.
On iOS it is safe to no-op when ActivityKit is unavailable (iOS < 16.1), while
Android falls back to an ordinary notification channel.
