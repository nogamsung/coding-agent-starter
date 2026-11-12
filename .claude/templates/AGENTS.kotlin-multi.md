# [프로젝트명] — Kotlin Spring Boot (Gradle 멀티 모듈)

## Stack
Kotlin · Spring Boot 3.x · **Gradle 멀티 모듈** (Kotlin DSL) · JPA + Hibernate + **QueryDSL** · Flyway · Spring Security + JWT · **SpringDoc OpenAPI**

## Agents & Commands
`kotlin-generator` / `kotlin-modifier` / `kotlin-tester` / `code-reviewer`. `/new module <name>` 로 서브모듈 추가. 공통 커맨드는 단일 모듈과 동일.

## 멀티 모듈 구조
```
settings.gradle.kts       # include(":api", ":domain", ":infra")
build.gradle.kts          # 루트 공통
api/                      # depends on :domain, :infra
  src/main/kotlin/.../{presentation,config}/
domain/                   # 외부 의존성 없음
  src/main/kotlin/.../{domain,application}/
infra/                    # depends on :domain
  src/main/kotlin/.../infrastructure/
```

**모듈 의존**: `api` → `domain` ← `infra`. `:domain` 은 `:api`/`:infra` import 금지. `:api` → `:infra` 직접 import 금지 (`:domain` 인터페이스 통해 간접).

## 공통 규칙
**레이어별 세부 규칙은 `AGENTS.kotlin.md` 와 동일** — MUST/NEVER 섹션 그대로 적용.

## 멀티 모듈 추가 규칙
- `:api` ↛ `:infra` 직접 import — `:domain` 인터페이스 경유
- `:domain` ↛ `:api`, `:infra` — 순수 도메인 유지
- SpringDoc 은 `:api` 모듈에만 적용
- QueryDSL 구현체는 `:infra`, 인터페이스는 `:domain`

## 명령어
```bash
./gradlew test jacocoTestReport    # 전체 모듈
./gradlew :api:test / :domain:test / :infra:test
./gradlew :api:bootJar
./gradlew ktlintCheck
```

**상세 패턴**: `.agents/skills/kotlin-patterns/SKILL.md`.

**커버리지 게이트**: git push 전 Jacoco 라인 커버리지 ≥90%. 루트 `build.gradle.kts`:
```kotlin
subprojects {
    apply(plugin = "jacoco")
    tasks.withType<JacocoReport> {
        dependsOn(tasks.withType<Test>())
        reports { xml.required = true; html.required = true }
    }
}
```

## 학습된 규칙

### 2026-04-14 — QueryDSL 필수화
Spring Boot 프로젝트는 JPA + QueryDSL 기본. 동적 쿼리는 QueryDSL 로 타입 안전하게.

<!-- /rule 로 여기에 추가됩니다 -->

## Memory
세션 시작 시 `memory/MEMORY.md` 자동 로드.

> **AGENTS.md ≤ 300줄 캡** — 초과 시 상세는 `.agents/skills/` 또는 `docs/` 로 이관, 본문은 인덱스 한 줄로.
