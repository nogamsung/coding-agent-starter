---
name: observability-patterns
description: structured logging · OpenTelemetry tracing/metrics · 에러 추적(Sentry/DataDog) · SLO/SLI 정의. 5개 코드 스택 횡단.
---

# Observability Patterns

5개 코드 스택 (Kotlin / Go / Python / Next.js / Flutter) 모두에 적용되는 관측 패턴.

## 1. Structured Logging

JSON 한 줄 = 1 이벤트. 항상 `level`, `ts`, `msg`, `request_id` (또는 `trace_id`) 포함.

| 스택 | 권장 라이브러리 | 비고 |
|------|----------------|------|
| Kotlin Spring Boot | Logback + `logstash-logback-encoder` | `MDC.put("trace_id", ...)` |
| Go Gin | `go.uber.org/zap` (구조화) 또는 `rs/zerolog` | `logger.With(zap.String("trace_id", id))` |
| Python FastAPI | `structlog` + `python-json-logger` | `contextvars` 로 request-scoped binding |
| Next.js | `pino` (server) + `pino-pretty` (dev) | API route 시작 시 child logger |
| Flutter | `logger` 패키지 + `logger_flutter` | crash 시 `FlutterError.onError` 캡처 |

### 공통 필드 컨벤션

```json
{
  "ts": "2026-05-08T10:23:11Z",
  "level": "info",
  "msg": "user.signup",
  "trace_id": "01HZ...",
  "span_id": "...",
  "service": "api-auth",
  "env": "prod",
  "user_id": "u_123",
  "duration_ms": 47
}
```

- **이벤트 이름은 스네이크케이스 명사** (`user.signup`, `payment.charged`) — 분석 쿼리 일관성
- PII 는 `user_id` 같은 ID 만, email/phone 직접 로깅 금지
- 스택 trace 는 `error.stack` 필드로 분리 (검색 가능)

## 2. OpenTelemetry (OTel)

OTLP 프로토콜로 Tempo / Jaeger / Datadog / Honeycomb 등에 단일 export.

### 백엔드 (Kotlin / Go / Python)

| 스택 | 핵심 의존성 |
|------|------------|
| Kotlin | `io.opentelemetry:opentelemetry-spring-boot-starter` (auto-instrument) |
| Go | `go.opentelemetry.io/otel` + `otelgin` (Gin) + `otelgorm` (DB) |
| Python | `opentelemetry-distro` + `opentelemetry-instrumentation-fastapi` |

환경변수 (모든 스택 공통):
```bash
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
export OTEL_SERVICE_NAME=api-auth
export OTEL_RESOURCE_ATTRIBUTES=env=prod,version=$VERSION
```

### 프론트엔드 (Next.js)

```ts
// instrumentation.ts (Next.js 13+)
import { registerOTel } from '@vercel/otel';
registerOTel({ serviceName: 'web' });
```

### 모바일 (Flutter)

OTel 공식 Dart SDK 미성숙 — `sentry_flutter` 또는 `firebase_performance` 사용.

## 3. 에러 추적

| 스택 | 권장 |
|------|------|
| Kotlin / Go / Python | Sentry SDK (가장 보편) 또는 DataDog APM (이미 인프라 있으면) |
| Next.js | `@sentry/nextjs` (build-time wrap) |
| Flutter | `sentry_flutter` (release symbols 업로드 자동) |

**규칙**:
- `error.captured = true` 필드를 로그에 같이 — Sentry 전송 여부 추적
- 4xx 는 보통 Sentry 안 보냄 (사용자 입력 오류). 5xx 만.
- `before_send` 훅에서 PII 제거

## 4. SLO / SLI 정의

서비스마다 **3개 이내** SLI 만 정의 (관리 가능 범위).

| SLI | 측정 | 일반 SLO |
|-----|------|---------|
| Availability | 5xx 비율 | 99.9% (월 43m 다운) |
| Latency p99 | 핵심 endpoint 응답 시간 | < 500ms |
| Error rate | 4xx + 5xx / total | < 1% |

PromQL 예시 (Prometheus):
```
# Latency p99 (Gin / OTel auto)
histogram_quantile(0.99, rate(http_server_duration_milliseconds_bucket[5m]))

# Error rate
sum(rate(http_server_request_count{status=~"5.."}[5m]))
  / sum(rate(http_server_request_count[5m]))
```

## 5. 의식적 배제

- **`println` / `console.log` 직접 사용 금지** — 구조화 로거 거치지 않으면 trace_id 누락
- **로그에 stack trace 풀 dump 금지** — Sentry 가 별도 캡처. 로그엔 `error.fingerprint` 만
- **trace_id 없이 `request_id` 만** — 분산 호출 추적 불가. OTel 켜면 자동 trace_id 사용 권장
- **모든 함수에 span 만들기** — span 폭증, 비용 증가. **DB 쿼리 / 외부 HTTP / 핵심 비즈니스 단위** 만
- **개발 환경에 OTLP 강제** — 로컬 노이즈. `OTEL_SDK_DISABLED=true` 로 끄기

## 6. 운영 체크리스트

배포 전:
- [ ] structured logger 가 stdout 으로 JSON 출력?
- [ ] `trace_id` 가 모든 로그에 박힘?
- [ ] Sentry DSN 환경변수 주입 (`SENTRY_DSN`)?
- [ ] OTLP endpoint 환경변수 주입?
- [ ] 핵심 endpoint (`/login`, `/checkout` 등) 에 명시 span?
- [ ] 5xx alert 룰 등록 (Grafana / Datadog)?
- [ ] runbook 링크가 alert annotation 에 포함?
