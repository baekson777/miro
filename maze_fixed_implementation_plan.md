# 고정 미로 3개 구현 계획서

작성일: 2026-11-15  
범위: **설계만** (이번 단계에서 게임 런타임 코드 수정 없음)

## 최종 선정 (확정)

| 난이도 | mazeId | size | seed | start | exit | 재현 |
|--------|--------|------:|-----:|-------|------|------|
| 하 | `EASY-001` | 15 | 1009 | (0,0) | (14,14) | `DfsMazeGenerator().generate(size: 15, seed: 1009)` |
| 중 | `NORMAL-001` | 21 | 2013 | (0,0) | (20,20) | `generate(size: 21, seed: 2013)` |
| 상 | `HARD-001` | 27 | 3045 | (0,0) | (26,19) | `generate(size: 27, seed: 3045)` |

출처: `maze_fixed_candidates_report.md` (실측 BFS·지표)

---

## 1. 고정 미로 데이터 설계

### 1.1 재사용 대상

- `MazeCell` (N/E/S/W 벽 플래그)
- `MazeGrid` (`size`, `cells`, `start`, `exit`, `seed`)
- `GridPos`
- `MazeCollision` / `MazeBoard` / `MazeWallCache` (변경 최소화)

### 1.2 영구 재현 방식 (권장: **직렬화 스냅샷**)

생성기만 믿고 seed를 런타임에 다시 돌리면, 이후 `DfsMazeGenerator` 내부 상수·알고리즘이 바뀌는 순간 맵이 달라진다.  
공정 경쟁용 고정맵은 아래를 **동결 스냅샷**으로 저장한다.

**권장 포맷 (Dart const 또는 JSON 동일 스키마)**

```text
FixedMazeDefinition {
  mazeId: String          // "EASY-001"
  difficulty: easy|normal|hard
  size: int
  seedUsed: int           // 제작 시 사용한 seed (감사·재생성용 메타)
  generatorVersion: String // 예: "growing_tree_v1_bias0.88"
  start: {row, col}
  exit: {row, col}
  cells: List<List<{n,e,s,w}>>  // visited 제외, 벽만
  checksum: String        // cells+start+exit+size 해시 (무결성)
  rulesVersion: String    // 예: "rules_v1" (이동/힌트 규칙 버전)
}
```

**동결 절차 (구현 시 1회성 툴)**

1. 현재 `DfsMazeGenerator`로 위 3 seed 생성  
2. `cells`를 const/JSON으로 dump  
3. BFS로 start→exit 도달·최단길이 스냅샷과 대조 (하 30 / 중 44 / 상 59)  
4. checksum 기록  
5. 이후 런타임은 **dump만 로드** (생성기 호출 금지)

### 1.3 생성기 변경으로부터의 보장

| 계층 | 역할 |
|------|------|
| `assets/mazes/*.json` 또는 `lib/.../fixed_maze_data.dart` | **유일한 진실 원본** |
| `DfsMazeGenerator` | 신규 맵 제작·실험용으로만 유지, 고정 플레이 경로에서 미호출 |
| CI 테스트 | dump ↔ checksum, 최단경로 불변 |

seed만 저장하고 런타임 재생성하면 **보장 실패**. seed는 메타데이터로만 남긴다.

### 1.4 mazeId

- `EASY-001`, `NORMAL-001`, `HARD-001`
- 맵 내용이 바뀌면 **새 ID** (`EASY-002`) + 랭킹 보드 분리 (기존 기록 보존)

---

## 2. 게임 연결 계획

### 2.1 GameMode 설계 (최소 침습)

기존 `PracticeMode` / `WeeklyChallengeMode`는 유지하고, **고정 경쟁 모드를 추가**하는 방안을 권장.

```text
sealed GameMode
  ├─ PracticeMode(difficulty, seed)     // 기존: 랜덤 연습 (옵션 유지)
  ├─ WeeklyChallengeMode(...)           // 기존: 주간 (옵션 유지/비활성)
  └─ FixedChallengeMode                 // 신규
        difficulty
        mazeId          // EASY-001 등
        boardKey        // fixed_easy 등
        rulesVersion    // rules_v1
```

`FixedChallengeMode` 속성 예:

- `displayName`: `고정 · 하` / `고정 · 중` / `고정 · 상`
- `mazeSize`: definition.size
- `seedKey` **또는** 명시적 `boardKey`: `fixed_easy` / `fixed_normal` / `fixed_hard`  
  (랭킹 키와 1:1 — 아래에 시드 난수 넣지 않음)

### 2.2 GameController

현재:

```text
_maze = _generator.generate(size: mode.mazeSize, seed: _resolveSeed());
```

변경 방향 (구현 단계):

```text
if mode is FixedChallengeMode:
  _maze = FixedMazeCatalog.load(mode.mazeId)  // dump → MazeGrid
else:
  기존 generate 유지
```

- **재시작**: `ResultScreen._retry` / 모드 선택에서 동일 `mazeId`의 `FixedChallengeMode`를 다시 넘김 → 동일 dump 로드  
- `app_router`의 `ValueKey(mode.seedKey)` → 고정 모드는 `boardKey` 또는 `mazeId` 기반으로 안정적 재생성

### 2.3 모드 선택 UI

`ModeSelectScreen`에 **「랭킹 챌린지 (고정 미로)」** 섹션 추가 권장:

- 하 / 중 / 상 → 각각 `FixedChallengeMode(EASY-001 | …)`
- 기존 **연습(랜덤)** · **주간** 버튼은 당분간 유지하되,  
  - 주간을 숨기거나 “실험”으로 내리는 것은 제품 결정  
  - 연습은 튜토리얼용으로 유지 가능 (랭킹 미연동 또는 별도 보드)

### 2.4 유지할 코드 (변경 금지에 가깝게)

- `collision.dart` 이동·벽 마찰
- `virtual_joystick.dart`
- `maze_board.dart` / `maze_wall_cache.dart`
- `timer_controller.dart` / `game_hud.dart`
- `hint_controller.dart` (규칙 버전만 메타에 기록)

---

## 3. 랭킹 설계

### 3.1 boardKey (난이도 독립)

| 난이도 | mazeId | boardKey |
|--------|--------|----------|
| 하 | EASY-001 | `fixed_easy` |
| 중 | NORMAL-001 | `fixed_normal` |
| 상 | HARD-001 | `fixed_hard` |

동일 난이도 전원 = 동일 미로 + 동일 `boardKey`로 경쟁.

저장 키 (기존 패턴 유지):

```text
SharedPreferences: lb_{boardKey}
예: lb_fixed_easy
```

### 3.2 기존 기록 마이그레이션 (비파괴)

현재 키:

- `lb_weekly_{weekId}`
- `lb_practice_{difficulty}_{seed}` (시드마다 분절)

**방안 A (권장): 병행 — 무마이그레이션**

- 새 `lb_fixed_*`만 사용
- 기존 weekly/practice 키는 그대로 둠 → **기존 기록 자동 보존**
- 리더보드 UI에 탭: `고정 하|중|상` / (옵션) `주간`

**방안 B: 읽기 전용 아카이브**

- 주간/연습 화면을 “이전 기록”으로만 노출
- 데이터 삭제·덮어쓰기 금지

**금지:** practice/weekly 엔트리를 `fixed_*`로 합산 (다른 맵이므로 불공정)

### 3.3 mazeId · rulesVersion 연결

`LeaderboardEntry` 확장 (구현 시, 하위호환):

```text
boardKey: fixed_easy
mazeId: EASY-001          // 신규 optional 필드
rulesVersion: rules_v1    // 신규 optional 필드
elapsedSeconds, hintCount, playerId, nickname, createdAt  // 기존
```

- **구버전 JSON**에 필드 없으면: `mazeId`/`rulesVersion` null 허용, 읽기 시 기본값 추론 가능  
- **제출 시** 항상 현재 catalog의 mazeId + rulesVersion 기록  
- 맵 또는 규칙(힌트 수, 이동 물리)이 바뀌면 `rulesVersion` 또는 `mazeId` 변경 → 필요 시 새 boardKey (`fixed_easy_v2`)로 분리

정렬 규칙은 기존 유지: 시간 ASC → 힌트 ASC.

### 3.4 LeaderboardScreen

- 기본: 고정 난이도 선택 (하/중/상) → `entriesFor('fixed_easy'|…)`
- 주간: 기존 `weekly_*` 쿼리 유지 (옵션)

---

## 4. 검증 계획

| ID | 검증 | 방법 |
|----|------|------|
| V1 | 출구 도달 | dump 로드 후 BFS start→exit ≥ 0 |
| V2 | 최단경로 불변 | 하=30, 중=44, 상=59 (선정 보고서와 일치) |
| V3 | 재시작 동일 | 동일 mazeId 두 번 로드 → cells/start/exit/checksum 동일 |
| V4 | 클라 간 동일 | dump가 리포에 커밋되어 빌드 산출물 공유 (시드 재생성 없음) |
| V5 | 통로·충돌 호환 | size·1셀 통로 + radius 0.30 기존 엔진; 스모크: 코너·좁은 통로 통과 |
| V6 | 랭킹 보존 | `lb_weekly_*` / `lb_practice_*` 키 미삭제·미개조 단위 테스트 |
| V7 | boardKey 분리 | fixed 제출이 weekly/practice 리스트에 섞이지 않음 |
| V8 | UI 재시작 | Result 재도전 → 동일 mazeId·동일 checksum |

분석 재실행: `flutter test tool/analyze_maze_candidates_test.dart` (참고용; 고정 후는 dump 단위 테스트로 대체)

---

## 5. 결과 보고

### 5.1 수정 대상 파일 (구현 단계)

| 파일 | 수정 내용 |
|------|-----------|
| `lib/features/maze/domain/game_mode.dart` | `FixedChallengeMode` 추가, boardKey/mazeId |
| `lib/features/maze/presentation/controllers/game_controller.dart` | Fixed면 dump 로드; Practice/Weekly는 기존 generate |
| `lib/features/home/.../mode_select_screen.dart` | 고정 하/중/상 진입 |
| `lib/features/maze/.../result_screen.dart` | 재시작 시 동일 Fixed 모드; submit에 mazeId/rulesVersion |
| `lib/features/leaderboard/domain/leaderboard_entry.dart` | optional mazeId, rulesVersion |
| `lib/features/leaderboard/.../leaderboard_screen.dart` | fixed 보드 탭/필터 |
| `lib/core/navigation/app_router.dart` | Fixed 모드 라우팅·ValueKey |

### 5.2 신규 파일 (구현 단계)

| 파일 | 역할 |
|------|------|
| `lib/features/maze/data/fixed_maze_catalog.dart` | mazeId → definition 로드 |
| `lib/features/maze/data/fixed_mazes/easy_001.dart` (또는 `assets/mazes/easy_001.json`) | EASY-001 dump |
| `.../normal_001.*` | NORMAL-001 |
| `.../hard_001.*` | HARD-001 |
| `lib/features/maze/domain/fixed_maze_definition.dart` | 스키마·checksum |
| `tool/export_fixed_mazes.dart` (또는 test) | seed→dump 1회성 export |
| `test/fixed_maze_invariants_test.dart` | V1–V4, V6–V7 |

### 5.3 데이터 구조 (요약)

```text
FixedMazeDefinition
  mazeId, difficulty, size, seedUsed, generatorVersion
  start, exit, cells[][], checksum, rulesVersion

FixedChallengeMode → mazeId + boardKey
GameController → MazeGrid (from catalog)
LeaderboardEntry → boardKey + mazeId? + rulesVersion?
Prefs → lb_fixed_easy | lb_fixed_normal | lb_fixed_hard
```

### 5.4 랭킹 연결 구조

```text
ModeSelect(고정·하)
  → FixedChallengeMode(mazeId=EASY-001, boardKey=fixed_easy)
  → GameController loads dump
  → Clear → ResultArgs(mode)
  → LeaderboardEntry(boardKey=fixed_easy, mazeId=EASY-001, rulesVersion=rules_v1, …)
  → prefs lb_fixed_easy
  → LeaderboardScreen(fixed_easy)
```

연습/주간 기록은 **다른 키**에 남아 영향 없음.

### 5.5 위험 요소

| 위험 | 완화 |
|------|------|
| 생성기 변경으로 seed 재생성 시 맵 변형 | **dump 전용 로드**, CI checksum |
| 기존 weekly를 fixed로 오인 | UI 분리 + 키 네이밍 `fixed_*` |
| Entry 스키마 확장으로 구기록 파싱 실패 | 필드 optional + fromJson 기본값 |
| 27×27 dump 용량 | JSON gzip 또는 Dart const; 커밋 전 크기 확인 |
| 규칙 변경(물리/힌트) 후 불공정 | `rulesVersion` / `fixed_easy_v2` 보드 분리 |
| 실수로 Practice 재시작이 새 seed | Fixed 경로만 동일 mazeId 강제 |

### 5.6 테스트 계획 (구현 후)

1. `fixed_maze_invariants_test`: 3맵 로드·최단 30/44/59·checksum  
2. `leaderboard_repository` 테스트: fixed 제출 후 weekly 키 개수 불변  
3. 위젯/통합: 모드 선택 → 클리어 → 재시작 → 동일 seed/mazeId  
4. 수동 Emulator: 하/중/상 각 1판, 벽 이동·출구·리더보드 탭  
5. `flutter analyze` / 기존 `flutter test` 회귀

---

## 구현 순서 제안 (다음 단계용)

1. Export 툴로 3 dump + checksum 생성  
2. Catalog + FixedChallengeMode  
3. GameController 분기 + ModeSelect  
4. LeaderboardEntry·Screen·Result 연동  
5. 불변 테스트 + 기존 키 보존 테스트  
6. Emulator 스모크  

**이번 문서 단계에서는 위 항목을 코드에 적용하지 않는다.**
