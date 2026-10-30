# SafeLoop (Flutter)

AI-powered women's journey safety app with adaptive check-ins, discreet distress PIN, trusted contacts, and emergency escalation. Converted from Kotlin / Jetpack Compose to high-performance Flutter.

---

## 🌟 Key Features

1. **Intelligent Protected Journeys**
   - Start transit monitoring across multiple transport modes (Cab, Auto/Rickshaw, Walking, Bus, Metro).
   - Real-time GPS telemetry simulation, speed metrics, geofence protection corridor, and arrival calculations.

2. **Adaptive Safety Check-Ins**
   - Scheduled check-in interval countdowns (5 to 30 min) based on transit mode and speed.
   - Gesture-based swipe confirmations ("Swipe right to confirm safe").

3. **Discreet Duress PIN (Covert Distress)**
   - Normal Safety PIN (`1234`) confirms routine safety and resets the check-in timer.
   - Duress PIN (`9999`) provides silent duress protection: visually confirms safety to deceive an attacker while covertly dispatching high-priority distress alerts and live GPS tracking to trusted contacts.

4. **Automated Escalation Protocol**
   - 45-second amber grace period if a check-in is missed.
   - Automatic escalation to trusted circle if not cancelled with PIN.

5. **Instant Emergency SOS**
   - Hold SOS button for 3 seconds or tap Quick Distress to trigger full-scale emergency mode.
   - Real-time contact notification delivery states (*Sending*, *Delivered*, *Acknowledged*).
   - Quick emergency dialing for Police (112) and primary trusted contact.
   - Security PIN disarm verification (supports covert distress continuation).

6. **Interactive Telemetry Map Canvas**
   - Custom-painted vector city road network, Bezier transit route curve, start/destination pins, dynamic speed readout, and pulsing GPS beacon.
   - Fallback indicators for cellular network loss (Mesh SMS fallback) and history route replays.

7. **Trusted Emergency Circle**
   - Manage emergency contacts with relationships and primary contact badges.
   - Preview of encrypted SMS broadcast template dispatched during emergency escalation.

8. **Safety & Audit History**
   - Dual-tab record of past protected journeys with route replay and security event logs.

9. **Interactive Demo Scenario Runner**
   - Quick switcher modal (accessible via beaker icon) to test 7 real-time emergency scenarios on demand:
     1. Normal Protected Journey
     2. Trigger Safety Check-In
     3. Test Discreet Duress PIN (`9999`)
     4. Missed Check-In & Escalation
     5. Instant Emergency SOS
     6. Safe Destination Reached
     7. Simulate Cellular Network Loss / Reconnect

---

## 📁 Project Architecture

```
lib/
├── models/
│   └── models.dart                 # Data classes: Journey, TrustedContact, UserProfile, SafetyEvent
├── theme/
│   ├── app_colors.dart             # Midnight Navy & Electric Lavender color design tokens
│   └── app_theme.dart              # Material 3 light and dark theme configurations
├── state/
│   └── safeloop_state.dart         # Core business logic, timers, duress state, and scenario runner
├── widgets/
│   ├── interactive_map_canvas.dart # Custom vector road grid & route bezier painter
│   ├── breathing_glow_card.dart    # 60fps pulsating gradient card
│   ├── swipe_action_control.dart   # Interactive swipe-to-confirm slider
│   ├── numeric_pin_pad.dart        # 4-digit PIN pad with biometric & error feedback
│   ├── scenario_selector_sheet.dart# Demo scenario switcher modal
│   └── safeloop_bottom_bar.dart    # Floating navigation bar
├── screens/
│   ├── onboarding_screen.dart      # 4-step onboarding carousel with feature highlights
│   ├── security_setup_screen.dart  # 3-step profile, PIN, and permission setup
│   ├── home_screen.dart            # Main dashboard with live status, maps, and circle
│   ├── journey_setup_screen.dart   # Transit planner with duration, geofence, and mode
│   ├── active_journey_screen.dart  # Active transit monitor with map, timer, SOS & end slider
│   ├── check_in_modal_screen.dart  # "Are you safe right now?" swipe & PIN verification
│   ├── escalation_warning_screen.dart # 45-second amber grace countdown
│   ├── emergency_screen.dart       # High-contrast SOS broadcast with contacts delivery
│   ├── journey_completion_screen.dart # Safe arrival celebration
│   ├── contacts_screen.dart        # Trusted circle management & SMS template
│   ├── safety_history_screen.dart  # Replay past journeys & security event logs
│   └── settings_screen.dart        # PINs, adaptive guardian parameters & dark mode
└── main.dart                       # App entrypoint and reactive navigation scaffold
```

---

## 🚀 Running the App

### Prerequisites
- Flutter SDK (3.13+)
- Dart SDK (3.0+)

### Commands
```bash
# Get dependencies
flutter pub get

# Run on emulator, device, or desktop
flutter run

# Run unit tests
flutter test
```
