#!/bin/bash
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

# thresholds (override via env if needed)
COST_WARN_USD="${COST_WARN_USD:-3}"
COST_CRIT_USD="${COST_CRIT_USD:-8}"

RESET='\033[0m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
BOLD_RED='\033[1;31m'

color_for_pct() {
  local p="$1"
  if (( $(echo "$p >= 80" | bc -l) )); then echo "$RED"
  elif (( $(echo "$p >= 50" | bc -l) )); then echo "$YELLOW"
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

pct_color=$(color_for_pct "$pct")
cost_color=$(color_for_cost "$cost")

pct_warn=""
(( $(echo "$pct >= 80" | bc -l) )) && pct_warn=" ⚠️ "
cost_warn=""
(( $(echo "$cost >= $COST_CRIT_USD" | bc -l) )) && cost_warn=" 💸"

line=$(printf "${cost_color}\$%.4f${RESET}${cost_warn} | ${pct_color}ctx %.0f%%${RESET}${pct_warn} | in:%s out:%s cache:%s" \
  "$cost" "$pct" "$in_tok" "$out_tok" "$cache_read")

if [ -n "$has_rate_limits" ]; then
  fh_color=$(color_for_pct "$fh_pct")
  wk_color=$(color_for_pct "$wk_pct")
  fh_warn=""; (( $(echo "$fh_pct >= 80" | bc -l) )) && fh_warn=" ⚠️"
  wk_warn=""; (( $(echo "$wk_pct >= 80" | bc -l) )) && wk_warn=" ⚠️"
  fh_reset_fmt=$(fmt_reset "$fh_reset")
  wk_reset_fmt=$(fmt_reset_with_date "$wk_reset")
  [ -n "$fh_reset_fmt" ] && fh_reset_fmt=" (resets ${fh_reset_fmt})"
  [ -n "$wk_reset_fmt" ] && wk_reset_fmt=" (resets ${wk_reset_fmt})"

  rl=$(printf " | ${fh_color}5h %.0f%%${RESET}${fh_warn}${fh_reset_fmt} · ${wk_color}wk %.0f%%${RESET}${wk_warn}${wk_reset_fmt}" \
    "$fh_pct" "$wk_pct")
  line="${line}${rl}"
fi

printf "%s" "$line"
