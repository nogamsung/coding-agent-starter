# [프로젝트명] — Flutter

## Stack
Flutter · Dart (null safety) · **Riverpod 2.x** (`@riverpod`) · GoRouter · Dio + Retrofit · Freezed + json_serializable · fpdart (`Either<Failure, T>`)

## Agents & Commands
| 목적 | Agent / Command |
|------|----------------|
| 새 파일 생성 | `flutter-generator` |
| 기존 코드 수정 | `flutter-modifier` |
| 테스트 작성 | `flutter-tester` |
| ThemeData 생성 | `ui-designer` (Flutter 모드) |
| 코드 리뷰 | `code-reviewer` · `/review` |
| Screen + 레이어 생성 | `/new <Name>` |
| 커밋/PR/머지 | `/commit` · `/pr` · `/merge` |
| 신규 기능 시작 | `/start <기능>` (worktree + PRD + 자동 구현) |
| 설계만 / 추가 PRD | `/plan <기능>` |
| Second Brain | `/memory [add\|search]` |

## Git 전략
`main` / `dev` / `{feature|fix|hotfix|refactor|chore}/{name}`. Worktree `.worktrees/{type}-{name}/` (독립 pub cache, `flutter pub get` 자동). `main` 직접 push 금지.

## 아키텍처 (Clean Architecture)
```
lib/
├── core/{errors,network,utils}/
├── features/{feature}/
│   ├── data/         # Repository impl, DataSource, Model
│   ├── domain/       # Entity, Repository interface, UseCase
│   └── presentation/ # Screen, Widget, Provider
└── shared/{widgets,providers}/
```

**레이어 의존**: `presentation` → `domain` ← `data`. `domain` 은 Flutter/외부 패키지 import 금지. `presentation` → `data` 직접 import 금지.

## MUST
- **Null Safety**: `?.`, `??` — `!` 확신 없이 금지
- **const**: 가능한 모든 위젯에 `const`
- **dispose**: `TextEditingController`, `AnimationController`, `ScrollController` 반드시 `dispose()`
- **Either**: `result.fold(onFailure, onSuccess)` 로 양쪽 처리 — 결과 무시 금지
- **Provider**: `@riverpod` 어노테이션 사용 (단순 경우만 `FutureProvider((ref) => ...)`)
- **async gap**: `BuildContext` 는 `if (!mounted) return;` 체크 후 사용

## NEVER
- `!` 를 non-null 보장 없이 사용
- Controller 생성하고 `dispose()` 안 함
- UI 스레드에서 blocking 연산 (`Isolate` / `compute` 사용)
- `presentation` 에서 `data` 직접 import
- `domain` 에서 Flutter 패키지 import
- `Either` 결과 무시
- `.freezed.dart`, `.g.dart` 직접 수정
- `BuildContext` 를 async gap 이후 mounted 체크 없이 사용
- `ListView` 20+ 항목을 `.builder` 없이 렌더

## 명령어
```bash
flutter pub get / test / analyze
flutter test --coverage
flutter pub run build_runner build --delete-conflicting-outputs
```

**`@freezed`, `@riverpod`, `@JsonSerializable`, Retrofit 어노테이션 변경 후** build_runner 실행 안내 필수.

**상세 패턴**: `.agents/skills/flutter-patterns/SKILL.md`.

**커버리지 게이트**: git push 전 Flutter 라인 커버리지 ≥90% (`.claude/hooks/pre-push.sh`). 제외 파일: `*.g.dart`, `*.freezed.dart`, `main.dart`.

## 학습된 규칙
<!-- /rule 로 여기에 추가됩니다 -->

## Memory
세션 시작 시 `memory/MEMORY.md` 자동 로드. `/plan`, `/rule`, 버그 해결, 라이브러리 도입, 아키텍처·성능 변경 → 자동 기록.

> **AGENTS.md ≤ 300줄 캡** — 초과 시 상세는 `.agents/skills/` 또는 `docs/` 로 이관, 본문은 인덱스 한 줄로.
