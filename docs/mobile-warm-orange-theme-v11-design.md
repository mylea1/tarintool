# KILO mobile warm-orange theme v11

## Product decision

- Target user: the owner and a small TestFlight testing group using KILO during real gym sessions.
- Current workaround: a cool blue utility theme and a test administrator that is unavailable in release builds unless explicitly enabled.
- Minimum useful path: launch -> use `1234 / 1234` -> reach Home -> start a plan or free workout -> complete a set.
- Primary measurable action: successful first-session login and successful workout start/completion.
- Failure cost: TestFlight testers are locked out, or brand color obscures completion/error states during training.

Business judgment: this change most directly affects TestFlight activation and workout task completion; the one-tap test-account affordance removes login friction, while the darker accessible orange identifies primary actions without competing with semantic training states.

## Design reading

Native mobile fitness logging tool; self-use and small testing cohort; bright, lively and elegant rather than promotional; Material 3 warm-orange light system; visual density 6/10, motion 5/10, layout change 2/10.

## Tokens

| Role | Value | Usage |
| --- | --- | --- |
| Background | `#FFF8F2` | App canvas |
| Surface | `#FFFFFF` | Cards, forms, navigation |
| Primary | `#C64F13` | Primary actions and selected navigation |
| Primary bright | `#E76522` | Decorative accent only |
| Primary container | `#FDE2D0` | Selection and low-emphasis emphasis |
| Ink | `#2B1D16` | Main text |
| Muted ink | `#6F594E` | Secondary text |
| Hairline | `#E8D8CD` | Borders and dividers |
| Success | `#26845B` | Completed sets and success feedback |
| Success container | `#E4F4EB` | Completed rows |

White on primary has a contrast ratio of 4.64:1. Success remains green and destructive actions remain red; orange is not reused as a completion/error signal.

## Test-account contract

- Credentials: `1234 / 1234`.
- Enabled in Debug builds or when `ENABLE_TEST_ADMIN=true` is supplied at compile time.
- The Codemagic `KILO iOS TestFlight` workflow supplies the define explicitly.
- A future production/App Store workflow must omit the define.
- The login page exposes a one-tap fill action only when the test account is enabled.

## Acceptance

1. Debug and TestFlight test builds can sign in with `1234 / 1234` and receive administrator/forever-member privileges.
2. A release build without the define rejects the test credentials and removes the convenience affordance.
3. Global Material theme, inputs, cards, navigation and prominent hard-coded blue containers use the warm-orange tokens.
4. Completed sets remain green; errors/destructive actions remain red.
5. Flutter formatting, analysis and tests pass.

Interactive preview: `docs/previews/mobile-warm-orange-theme-v11.html`.
