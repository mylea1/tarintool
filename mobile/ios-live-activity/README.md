# Live Activity implementation status

This folder keeps the earlier reference implementation only. The production
Widget Extension is now part of `ios/Runner.xcodeproj` and its compiled sources
live in `ios/KiloLiveActivity/`. The Runner-side ActivityKit bridge is
`ios/Runner/KiloLiveActivityManager.swift`.

The extension uses an absolute rest end time, allowing iOS to update the lock
screen and Dynamic Island countdown without receiving one method-channel call
per second. Flutter remains authoritative for workout data.

For App Store signing, register the extension identifier
`com.kilostrength.kiloStrength.KiloLiveActivity` and provide an App Store
provisioning profile for both the Runner and extension targets in Codemagic.
