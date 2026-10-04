<div align="center">

<img src=".github/assets/micro-breaks.gif" alt="Kaskas — the flame mascot reminding you to take a micro-break" width="860" />

<br/>

<img src=".github/assets/icon.png" width="94" alt="Kaskas app icon" />

# Kaskas

A free, open source break reminder and focus tracker for macOS.<br/>
Rest your eyes and stay productive. Kaskas lives in your menu bar, tracks your study time and reminds you to rest before you burn out.

<br/>

<p>
  <a href="https://github.com/ramazanberkozbek/kaskas/releases/latest"><img alt="Download DMG" src="https://img.shields.io/badge/Download-DMG-007AFF?style=flat&logo=apple&logoColor=white" /></a>
  <img alt="macOS 15+" src="https://img.shields.io/badge/macOS-15%2B-000000?style=flat&logo=apple&logoColor=white" />
  <img alt="Swift" src="https://img.shields.io/badge/Swift-SwiftUI-F05138?style=flat&logo=swift&logoColor=white" />
  <img alt="License GPLv2" src="https://img.shields.io/badge/License-GPLv2-C2410C?style=flat&logo=gnu&logoColor=white" />
  <img alt="Languages" src="https://img.shields.io/badge/Languages-EN%20%C2%B7%20TR-4C9A2A?style=flat" />
  <a href="https://github.com/ramazanberkozbek/kaskas/stargazers"><img alt="Stars" src="https://img.shields.io/github/stars/ramazanberkozbek/kaskas?style=flat&color=34C8F5&labelColor=181717&logo=github" /></a>
</p>

<br/>

<img src=".github/assets/break-screen.gif" width="860" alt="Kaskas full-screen break: look away and rest, with snooze, skip and lock screen controls" />

<sub><b>Break screen</b> &nbsp;·&nbsp; a calm full-screen pause every 45 minutes</sub>

<br/>
<br/>

<img src=".github/assets/micro-reminder.gif" width="420" alt="Kaskas micro-break reminder: the flame mascot asks you to take a breath" />
<img src=".github/assets/break-warning.gif" width="420" alt="Kaskas break warning with a countdown and snooze options" />

<sub><b>Micro-break reminder</b> &nbsp;·&nbsp; <b>Break warning</b></sub>

<br/>
<br/>

<img src=".github/assets/dashboard.png" width="420" alt="Kaskas dashboard: today's study hours compared with yesterday" />
<img src=".github/assets/dashboard-sessions.png" width="420" alt="Kaskas study sessions with automatic categories" />

<sub><b>Dashboard</b> &nbsp;·&nbsp; <b>Study sessions</b></sub>

<br/>
<br/>

<img src=".github/assets/statistics.png" width="420" alt="Kaskas statistics: time by app and time by category" />
<img src=".github/assets/focus-settings.png" width="420" alt="Kaskas focus settings: break wallpaper and layout" />

<sub><b>Statistics</b> &nbsp;·&nbsp; <b>Focus settings</b></sub>

</div>

## What it does

<table>
<tr>
<td width="50%" valign="top">

### Breaks

- A **full-screen break** every 45 minutes, so you actually step away
- A tiny **micro-break reminder** every 20 minutes: the flame mascot
  asks you to blink, breathe and relax your shoulders
- A **warning** a few seconds before each break, with +1, +5 or +15 min
- **Snooze**, **skip** with `esc`, or **lock the screen** from the break
- **Long breaks** after a set number of short ones
- A gentle nudge when you've **skipped** too many breaks in a row

</td>
<td width="50%" valign="top">

### Focus tracking

- Tracks your **study time** quietly from the menu bar
- A **dashboard** that puts today and yesterday on the same timeline
- **Study sessions** with notes and an automatic category
- **Statistics** by app and by category, for a day, 7 or 30 days
- **Hourly focus**, time distribution and a **yearly activity heatmap**
- See how much time went to study, breaks, meetings and sleep

</td>
</tr>
<tr>
<td width="50%" valign="top">

### Smart, not annoying

- **Meeting protection**: breaks wait while your mic or camera is in use
- **Idle detection**: walk away and Kaskas pauses, then offers to log
  the time as a break
- Survives **sleep, wake and relaunch** without losing your timer
- **Categories** (coding, writing, design, browsing...) assigned per app,
  with your own rules and custom categories

</td>
<td width="50%" valign="top">

### Make it yours

- Break **wallpapers**: mountain lake, snowy peaks, northern lights,
  desert dunes, deep space, ocean, or **your own photo**
- Two **break layouts**: Horizon and Gentle Bar
- **Start and end sounds** for every break
- Flame mascot in **eight colors**
- Menu bar shows **icon, timer or both**, and the Dock icon is optional
- Every duration is adjustable, plus **launch at login**
- **English and Turkish**, light and dark mode

</td>
</tr>
</table>

## Why Kaskas

Long study and coding sessions are hard on your eyes, your neck and your
focus. Kaskas follows the idea behind the 20-20-20 rule: every 20 minutes a
short reminder to look away, and every 45 minutes a real break. It is built
with native SwiftUI and AppKit, so it feels like part of macOS rather than
another app fighting for your attention.

## Installation

1. Download **[Kaskas.dmg](https://github.com/ramazanberkozbek/kaskas/releases/latest/download/Kaskas.dmg)** (or browse [all releases](https://github.com/ramazanberkozbek/kaskas/releases)).
2. Open the DMG and drag **Kaskas** into your **Applications** folder.
3. Open Kaskas and enjoy healthy breaks.

## Build from source

Kaskas runs on **macOS 15 Sequoia or later**.

```bash
git clone https://github.com/ramazanberkozbek/kaskas.git
cd kaskas
open Kaskas.xcodeproj
```

Then pick the `Kaskas` scheme in Xcode and press <kbd>⌘</kbd> <kbd>R</kbd>.

## Privacy

No account, no ads, no analytics and no backend. Kaskas is sandboxed and
everything it records (sessions, app usage and settings) stays on your Mac.
Meeting protection only checks *whether* the microphone or camera is in use;
audio and video are never recorded.

## Contributing

Bug reports, ideas and pull requests are welcome. For anything big, please
open an issue first so we can talk it through.

## License

The code is licensed under the [GNU General Public License v2.0](LICENSE).
The break wallpapers come from [Unsplash](https://unsplash.com/license);
[PhotoCredits.md](Artwork/PhotoCredits.md) lists every photographer.

## Star history

<a href="https://www.star-history.com/#ramazanberkozbek/kaskas&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=ramazanberkozbek/kaskas&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=ramazanberkozbek/kaskas&type=Date" />
   <img alt="Kaskas star history chart" src="https://api.star-history.com/svg?repos=ramazanberkozbek/kaskas&type=Date" />
 </picture>
</a>
