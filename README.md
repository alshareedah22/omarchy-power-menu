# Power Menu for Omarchy

A power button for the Omarchy bar. Click it to open a popup with:

| # | Action    | Command                   |
|---|-----------|---------------------------|
| 1 | Lock      | `omarchy-system-lock`     |
| 2 | Logout    | `omarchy-system-logout`   |
| 3 | Suspend   | `systemctl suspend`       |
| 4 | Hibernate | `systemctl hibernate`     |
| 5 | Reboot    | `omarchy-system-reboot`   |
| 6 | Shutdown  | `omarchy-system-shutdown` |

- **Suspend** is hidden when you've turned suspend off in Omarchy.
- **Hibernate** only shows when hibernation is set up (`omarchy-hibernation-available`).
- **Logout**, **Reboot** and **Shutdown** ask for confirmation first.
- Keyboard: arrows or `j`/`k` to move, `Enter` to select, `1`–`6` for a direct pick, `Esc` to close.

## Install

```bash
omarchy plugin add https://github.com/alshareedah22/omarchy-power-menu.git --enable
```

The button places itself at the far right edge of the bar, after the battery,
and moves back there if another widget is added after it. If you take it off
the bar it stays off.

## Remove

```bash
omarchy plugin remove blackcode.power-menu
```

## Update

```bash
omarchy plugin update blackcode.power-menu
```

## Settings

To place the button yourself instead of keeping it at the far right:

```bash
omarchy bar set blackcode.power-menu pinned false --json
```

To skip the confirmation for logout, reboot and shutdown, set `confirm` to
`false` on the widget in `~/.config/omarchy/shell.json`:

```bash
omarchy bar set blackcode.power-menu confirm false --json
```

## License

MIT
