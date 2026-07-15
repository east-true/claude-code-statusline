# claude-code-statusline

A script that uses Claude Code's `statusLine` feature to show session cost, context-window usage, and (for Pro/Max subscription plans) 5-hour/weekly rate-limit consumption live in the terminal status line. No third-party extensions - runs entirely locally.

## Preview

```
$1.8000 | ctx 9% | in:2 out:333 cache:84959 | 5h 59% (resets 14:20) · wk 35% (resets 07/20 21:00)
```

Colors shift green/yellow/red based on thresholds; ⚠️ appears at 80%+, and 💸 appears once cost passes `COST_CRIT_USD`.

## Requirements

`jq` and `bc` must be installed. If either is missing, the status line will show raw `command not found` errors.

```bash
# Debian/Ubuntu
sudo apt install jq bc

# macOS
brew install jq bc
```

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

## Customization

Drop in a config file and it's picked up automatically. The first file found in this order wins (or set an explicit path with the `STATUSLINE_CONFIG` env var):

1. `~/.claude/statusline.conf` (shell variable format)
2. `~/.claude/statusline.json`
3. `~/.claude/statusline.yml` / `~/.claude/statusline.yaml`

Copy `statusline.conf.example`, `statusline.json.example`, or `statusline.yaml.example` from this repo under your preferred name to get started.

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

- **Per-model (Opus/Sonnet/Fable) weekly limits are not shown.** The `/usage` command displays per-model breakdowns (e.g. "Current week (Fable)"), but those values only come from a separate account-status API that `/usage` calls on its own. The JSON payload passed to `statusLine` only includes the aggregate `five_hour` / `seven_day` fields, not per-model fields. Run `/usage` directly if you need per-model consumption.
- The `rate_limits` field isn't documented in Anthropic's official docs - it was found by inspecting the installed Claude Code binary's internal code. Field names or structure may change in future Claude Code versions.
- API-key (pay-as-you-go) users never receive the `rate_limits` field, so the `5h`/`wk` items are automatically omitted.

## License

MIT
