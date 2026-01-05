# RSG Scoreboard

This is a Scoreboard that will show your players First and Last name, Job, and the Citizens ID.  
It also shows how many Lawmen and Medics you have on-duty.  
To be able to see the scoreboard use the command `/scoreboard`.

## Authors

- Original Author: [@iinsanegaming](https://www.github.com/iinsanegaming)

## Screenshots

![image](https://github.com/user-attachments/assets/83d94782-08ed-4e01-af48-baf42e52b0b0)

---

> ⚠️ **Fork Notice**  
> This project is a **modified fork** of the original **RSG Scoreboard** by  
> [@iinsanegaming](https://github.com/iinsanegaming).  
>  
> The original concept and foundation remain credited to the original author.  
> This fork focuses on **performance, UX, and government-roleplay integration**.

![Forked from RSG Scoreboard](https://img.shields.io/badge/forked%20from-RSG%20Scoreboard-blue)

---

## Summary of Changes

### Input & Controls
- Removed `/scoreboard` command dependency
- Scoreboard is now toggled using **PGDN**
- Removed **Backspace** and **ESC** closing behavior
- No cursor or NUI focus stealing

### UI / UX Improvements
- Smooth **fade-in / fade-out animation**
- Sidebar rebuilt dynamically for robustness
- Pulse animation on value changes only
- Clean, minimal layout with no key spam
- Fully passive UI (display-only, no client logic)

### Data Handling
- Server-authoritative updates
- Client forwards payloads **as-is**
- Auto-refresh every **10 seconds only while visible**
- Defensive rendering (sanitized values, safe fallbacks)

### Role Counts
- Lawmen count
- Medic count
- Governor count (added)
- Total player count

### In-Game Clock (New)
- Real-time in-game date and time
- 12-hour format with AM/PM
- Example format: Monday May 12, 1899 2:30 PM


### Performance & Stability
- No continuous tick spam
- No forced key listeners in NUI
- Safe fade fallback if transition events fail
- Prevents duplicate show/hide calls

---

## Technical Overview

### Client (`scoreboard/client.lua`)
- PGDN toggle
- No NUI focus
- Event-driven updates
- Optional auto-refresh
- Dedicated in-game clock thread

### NUI (`html/script.js`)
- Minimal DOM updates
- No input listeners
- Fade animation handling
- Defensive rendering
- Modular sidebar creation

---

## Design Philosophy

- **Non-intrusive UI**
- **Low performance cost**
- **Framework-compatible**
- **Government RP ready**
- **Server-authoritative by design**

This version is intended for servers using:
- `rsg-core`
- `rsg-governor`
- `rsg-residency`
- `rsg-economy`

---

## Notes

- This resource does **not** include administrative controls
- Intended as a **read-only scoreboard**
- Safe for long RP sessions and large player counts

---

## License & Credit

All original work is credited to **@iinsanegaming**.  
This modified version is shared with respect to the original creator and is intended as an **enhanced fork**, not a replacement.

---

If you wish to:
- Add region-based sections
- Show governor names per region
- Add treasury or tax readouts
- Provide a compact/minimal mode

those can be layered on **without rewriting** this scoreboard.


# Changelog

All notable changes to this project are documented in this file.

This project is a **modified fork** of the original RSG Scoreboard by
[@iinsanegaming](https://github.com/iinsanegaming).

---

## [1.1.0] – Government-Compatible Update
### Added
- PGDN key toggle for scoreboard visibility
- Governor count support
- Real-time in-game date and clock display
- Fade-in / fade-out UI transitions
- Auto-refresh while scoreboard is visible

### Changed
- Removed `/scoreboard` command dependency
- Removed ESC and Backspace closing behavior
- UI is now fully passive (no NUI focus or cursor)
- Client now forwards server payloads as-is
- Sidebar is dynamically generated for robustness

### Removed
- Client-side input listeners in NUI
- Forced UI focus behavior
- Continuous tick-based refresh spam

### Performance
- Reduced client tick usage
- Safe UI state handling
- Defensive rendering for missing or malformed data

---

## [1.0.0] – Original Release
- Initial release by @iinsanegaming
- Player list scoreboard
- Job and duty counts
- Command-based toggle

## my screenshot

<img width="319" height="329" alt="scoreboard" src="https://github.com/user-attachments/assets/33193cbd-c626-4ef9-888c-9403d429f790" />
