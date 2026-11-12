# [프로젝트명] — Kotlin Spring Boot

## Stack
Kotlin · Spring Boot 3.x · Gradle (Kotlin DSL) · JPA + Hibernate + **QueryDSL** · Flyway · Spring Security + JWT · **SpringDoc OpenAPI**

## Agents & Commands
| 목적 | Agent / Command |
|------|----------------|
| 새 파일 생성 | `kotlin-generator` |
| 기존 코드 수정 | `kotlin-modifier` |
| 테스트 작성 | `kotlin-tester` |
| 코드 리뷰 | `code-reviewer` · `/review` |
| API 설계 | `/plan api <Resource>` |
| DB 설계 | `/plan db <도메인>` |
| REST API 스캐폴딩 | `/new <Resource>` |
| 커밋/PR/머지 | `/commit` · `/pr` · `/merge` |
| 신규 기능 시작 | `/start <기능>` (worktree + PRD + 자동 구현) |
| 설계만 / 추가 PRD | `/plan <기능>` |
| Second Brain | `/memory [add\|search]` |

## Git 전략
`main` / `dev` / `{feature|fix|hotfix|refactor|chore}/{name}`. Worktree `.worktrees/{type}-{name}/`. `main` 직접 push 금지.

## 디렉토리 구조
```
src/main/kotlin/com/{company}/{project}/
├── domain/           # Entity, VO — 순수 도메인
├── application/      # Service
├── infrastructure/   # Repository 구현, 외부 연동
├── presentation/     # Controller, DTO
└── config/
```

**레이어 의존**: `presentation` → `application` → `domain` ← `infrastructure`. `domain` 은 infrastructure import 금지.

## MUST
- **DI**: 생성자 주입만 — `@Autowired lateinit var` 금지
- **Transaction**: `@Service @Transactional(readOnly = true)` 클래스, 쓰기 메서드에만 `@Transactional`
- **DTO**: `Response.from(entity)` 로 변환 — Entity 직접 반환 금지
- **Null Safety**: `?.`, `?:` — `!!` 확신 없이 금지
- **예외**: 도메인 예외 던지고 `GlobalExceptionHandler` 에서 처리 — Controller try-catch 로 삼키기 금지
- **QueryDSL**: 모든 동적 쿼리는 QueryDSL (인터페이스 + Impl + SearchCondition 3세트)
- **SpringDoc**: Controller 에 `@Tag`, `@Operation`, `@ApiResponse`, `@Parameter` 필수
- **Schema**: Request/Response DTO 에 `@Schema` 필수

## NEVER
- `DROP TABLE`, `TRUNCATE` raw DDL
- 기존 Flyway migration 수정
- Entity 에 비즈니스 로직
- 패스워드·토큰·PII 로그
- `@SpringBootApplication` 에 비즈니스 코드
- 테스트 없이 public 메서드 추가
- N+1 유발 `FetchType.EAGER`
- SpringDoc 없이 Controller 엔드포인트 추가
- QueryDSL 없이 `@Query` JPQL / Native Query 로 동적 쿼리
- 동적 조건을 `JpaRepository` 메서드 이름으로 억지 처리

## 명령어
```bash
./gradlew build / test / ktlintCheck / jacocoTestReport
./gradlew bootRun
```

**상세 패턴**: `.agents/skills/kotlin-patterns/SKILL.md` · API 설계: `.agents/skills/api-design-patterns/SKILL.md`.

**커버리지 게이트**: git push 전 Jacoco 라인 커버리지 ≥90% (`.claude/hooks/pre-push.sh`). build.gradle.kts 에 `jacoco` 플러그인 + `tasks.test { finalizedBy(tasks.jacocoTestReport) }`.

## 학습된 규칙

### 2026-04-14 — QueryDSL 필수화
Spring Boot 프로젝트는 JPA + QueryDSL 기본 조합. 동적 조건 쿼리는 타입 안전하게 QueryDSL 로 작성. 복잡한 집계는 jOOQ 추가 가능.

<!-- /rule 로 여기에 추가됩니다 -->

## Memory
세션 시작 시 `memory/MEMORY.md` 자동 로드. `/plan`, `/rule`, 버그 해결, 라이브러리 도입, 아키텍처·성능 변경 → 자동 기록.

> **AGENTS.md ≤ 300줄 캡** — 초과 시 상세는 `.agents/skills/` 또는 `docs/` 로 이관, 본문은 인덱스 한 줄로.
