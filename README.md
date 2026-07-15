# claude-code-statusline

Claude Code의 `statusLine` 기능을 이용해, 세션 비용 · 컨텍스트 사용률 · (Pro/Max 구독 플랜의) 5시간·주간 rate limit 소진율을 터미널 상태줄에 실시간으로 보여주는 스크립트입니다. 서드파티 확장 없이, 로컬에서만 동작합니다.

## 미리보기

```
$1.8000 | ctx 9% | in:2 out:333 cache:84959 | 5h 59% (resets 14:20) · wk 35% (resets 07/20 21:00)
```

색상은 임계값에 따라 초록/노랑/빨강으로 바뀌고, 80% 이상이면 ⚠️, 비용이 `COST_CRIT_USD` 이상이면 💸가 붙습니다.

## 요구사항

`jq`, `bc`가 설치되어 있어야 합니다. 둘 중 하나라도 없으면 상태줄에 `command not found` 에러가 그대로 노출됩니다.

```bash
# Debian/Ubuntu
sudo apt install jq bc

# macOS
brew install jq bc
```

## 설치

1. `statusline.sh`를 `~/.claude/statusline.sh`로 복사하고 실행 권한을 줍니다.

   ```bash
   cp statusline.sh ~/.claude/statusline.sh
   chmod +x ~/.claude/statusline.sh
   ```

2. `~/.claude/settings.json`에 아래 항목을 추가합니다 (기존 설정이 있다면 병합).

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.claude/statusline.sh",
       "refreshInterval": 2
     }
   }
   ```

3. 새 Claude Code 세션을 시작하면 적용됩니다.

## 표시 항목

| 항목 | 설명 |
|---|---|
| `$X.XXXX` | 현재 세션 비용 (USD) |
| `ctx X%` | 컨텍스트 윈도우 사용률 |
| `in / out / cache` | 현재 턴의 input / output / cache-read 토큰 수 |
| `5h X%` | 5시간 롤링 세션 rate limit 소진율 (구독 플랜에서만 표시) |
| `wk X%` | 7일 주간 rate limit 소진율 (구독 플랜에서만 표시) |

## 커스터마이징

설정 파일을 두면 적용됩니다. 아래 순서로 첫 번째로 존재하는 파일을 사용합니다 (`STATUSLINE_CONFIG` 환경변수로 경로를 직접 지정할 수도 있습니다):

1. `~/.claude/statusline.conf` (셸 변수 형식)
2. `~/.claude/statusline.json`
3. `~/.claude/statusline.yml` / `~/.claude/statusline.yaml`

레포에 있는 `statusline.conf.example`, `statusline.json.example`, `statusline.yaml.example`을 원하는 이름으로 복사해서 시작하세요.

> YAML은 `yq` 같은 별도 파서를 추가로 요구하지 않기 위해, 이미 쓰고 있는 `jq`/`bc` 외 새 의존성 없는 **최소 플랫(flat) 파서**로 처리합니다. 중첩 구조나 리스트는 지원하지 않고 `KEY: value` 한 줄짜리 항목만 인식합니다. 더 복잡한 YAML이 필요하면 JSON 설정을 쓰세요 (`jq`로 처리되어 더 견고합니다).

### 옵션

| 옵션 | 기본값 | 설명 |
|---|---|---|
| `SHOW_COST` | `true` | 비용 세그먼트 표시 여부 |
| `SHOW_CONTEXT` | `true` | 컨텍스트 사용률 세그먼트 표시 여부 |
| `SHOW_RATE_LIMITS` | `true` | 구독 rate limit 세그먼트 표시 여부 |
| `SEGMENT_ORDER` | `cost,context,rate_limits` | 세그먼트 표시 순서 (콤마 구분, 목록에 없는 항목은 숨겨짐) |
| `USAGE_FORMAT` | `percent` | 퍼센트 표현 방식: `percent`(`59%`) / `bar`(`██████░░░░`) / `both`(`██████░░░░ 59%`) |
| `BAR_WIDTH` | `10` | `bar`/`both` 포맷일 때 막대 길이 |
| `ICON_STYLE` | `emoji` | 경고 아이콘 스타일: `emoji`(⚠️/💸) / `text`(`[WARN]`/`[HIGH]`) / `none` |
| `USE_COLOR` | `true` | ANSI 색상 사용 여부 |
| `SEPARATOR` | `" \| "` | 세그먼트 사이 구분 문자열 |
| `COST_WARN_USD` / `COST_CRIT_USD` | `3` / `8` | 비용 경고·위험 임계값 (USD) |
| `WARN_PCT` / `CRIT_PCT` | `50` / `80` | 사용률(컨텍스트·rate limit) 경고·위험 임계값 (%) |

## 알려진 제한사항

- **모델별(Opus/Sonnet/Fable) 주간 한도는 표시되지 않습니다.** `/usage` 명령은 모델별 세부 한도(예: "Current week (Fable)")를 보여주지만, 이는 `/usage`가 별도로 호출하는 계정 상태 API에서만 제공되는 값입니다. `statusLine`에 전달되는 JSON payload에는 전체 합산 `five_hour` / `seven_day` 필드만 있고, 모델별 필드는 포함되어 있지 않습니다. 모델별 소진율이 필요하면 `/usage`를 직접 실행해야 합니다.
- `rate_limits` 필드는 Anthropic 공식 문서에 명시적으로 문서화되어 있지 않고, 설치된 Claude Code 바이너리 내부 코드를 직접 확인해 알아낸 값입니다. 향후 Claude Code 버전에서 필드명이나 구조가 바뀔 수 있습니다.
- API 키(pay-as-you-go) 사용자에게는 `rate_limits` 필드 자체가 내려오지 않아 `5h`/`wk` 항목이 자동으로 생략됩니다.

## License

MIT
