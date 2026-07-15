# claude-code-statusline

![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)
![Shell: Bash](https://img.shields.io/badge/shell-bash-89e051.svg)
![Platform](https://img.shields.io/badge/platform-linux%20%7C%20macos-lightgrey.svg)
![Dependencies](https://img.shields.io/badge/deps-jq%20%2B%20bc-orange.svg)

**See your Claude Code spend before it surprises you.** A drop-in `statusLine` script that shows session cost, context-window usage, and (on Pro/Max) your 5-hour/weekly rate-limit consumption — live, in the terminal, with zero third-party extensions and zero network calls.

---

## Preview

Default (`USAGE_FORMAT=percent`):

```
$1.8000 | ctx 9% | in:2 out:333 cache:84959 | 5h 59% (resets 14:20) · wk 35% (resets 07/20 21:00)
```

With `USAGE_FORMAT=both`:

```
$1.8000 | ctx ████░░░░░░ 9% | in:2 out:333 cache:84959 | 5h ██████░░░░ 59% (resets 14:20) · wk ████░░░░░░ 35% (resets 07/20 21:00)
```

Colors shift 🟢 green → 🟡 yellow → 🔴 red as thresholds are crossed; ⚠️ appears at 80%+, and 💸 appears once cost passes `COST_CRIT_USD`. Every color, icon, threshold, and segment is configurable - see [Customization](#customization).

---

## Requirements

`jq` and `bc` must be installed. If either is missing, the status line will show raw `command not found` errors instead of failing quietly.

```bash
# Debian/Ubuntu
sudo apt install jq bc

# macOS
brew install jq bc
```

## Platform support

| Platform | Status |
|---|---|
| 🐧 Linux | Works out of the box. |
| 🍎 macOS | Works once `jq`/`bc` are installed via Homebrew. The script detects GNU vs. BSD `date` automatically, so reset times (`resets 14:20`) render correctly on both. |
| 🪟 Windows | Not supported natively - it's a bash script. Use **WSL** (behaves exactly like Linux). Git Bash/MSYS2 may work but you'll need to install `jq` and `bc` separately (`bc` in particular has no official Windows build, so it may be hard to source). |

## Install

1. Copy `statusline.sh` to `~/.claude/statusline.sh` and make it executable.

   ```bash
   cp statusline.sh ~/.claude/statusline.sh
   chmod +x ~/.claude/statusline.sh
   ```

2. Add the following to `~/.claude/settings.json` (merge with any existing settings).

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.claude/statusline.sh",
       "refreshInterval": 2
     }
   }
   ```

3. Start a new Claude Code session and it takes effect.

## What it shows

| Item | Description |
|---|---|
| `$X.XXXX` | Current session cost (USD) |
| `ctx X%` | Context window usage |
| `in / out / cache` | Input / output / cache-read token counts for the current turn |
| `5h X%` | 5-hour rolling session rate-limit consumption (subscription plans only) |
| `wk X%` | 7-day weekly rate-limit consumption (subscription plans only) |

> [!NOTE]
> `resets_at` is delivered as a UTC Unix timestamp; the `(resets ...)` times shown for `5h`/`wk` are converted to your system's local timezone (or `TZ`, if set) - the same convention `/usage` uses (e.g. "Resets 2:19pm (Asia/Seoul)").

## Customization

Drop in a config file and it's picked up automatically. The first file found in this order wins (or set an explicit path with the `STATUSLINE_CONFIG` env var):

1. `~/.claude/statusline.conf` (shell variable format)
2. `~/.claude/statusline.json`
3. `~/.claude/statusline.yml` / `~/.claude/statusline.yaml`

Copy `statusline.conf.example`, `statusline.json.example`, or `statusline.yaml.example` from this repo under your preferred name to get started.

> [!TIP]
> To avoid requiring a separate parser like `yq`, YAML is handled by a **minimal flat parser** with no dependency beyond the `jq`/`bc` already in use. It doesn't support nesting or lists - only single-line `KEY: value` entries. If you need anything more complex, use the JSON config instead (parsed by `jq`, so it's more robust).

### Options

| Option | Default | Description |
|---|---|---|
| `SHOW_COST` | `true` | Whether to show the cost segment |
| `SHOW_CONTEXT` | `true` | Whether to show the context-usage segment |
| `SHOW_RATE_LIMITS` | `true` | Whether to show the subscription rate-limit segment |
| `SEGMENT_ORDER` | `cost,context,rate_limits` | Display order of segments (comma-separated; anything left out is hidden) |
| `USAGE_FORMAT` | `percent` | How percentages are rendered: `percent` (`59%`) / `bar` (`██████░░░░`) / `both` (`██████░░░░ 59%`) |
| `BAR_WIDTH` | `10` | Bar length for `bar`/`both` formats |
| `ICON_STYLE` | `emoji` | Warning icon style: `emoji` (⚠️/💸) / `text` (`[WARN]`/`[HIGH]`) / `none` |
| `USE_COLOR` | `true` | Whether to use ANSI colors |
| `SEPARATOR` | `" \| "` | String placed between segments |
| `COST_WARN_USD` / `COST_CRIT_USD` | `3` / `8` | Cost warning/critical thresholds (USD) |
| `WARN_PCT` / `CRIT_PCT` | `50` / `80` | Usage (context/rate-limit) warning/critical thresholds (%) |

## Known limitations

> [!WARNING]
> A few rough edges to know about before you rely on this for anything important.

- **Per-model (Opus/Sonnet/Fable) weekly limits are not shown.** The `/usage` command displays per-model breakdowns (e.g. "Current week (Fable)"), but those values only come from a separate account-status API that `/usage` calls on its own. The JSON payload passed to `statusLine` only includes the aggregate `five_hour` / `seven_day` fields, not per-model fields. Run `/usage` directly if you need per-model consumption.
- **The `rate_limits` field isn't officially documented.** It was found by inspecting the installed Claude Code binary's internal code, not Anthropic's docs. Field names or structure may change in future Claude Code versions.
- **API-key (pay-as-you-go) users never receive `rate_limits`**, so the `5h`/`wk` items are automatically omitted.
- **`5h`/`wk` can show different numbers across concurrent sessions of the same account.** These are account-wide quotas, but each session only displays the rate-limit snapshot from *its own* last API response - an idle session keeps showing an old (possibly even previous-window) snapshot until it makes another request. If two windows disagree, the one with the more recent message is the accurate one; send any message in the stale one to refresh it.
