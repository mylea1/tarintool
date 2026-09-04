# KILO Strength Visual System

<!-- impeccable:design-schema 1 -->

## Direction

Performance Bay: a mobile-first training console inspired by gym floor lane markings, competition attempt cards, and equipment calibration labels. It is an operate-first tool, not a marketing dashboard. The interface should feel like a precise instrument that is easy to read between sets.

## Materials and palette

The black-metal and orange Logo is the single brand source. Layout and component geometry stay stable between modes; semantic tokens remap.

Light:

- Cool-gray canvas: `#F2F4F6`
- Frost-white work surface: `#F8FAFB`
- Graphite ink: `#171A1D`
- Slate secondary ink: `#5E6872`
- Logo-orange action: `#D64C0C`
- Bright-orange highlight: `#FF6817`
- Neutral selected container: `#E8EDF1`
- Hairline: `#D7DDE2`

Dark:

- Charcoal canvas: `#0D0B0A`
- Warm-black work surface: `#171310`
- Raised metal surface: `#211A16`
- Warm-white ink: `#F7EEE8`
- Secondary ink: `#C9B8AD`
- Bright-orange action: `#FF7A2F`
- Burnt-orange container: `#4A230F`
- Hairline: `#4B3B32`

Orange is reserved for primary actions, focus, selection and progress. Green remains success, red remains destructive, and data visualizations may retain multiple hues when labels or shape also identify the series. Never use color without a text or icon cue.

## Type and numbers

Use a condensed sports display fallback for workout names and metrics: `Barlow Condensed`, `Arial Narrow`, `Noto Sans SC`, sans-serif. Use a readable sans for body copy: `Barlow`, `Segoe UI`, `Noto Sans SC`, sans-serif. Numeric measurements use tabular figures and never shift the layout when values update.

## Layout grammar

- 8px base spacing; 12px controls; 16px work surfaces; 24px page sections.
- One primary action per screen. Secondary actions sit in quiet rows or menus.
- Mobile is a single vertical task rail with a fixed seven-entry navigation bar. Desktop centers a phone-like work surface without inventing a second information architecture. “我的” is a settings index, not a second dashboard.
- Use hairline dividers and shallow shadows instead of nested decorative cards.
- Keep training pages low-density. Put advanced settings in sheets and details.

## Motion grammar

- Route and sheet transitions: 180–260ms fade/translate, interruptible.
- Completing a set: a short orange-to-success state pulse and count update, not a celebration overlay.
- Progress surfaces: a single seeded particle/line field that pauses when hidden or when reduced motion is requested.
- No looping animation in forms, calendars or long lists.

## Components

- `Primary action`: Logo-orange filled in light mode and bright-orange filled in dark mode, 48px minimum, one per screen.
- `Secondary action`: white or paper surface, hairline border, 44px minimum.
- `Status chip`: text plus semantic color, never color alone.
- `Set type`: native select with the full type label; no icon-cycling interaction.
- `Plan detail`: inspect first; primary start action above secondary save/use actions.
- `Training row`: type select, previous value, weight, reps, RPE and completion control in that order.

## Responsive and accessibility

Test 320, 375, 414, 768, 1024 and 1440 widths. No horizontal page scroll. Set tables may scroll only inside their own list when needed. Every control has a visible focus ring, an accessible name and a 44px hit area. Reduced motion keeps content visible and disables decorative transforms.

## Anti-references

- Dark neon gaming dashboards
- Generic pastel wellness cards
- Unbounded gradient backgrounds
- Icon-only controls for decisions
- Simultaneous hero metrics, charts and CTAs competing on the first screen
