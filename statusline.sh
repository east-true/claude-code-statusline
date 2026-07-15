#!/bin/bash

# config file resolution: explicit path via $STATUSLINE_CONFIG, else first
# match of statusline.{conf,json,yml,yaml} in ~/.claude/
CONFIG_FILE="$STATUSLINE_CONFIG"
if [ -z "$CONFIG_FILE" ]; then
  for f in "$HOME/.claude/statusline.conf" "$HOME/.claude/statusline.json" \
           "$HOME/.claude/statusline.yml" "$HOME/.claude/statusline.yaml"; do
    if [ -f "$f" ]; then CONFIG_FILE="$f"; break; fi
  done
fi

load_config() {
  local f="$1"
  [ -f "$f" ] || return
  case "$f" in
    *.json)
      eval "$(jq -r 'to_entries | map("\(.key)=\(.value | tostring | @sh)") | .[]' "$f")"
      ;;
    *.yml|*.yaml)
      # minimal flat "key: value" parser - no nesting or lists, matches our
      # scalar-only config schema. Use a real YAML config (jq/yq) if you need more.
      while IFS= read -r line; do
        line="${line%%#*}"
        [ -z "${line//[[:space:]]/}" ] && continue
        local k="${line%%:*}"
        local v="${line#*:}"
        k="$(echo "$k" | xargs)"
        v="$(echo "$v" | xargs)"
        [ -n "$k" ] && eval "${k}=$(printf '%q' "$v")"
      done < "$f"
      ;;
    *)
      source "$f"
      ;;
  esac
}
load_config "$CONFIG_FILE"

# options (override in statusline.conf / .json / .yml)
SHOW_COST="${SHOW_COST:-true}"
SHOW_CONTEXT="${SHOW_CONTEXT:-true}"
SHOW_RATE_LIMITS="${SHOW_RATE_LIMITS:-true}"
ICON_STYLE="${ICON_STYLE:-emoji}"          # emoji | text | none
USE_COLOR="${USE_COLOR:-true}"
SEPARATOR="${SEPARATOR:- | }"
SEGMENT_ORDER="${SEGMENT_ORDER:-cost,context,rate_limits}"
USAGE_FORMAT="${USAGE_FORMAT:-percent}"    # percent | bar | both
BAR_WIDTH="${BAR_WIDTH:-10}"

# thresholds
COST_WARN_USD="${COST_WARN_USD:-3}"
COST_CRIT_USD="${COST_CRIT_USD:-8}"
WARN_PCT="${WARN_PCT:-50}"
CRIT_PCT="${CRIT_PCT:-80}"

input=$(cat)
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
in_tok=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
out_tok=$(echo "$input" | jq -r '.context_window.current_usage.output_tokens // 0')
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')

# subscription rate limits (Pro/Max only; absent for pay-as-you-go API keys)
fh_pct=$(echo "$input" | jq -r '(.rate_limits.five_hour.used_percentage // 0)')
fh_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
wk_pct=$(echo "$input" | jq -r '(.rate_limits.seven_day.used_percentage // 0)')
wk_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
has_rate_limits=$(echo "$input" | jq -r 'if .rate_limits.five_hour or .rate_limits.seven_day then "1" else "" end')

if [ "$USE_COLOR" = "true" ]; then
  RESET='\033[0m'
  GREEN='\033[32m'
  YELLOW='\033[33m'
  RED='\033[31m'
  BOLD_RED='\033[1;31m'
else
  RESET=''; GREEN=''; YELLOW=''; RED=''; BOLD_RED=''
fi

case "$ICON_STYLE" in
  emoji) WARN_ICON=" ⚠️"; MONEY_ICON=" 💸" ;;
  text)  WARN_ICON=" [WARN]"; MONEY_ICON=" [HIGH]" ;;
  *)     WARN_ICON=""; MONEY_ICON="" ;;
esac

color_for_pct() {
  local p="$1"
  if (( $(echo "$p >= $CRIT_PCT" | bc -l) )); then echo "$RED"
  elif (( $(echo "$p >= $WARN_PCT" | bc -l) )); then echo "$YELLOW"
  else echo "$GREEN"
  fi
}

color_for_cost() {
  local c="$1"
  if (( $(echo "$c >= $COST_CRIT_USD" | bc -l) )); then echo "$BOLD_RED"
  elif (( $(echo "$c >= $COST_WARN_USD" | bc -l) )); then echo "$YELLOW"
  else echo "$GREEN"
  fi
}

fmt_reset() {
  local epoch="$1"
  [ -z "$epoch" ] && return
  date -d "@${epoch%%.*}" "+%H:%M" 2>/dev/null
}

fmt_reset_with_date() {
  local epoch="$1"
  [ -z "$epoch" ] && return
  date -d "@${epoch%%.*}" "+%m/%d %H:%M" 2>/dev/null
}

render_bar() {
  local p="$1"
  local filled empty bar=""
  filled=$(printf "%.0f" "$(echo "$p / 100 * $BAR_WIDTH" | bc -l)")
  (( filled < 0 )) && filled=0
  (( filled > BAR_WIDTH )) && filled=$BAR_WIDTH
  empty=$((BAR_WIDTH - filled))
  for ((i = 0; i < filled; i++)); do bar+="█"; done
  for ((i = 0; i < empty; i++)); do bar+="░"; done
  printf "%s" "$bar"
}

# renders a usage percentage per USAGE_FORMAT (percent | bar | both)
render_usage() {
  local p="$1"
  local pct_txt
  pct_txt=$(printf "%.0f%%" "$p")
  case "$USAGE_FORMAT" in
    bar)  printf "%s" "$(render_bar "$p")" ;;
    both) printf "%s %s" "$(render_bar "$p")" "$pct_txt" ;;
    *)    printf "%s" "$pct_txt" ;;
  esac
}

join_segments() {
  local sep="$1"; shift
  local out="" first=1
  for seg in "$@"; do
    if [ "$first" -eq 1 ]; then out="$seg"; first=0
    else out="${out}${sep}${seg}"
    fi
  done
  printf "%s" "$out"
}

cost_seg=""
if [ "$SHOW_COST" = "true" ]; then
  cost_color=$(color_for_cost "$cost")
  cost_warn=""
  (( $(echo "$cost >= $COST_CRIT_USD" | bc -l) )) && cost_warn="$MONEY_ICON"
  cost_seg=$(printf "${cost_color}\$%.4f${RESET}${cost_warn}" "$cost")
fi

context_seg=""
if [ "$SHOW_CONTEXT" = "true" ]; then
  pct_color=$(color_for_pct "$pct")
  pct_warn=""
  (( $(echo "$pct >= $CRIT_PCT" | bc -l) )) && pct_warn="$WARN_ICON"
  context_seg=$(printf "${pct_color}ctx %s${RESET}${pct_warn} | in:%s out:%s cache:%s" "$(render_usage "$pct")" "$in_tok" "$out_tok" "$cache_read")
fi

ratelimit_seg=""
if [ "$SHOW_RATE_LIMITS" = "true" ] && [ -n "$has_rate_limits" ]; then
  fh_color=$(color_for_pct "$fh_pct")
  wk_color=$(color_for_pct "$wk_pct")
  fh_warn=""; (( $(echo "$fh_pct >= $CRIT_PCT" | bc -l) )) && fh_warn="$WARN_ICON"
  wk_warn=""; (( $(echo "$wk_pct >= $CRIT_PCT" | bc -l) )) && wk_warn="$WARN_ICON"
  fh_reset_fmt=$(fmt_reset "$fh_reset")
  wk_reset_fmt=$(fmt_reset_with_date "$wk_reset")
  [ -n "$fh_reset_fmt" ] && fh_reset_fmt=" (resets ${fh_reset_fmt})"
  [ -n "$wk_reset_fmt" ] && wk_reset_fmt=" (resets ${wk_reset_fmt})"
  ratelimit_seg=$(printf "${fh_color}5h %s${RESET}${fh_warn}${fh_reset_fmt} · ${wk_color}wk %s${RESET}${wk_warn}${wk_reset_fmt}" \
    "$(render_usage "$fh_pct")" "$(render_usage "$wk_pct")")
fi

segments=()
IFS=',' read -ra order_keys <<< "$SEGMENT_ORDER"
for key in "${order_keys[@]}"; do
  key="$(echo "$key" | xargs)"
  case "$key" in
    cost)         [ -n "$cost_seg" ] && segments+=("$cost_seg") ;;
    context)      [ -n "$context_seg" ] && segments+=("$context_seg") ;;
    rate_limits)  [ -n "$ratelimit_seg" ] && segments+=("$ratelimit_seg") ;;
  esac
done

join_segments "$SEPARATOR" "${segments[@]}"
