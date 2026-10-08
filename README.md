# Signal Radar

Flutter Android app: radar view of nearby Wi-Fi APs, BLE devices and (optionally) LAN hosts,
with heuristic detection of possible surveillance cameras and item trackers. Storage is JSON only.

## Build
Push to GitHub, add the repo in Codemagic (Flutter App, use codemagic.yaml), start the build,
download the APK from Artifacts.

Extend `assets/oui_db.json` with more vendor MAC prefixes and name patterns.
