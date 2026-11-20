# Claude companion for the Dragon's Dogma 2 Trainer by RipXic

An **optional** add-on for the [Dragon's Dogma 2 Trainer by RipXic](https://www.nexusmods.com/dragonsdogma2/mods/2703) (Nexus Mods). The trainer works fully without it. Run it next to the game and you get two extra things:

- **Automatic save backups.** Before the trainer changes something that is saved with your game (level, vocation ranks, stats, NPC affinity), your Steam save folder is copied to `Documents\DD2 Trainer save backups`. It makes at most one backup every 10 minutes and keeps the newest 40. You can also click **Back up my save now** on the trainer's Automation page. **This part does not need Claude.**
- **Ask Claude.** On the trainer's **Ask Claude** page, type a question such as "why do my pawns keep dying?" or "best augments for my Magick Archer". Claude sees your live character and the trainer's settings and answers in the panel. If it suggests a settings change, you see the code first. It only runs when you click **Do it**, and it goes into the trainer's Undo list.

It is two small scripts (PowerShell + a .bat launcher), not an exe. You can open both and read every line.

> **Claude is not included and is not free.**
> This companion is free, but **Ask Claude** only works if you have the **Claude desktop app** signed in with **your own paid Claude subscription**. Every question uses your own plan. This download does not give you Claude, a Claude account or any Claude usage. Save backups work without it.

## What you need

- Dragon's Dogma 2 (Steam, PC) with [REFramework](https://www.nexusmods.com/dragonsdogma2/mods/8) and the [Dragon's Dogma 2 Trainer by RipXic](https://www.nexusmods.com/dragonsdogma2/mods/2703) installed.
- Windows 10 or 11. Windows PowerShell comes with Windows, so there is nothing to install for backups.
- For **Ask Claude** only: the **Claude desktop app** (https://claude.ai/download), installed and signed in with your own paid Claude subscription. The companion uses the Claude Code that comes with the app.
  - Each question uses **your own** Claude plan.
  - Each question is capped at $0.50 of usage. A normal question uses about $0.03.
  - Without the Claude app, backups still work and the Ask Claude page says Claude was not found.

## Download and install

1. Go to **[Releases](https://github.com/RipXic/DragonsDogma2TrainerClaudeCompanion/releases/latest)** and download **DD2_Trainer_Claude_Companion_v1.1.zip** (under *Assets*).
2. Unzip it anywhere you like, for example `Documents\DD2 Trainer Claude Companion`. Keep the files together.
3. Double-click **start_companion.bat**.
4. A window opens and shows where it found your game, your saves and Claude. Keep it open while you play, and close it to stop.

The trainer's Ask Claude page and Automation page show "companion running" while it is on.

Windows may show "Windows protected your PC" the first time, because the .bat was downloaded from the internet. Click **More info > Run anyway**. The .bat only starts PowerShell with `companion.ps1`, and both are plain text you can read first.

**Update:** download the new zip and unzip it over the old folder. **Uninstall:** delete the folder. Your save backups stay in `Documents\DD2 Trainer save backups` until you delete them.

### Options

Add these after the .bat name, for example in a shortcut or a command prompt:

| Option | Default | What it does |
|---|---|---|
| `-Game "D:\...\Dragons Dogma 2"` | found through Steam | Use this if the game is not found automatically. |
| `-BackupRoot "E:\Backups\DD2"` | `Documents\DD2 Trainer save backups` | Where backups go. |
| `-Keep 20` | `40` | How many backups are kept. |
| `-BudgetUsd 0.25` | `0.5` | The most one question may use. |
| `-Model claude-sonnet-5-5` | `claude-sonnet-5-5` | The Claude model used for answers. |

Example: `start_companion.bat -Game "D:\Games\Steam\steamapps\common\Dragons Dogma 2" -Keep 20`

## Restore a backup

1. Close the game.
2. Open `Documents\DD2 Trainer save backups` and pick a folder. The name starts with the date and time.
3. Copy its contents over your save folder, which is listed in the companion window under "saves" (`...\Steam\userdata\<id>\2054970\remote\win64_save`).
4. Steam Cloud may offer a choice when you start the game. Pick the **local** files.

## How it works

The trainer (a REFramework Lua mod) cannot copy files outside its own folder or start programs. It hands those jobs to the companion through small text files in `<game>\reframework\data\wf_companion\`:

- `req\<id>.json`: a request written by the trainer (backup, or a question plus a snapshot of the game).
- `ans\<id>.json`: the answer written by the companion.
- `status.json`: written every 2 seconds, so the trainer knows the companion is running.

For a question, the companion runs `claude.exe -p` from the Claude desktop app like this:

- **No tools and no MCP servers:** Claude cannot run commands, read your files or browse.
- **No saved session.**
- **A fixed instruction file:** `system_prompt.txt`, which you can read and edit.
- **A spending cap per question.**

Claude only sees your question and the game snapshot. Its answer comes back to the panel.

Nothing is sent anywhere except that question and snapshot to Claude through your own Claude app, and only when you click **Ask**.

## Troubleshooting

- **The window closes at once, or there are red text errors:** run `start_companion.bat` from a command prompt to read the message. If the game was not found, pass `-Game "..."`.
- **"Claude Code not found":** install the Claude desktop app and sign in once, then restart the companion.
- **The trainer says "companion not running":** check that the companion window is open and shows the same game folder you play from.
- **Antivirus or SmartScreen warns about the .bat:** it only starts PowerShell with `companion.ps1`. Both files are plain text, so you can read them first.

Questions or bugs: the trainer's Nexus page (Posts / Bugs tabs) or the [RipXic Mods Discord](https://discord.gg/ZwrWMdJfFW).

## Single-player only

The trainer and this companion are for single-player use.

## License

Source-available, no redistribution: see [LICENSE](LICENSE). You may read it and run it for your own single-player use. You may not re-upload it, share changed versions, or use it in other projects without written permission from RipXic. This is a fan-made tool and is not affiliated with Capcom or Anthropic.
