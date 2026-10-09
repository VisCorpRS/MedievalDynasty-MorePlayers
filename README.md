# Medieval Dynasty – More Players

Raises Medieval Dynasty's co-op player limit from **4 to 8**, or any number from 2 to 64.

- **Only the host installs it.** Joining players use the normal, unmodded game.
- **No mod loader and no extra DLLs.** It's one small script that changes 7 bytes in the game exe and one line in a config file.
- **It never ships game files.** The script edits your own copy of the game, backs up the original, and can undo everything.

> Tested with 5 players on the Steam version, game version 2.2.0.8 (Oxbow co-op map). Joining, the in-game player list, player colours, building and saving all worked. Counts above 5 haven't been tested yet. Please report how it goes.

---

## Install

1. Download and unzip this folder anywhere, for example your Desktop.
2. **Close the game.**
3. Double-click **`Install (8 players).bat`**.
4. It should say `Done: co-op player cap is now 8`.

The script finds a Steam install of the game automatically. If it can't, it asks for the game folder. To find it in Steam, right-click Medieval Dynasty → Manage → Browse local files.

Then host a co-op game as usual. Friends join through Steam invites or the invite code.

## Change the player count

Double-click **`Set player count.bat`** and type a number from 2 to 64.

From the command line:

```powershell
powershell -ExecutionPolicy Bypass -File MorePlayers.ps1 -Players 12
```

Things to know before going above 8:

- **Colours:** the game has 8 player colours. Players 9+ will probably share a colour with someone else.
- **Performance:** the host simulates the whole world and every player, so each extra player adds load on the host's CPU and connection.
- **64 is the upper bound** of the online lobby service the game uses.

## Check status / uninstall

- **`Check status.bat`** shows the current lobby size and join limit.
- **`Uninstall.bat`** restores the original 4-player game. It undoes both changes.

You can also use Steam → Properties → Installed Files → **Verify integrity of game files**. That restores the exe. The Game.ini line is harmless on its own, but `Uninstall.bat` removes it too.

## After a game update

Steam updates replace the game exe, which resets the lobby size to 4. **Run `Install (8 players).bat` again.**

If an update changed the relevant code, the script says *"This version … is not recognised"* and changes **nothing**. In that case, wait for an updated version of this mod.

---

## How it works

Co-op player count is limited in two places, and both are on the host.

| Limit | Where | What the mod changes |
|---|---|---|
| **Lobby slots** (how many can join the online session) | `CreateSessionCustomCallProxy::CreateSession` in `Medieval_Dynasty-Win64-Shipping.exe` stores the slot count the menu passes in (4) | 7 bytes: `mov ecx,[rsp+0A8h]` → `mov ecx,<N>; nop; nop`, so the stored count is always N |
| **Join limit** (how many players the host accepts) | `AGameSession::MaxPlayers`, read from config | `%LOCALAPPDATA%\Medieval_Dynasty\Saved\Config\WindowsNoEditor\Game.ini` → `[/Script/Engine.GameSession]` `MaxPlayers=<N>` |

The script finds the code by a unique byte pattern, not a fixed address, and checks the surrounding bytes before writing anything.

With only one of the two raised, extra players are still refused:

| Symptom when player 5 tries to join | Meaning |
|---|---|
| Steam "Join game" missing / invite code says **"session is full"** | Lobby slots still 4: run the installer again (game update?) |
| **"Pending connection failure"** while loading in | Join limit still 4: Game.ini wasn't updated |

The rest of the game already copes with more than 4 players. The in-game player list (Esc) adds a row for each player, and colours come from an 8-colour palette.

## Requirements and compatibility

- Windows, **Steam version**. GOG and Epic versions may work if their exe is the same build. The script refuses to patch an exe it doesn't recognise. The Game Pass / Microsoft Store version is not supported.
- Windows PowerShell, which is built into Windows 10/11.
- Clients need nothing. Crossplay with consoles above 4 players is untested.

## Troubleshooting

- **"Close the game first."** The game, or a stuck copy of it, is still running. End `Medieval_Dynasty-Win64-Shipping.exe` in Task Manager.
- **Antivirus or SmartScreen warning.** The .bat files only run `MorePlayers.ps1` from the same folder. Read it, it's short. Antivirus may also briefly lock or scan the exe after it's been modified.
- **Game won't start after patching.** Run `Uninstall.bat` or verify the game files in Steam. Then please open an issue with your game version.

## Disclaimer

This is a fan-made mod, not affiliated with Render Cube or Toplitz Productions. Back up your saves (`%LOCALAPPDATA%\Medieval_Dynasty\Saved\SaveGames`) before playing with more players than the game was designed for. Use at your own risk.

## License

MIT. See [LICENSE](LICENSE).

## Support

If you enjoyed this mod, be sure to support me and similar future projects! 
☕ https://ko-fi.com/viscorp
