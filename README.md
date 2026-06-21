# SBB Departures

**Check your next train without breaking focus — Swiss departures, always one click away.**

A lightweight macOS menu bar app that shows live SBB departure times for any Swiss station. No browser tab, no phone, no context switch — just glance up, check the countdown, keep working.

---

## The Problem

You're deep in a task. Your train leaves in 12 minutes. To check if you need to leave now, you unlock your phone, open the SBB app, wait for it to load, search your station, read the result, and by the time you're back at your desk, you've broken your flow...

SBBDepartures puts departure countdowns in your menu bar. One look is enough.

---

## Who It's For

Developers, designers, and anyone who works from a Mac and commutes by Swiss public transport. If you've ever missed a train because you were hyperfocused and forgot to check, this is for you.

---

## Features

- **Departure countdowns** for any Swiss station, updated every 10 seconds
- **Stop-watchlist** to keep them ready for whenever you need it
- **Use live location** to automatically see the departures from your closer stop/station
- **Watch multiple lines** — configure the lines you use normally
- **Expand any line** to see all upcoming departures
- **Station Manager** — search and switch stations by name
- **Menu bar native** — no dock icon, no window clutter

---

## Screenshots

![SBBDepartures menu bar popover open on macOS](screenshots/Bildschirmfoto%202026-06-20%20um%2016.58.30.png)

| Menu Bar Popover | Watchlist Manager |
| --- | --- |
| ![Nearby departures in the compact menu bar popover](screenshots/Bildschirmfoto%202026-06-20%20um%2016.57.34.webp) | ![Watchlist manager with saved routes and next departures](screenshots/Bildschirmfoto%202026-06-20%20um%2016.57.52.webp) |

---

## Getting Started

### Requirements

- macOS 13 Ventura or later
- Xcode 15 or later
- Swift 5.9+

### Build & Run

```bash
git clone https://github.com/fernandoleyra/SBBDepartures.git
cd SBBDepartures
open SBBDepartures.xcodeproj
```

Then in Xcode: select the **SBBDepartures** scheme → press `⌘R`.

The app appears in your menu bar. Click the red SBB icon to see live departures.

### First Launch

1. Click the menu bar icon
2. Open **Station Manager** (bottom of the popover)
3. Search for your station
4. Select the lines you want to watch
5. Done — countdowns start immediately

---

## Project Structure

```
SBBDepartures/
├── App/
│   ├── SBBDeparturesApp.swift       # App entry point, window scene setup
│   ├── DeparturesAppState.swift     # Core state — polling, station selection
│   ├── MenuBarPopoverView.swift     # Popover UI shown on menu bar click
│   ├── ManagementWindowView.swift   # Station Manager window
│   ├── WatchedLinesSection.swift    # Expandable line rows inside the popover
│   └── SBBStyle.swift               # Design tokens — colors, typography
├── Shared/
│   ├── TransportAPI.swift           # SBB Open Data API client
│   ├── Models.swift                 # Departure, Station, Line data models
│   ├── SharedStore.swift            # Persistence — UserDefaults-backed store
│   ├── NotificationService.swift    # Departure reminders
│   └── DateFormatting.swift         # Countdown and time display helpers
└── Widget/
    └── DeparturesWidget.swift       # macOS widget extension
```

---

## API

Uses the [Swiss public transport Open Data API](https://transport.opendata.ch) — no key required, no account needed.

---

## License

MIT
