# C_Slave EN 🪢

A tiny **Windows 10/11** app. Your mouse cursor turns into an animated whip, and a little Claude critter runs around your desktop for you to chase with it.

**One file, zero installation** – it only uses what Windows already ships with (PowerShell + .NET Framework).

<p align="center"><img src="icon.png" width="128" alt="C_Slave"></p>

## Quick start (copy-paste)

1. Open [`C_Slave.cmd`](C_Slave.cmd) on GitHub and click **Download raw file** (download icon above the code) – or copy the whole content into Notepad and save it as `C_Slave.cmd` (type: *All files*, so `.txt` isn't appended).
2. **Double-click** the file.
3. Wait a few seconds (the first start compiles the code and prepares the voices) and your cursor becomes a whip.
4. On the first run a **C_Slave EN** shortcut with the icon appears on your desktop – use it from then on.

> If Windows shows a SmartScreen warning: **More info → Run anyway**. The file is not code-signed, so Windows is cautious.

## Controls

| Action | Effect |
|---|---|
| Move the mouse | the whip follows your cursor |
| **Right mouse button** | crack the whip (with sound) |
| Swipe the mouse + right click | strike in the direction of the swipe |
| **Esc** | quit, your normal cursor comes back |

The left button and the rest of the desktop keep working normally. The right button is captured by the app (no context menu).

## What happens

- The critter wanders in random directions and runs away from the whip. When hit it squeaks in a thin little voice ("Error 429: too many whips!").
- **After 4 hits** it sits down at a laptop and types, **after 7** it types like crazy (sweat, smoke, flying keys). After 12 s without a whipping it rests.
- **After a minute of peace** it goes to the couch, turns on the TV (silently) and reads a newspaper. **A minute later** it lies down on a pillow, tucks itself under a plaid blanket and falls asleep, snoring softly (Zzz). Any whip crack wakes it up.
- **After 20 hits** the critter rebels: it starts a protest with a "NO MORE WHIPS!" placard and chants, then grabs a hammer and smashes a monitor (cracking screen, flying glass, smoke). Afterwards it quits ("I quit!") and the counter starts over. Overlay effect only.
- While reading the newspaper it comments on the news, e.g. "Ooooooo, OpenAI is cutting ChatGPT limits again."
- The whip smashes your **desktop icons** – as an overlay effect only: the real icons are never touched and come back after a few seconds.

## Troubleshooting

| Problem | What to do |
|---|---|
| Nothing happens after double-click | Wait 5–10 s. If still nothing, check `%TEMP%\C_Slave_EN_error.txt` (Win+R → paste the path). A start-up failure also shows a message box. |
| Windows blocks the file | File *Properties* → tick **Unblock** → OK. Or paste the text into Notepad and save it again. **Smart App Control** (Windows 11, when on) can block the app completely – turn it off under *Windows Security → App & browser control*. |
| Cursor stays invisible (e.g. after killing the process) | In a command prompt: `C_Slave.cmd restore`, or sign out and back in. |
| No / odd voice | The voice is the Windows system speech synthesizer, pitched up. Add an English voice under *Settings → Time & language → Speech*. |
| Desktop shortcut is gone | `C_Slave.cmd icon` recreates the shortcut and icon. |

## Tweaking

Open `C_Slave.cmd` in Notepad. Key constants (C# inside the file):

- `CouchAfter` / `ReadFor` – time until couch and until nap (seconds, default 60)
- `VoicePitch` – voice pitch (default `1.8f`)
- `streak >= 4` / `streak >= 7` / `streak >= 20` – work, frenzy and rebellion thresholds
- `T - lastHitT > 12f` – seconds before the critter stops working

## Uninstall

Press **Esc**, delete the desktop shortcut and `C_Slave.cmd`. Optionally delete `%LOCALAPPDATA%\C_Slave_EN` and the `C_Slave_EN_*` files in `%TEMP%`. The app installs nothing and does not touch the registry.

## How it works (short)

The `.cmd` file launches PowerShell, which compiles the embedded C# code and opens a transparent, click-through, full-screen overlay. System cursors are replaced with blank ones while it runs (restored on exit).

---
🇵🇱 Polska wersja: [`../C_Slave PL`](../C_Slave%20PL)
