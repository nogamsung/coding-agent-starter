---
name: motion-patterns
description: 애니메이션 판단 기준 — 넣을지 말지(대개 넣지 않는다)와 넣을 때의 토큰. UI 에 모션을 고민할 때 참고.
---

# Motion Patterns

애니메이션을 넣을지 말지, 넣는다면 어떤 재료로 만들지 정하는 기준.
웹(Next.js)·앱(Flutter) 공통. 곡선·시간 토큰의 출처는 프로젝트 `DESIGN.md` (ui-designer 가 관리, 없으면 아래 값을 기본으로).

원본 기준: Emil Kowalski 의 애니메이션 원칙(`emilkowalski/skills` 의 `animate`·
`review-animations`). 이 문서는 그 기준을 스타터의 스택에 맞춰 옮긴 것이다.

---

## 0. 순서대로 판단한다

재료(곡선·시간)를 고르기 전에 **애니메이션을 넣을지부터** 정한다.
1번과 2번을 통과하지 못하면 코드는 0줄이고, 그게 정답이다.

### 1. 애니메이션할 것인가

| 빈도 | 판단 |
|---|---|
| 하루 100회 이상 (키보드 단축키, 목록 사이 이동) | **넣지 않는다.** 끝. |
| 하루 수십 회 (호버, 행 선택) | 거의 안 보일 정도로만, 아니면 없음 |
| 가끔 (모달, 드로어, 토스트) | 표준 애니메이션 |
| 드물게 (온보딩, 완료, 첫 사용) | 여기서만 재미를 부린다 |

**키보드로 시작한 동작은 판단이 아니라 실격이다.** 하루에 수백 번 여는 것에
애니메이션이 붙으면 느리고 겉도는 느낌만 남는다.

업무 도구라면 특히 — 매일 보는 데이터 테이블·결재/작업 목록은 "하루 수십 회" 칸이다.

### 2. 목적을 한 단어로 댈 수 있는가

`피드백` · `공간 연속성` · `상태 표시` · `급격한 변화 완충` · `설명` · `기쁨(드문 경우만)`

못 대면 만들지 않는다. **"멋있어서"는 자주 보는 요소에서는 이유가 안 된다.**
사용자가 읽거나 조작하는 데이터는 멋을 위해 움직이지 않는다.

### 3. 가장 싼 도구부터

| 필요 | 도구 |
|---|---|
| 호버·눌림·색, 클래스로 켜고 끄는 상태 | **CSS transition** |
| 마운트 시 등장, JS 상태 없이 | **CSS `@starting-style`** |
| 페이지가 바쁜 동안에도 안 끊겨야 하는 정해진 모션 | **CSS animation** (메인 스레드 밖) |
| 스프링, 레이아웃 전환, 제스처 | **motion(framer-motion)** — 이미 설치된 앱에서만 |

> **페이드 하나 때문에 모션 라이브러리를 새로 넣지 않는다.** 가장 비싼 선택이다.
> CSS 로 안 되는 게 확인된 다음에 논의한다.

Flutter 는 `AnimatedContainer`·`AnimatedTheme`·`AnimatedOpacity` 로 먼저 해결하고,
그다음이 `AnimationController` 다.

---

## 1. 재료

### 속성
`transform` 과 `opacity` **만**. 레이아웃·페인트를 건너뛰고 GPU 에서 돈다.
`width`·`height`·`margin`·`padding`·`top`·`left` 는 셋 다 유발한다.

`translate()` 의 퍼센트는 **자기 크기 기준**이다 — `translateY(100%)` 는 내용이 뭐든
자기 높이만큼 움직인다. 하드코딩 px 보다 이쪽을 쓴다.

### 곡선 (DESIGN.md 토큰이 있으면 그 값)

| 상황 | 곡선 |
|---|---|
| 들어오거나 나갈 때 | `ease-out` — `cubic-bezier(.23,1,.32,1)` |
| 화면 안에서 이동·변형 | `ease-in-out` — `cubic-bezier(.77,0,.175,1)` |
| 드로어·시트 | `cubic-bezier(.32,.72,0,1)` |
| 등속(마퀴·진행바) | `linear` |

**`ease-in` 은 UI 에 쓰지 않는다.** 브라우저 기본 `ease-out` 도 너무 약하다 —
위 값을 토큰으로 정의해 쓴다(웹은 Tailwind `transitionTimingFunction` 확장, Flutter 는 `Curves`/`Cubic` 상수 클래스).

### 시간

| 대상 | 시간 |
|---|---|
| 버튼 눌림 | 100~160ms → 토큰 `fast`(120ms) |
| 툴팁·작은 팝오버 | 125~200ms |
| 드롭다운·셀렉트 | 150~250ms → 토큰 `base`(180ms) |
| 모달·드로어 | 200~300ms → 토큰 `slow`(240ms) |

**300ms 를 넘기지 않는다.** 180ms 드롭다운이 400ms 짜리보다 반응이 좋아 보인다.

### 스프링은 언제

관성이 붙은 드래그, 사용자가 도중에 되돌릴 수 있는 제스처, 살아 있어야 하는 요소.
그 외에는 쓰지 않는다. 바운스는 0.1~0.3, 업무 화면에서는 사실상 쓰지 않는다.

---

## 2. 절대 하지 않는 것

| 하지 말 것 | 대신 |
|---|---|
| `transition: all` | 바꿀 속성만 명시 |
| `transform: scale(0)` 로 등장 | `scale(0.95~0.97)` + `opacity: 0` |
| 트리거에 붙은 팝오버에 `transform-origin: center` | 트리거 쪽에서 자라게 (모달은 예외 — 중앙) |
| 토스트·토글에 keyframes | transition (중간에 끊고 되돌릴 수 있다) |
| framer-motion 의 `x`/`y`/`scale` prop | `transform` 문자열 — shorthand 는 하드웨어 가속이 안 된다 |
| 부모 CSS 변수로 자식 transform 구동 | 해당 요소에 직접 `transform` (자식 전체 스타일 재계산) |
| 게이트 없는 `:hover` 모션 | `@media (hover: hover) and (pointer: fine)` — 터치는 탭에서 가짜 호버가 뜬다 |
| 한꺼번에 전부 등장 | 40ms 스태거, 5개까지 |

`prefers-reduced-motion` 은 전역 base 스타일에 한 번 깔아 두고 컴포넌트마다 반복하지 않는다.
**"모션을 0으로"가 아니라 "덜·부드럽게"** — 이해를 돕는 전환은 남기고 위치 이동만 없앤다.
Flutter 는 `MediaQuery.disableAnimationsOf(context)` 를 본다.

---

## 3. 자주 쓰는 레시피

### 눌림 피드백 (웹)
```tsx
// transform 만 트랜지션한다
<button className="transition-transform duration-[120ms] active:scale-[0.97] rounded-lg bg-primary ...">저장</button>
```

### 진입 (JS 상태 없이)
```css
.panel {
  opacity: 1;
  transform: translateY(0);
  transition: opacity var(--duration-slow) var(--ease-out),
              transform var(--duration-slow) var(--ease-out);
  @starting-style {
    opacity: 0;
    transform: translateY(8px);
  }
}
```

### 리스트 스태거
```css
.item { opacity: 0; transform: translateY(8px); animation: rise 240ms var(--ease-out) forwards; }
.item:nth-child(2) { animation-delay: 40ms; }
.item:nth-child(3) { animation-delay: 80ms; }
/* 5개까지만. 그 뒤는 지연 없이 */
@keyframes rise { to { opacity: 1; transform: translateY(0); } }
```
스태거는 장식이다 — **재생 중에 조작을 막지 않는다.**

### 강조색 전환 (Flutter 셸)
```dart
AnimatedTheme(
  data: accentTheme,
  duration: AppMotion.base,      // 180ms 토큰
  curve: AppMotion.easeInOut,    // Cubic(.77, 0, .175, 1)
  child: child,
)
```

---

## 4. 리뷰 체크리스트

- [ ] 빈도 표를 통과했는가 (하루 100회짜리에 붙지 않았는가)
- [ ] 목적을 한 단어로 댈 수 있는가
- [ ] `transform`/`opacity` 만 쓰는가
- [ ] 곡선·시간이 토큰에서 왔는가 (하드코딩 `cubic-bezier` 없는가)
- [ ] `ease-in` 이 없는가, 300ms 초과가 없는가
- [ ] 들어온 길로 나가는가 (아래서 올라온 토스트는 아래로 사라진다)
- [ ] 호버 모션에 포인터 게이트가 있는가
- [ ] 빠르게 두 번 누르면 자연스러운가 (keyframes 가 아니라 transition 인가)

**코드로 판단이 안 되는 것**(크로스페이드, 스프링 감각, 리스트 등퇴장 균형)은
지속시간을 2~5배로 늘려 보거나 DevTools 애니메이션 패널에서 프레임 단위로 본다.
그래도 애매하면 다음 날 다시 본다 — 만들 때 안 보이던 게 그때 보인다.
