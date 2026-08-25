# Breather Design Guidelines

Breather should feel like a considerate macOS companion: calm while the user is focused, clear when rest is ready, and never punitive. The sleeping cat represents permission to pause rather than an alarm demanding attention.

## Principles

1. **Native** — Start with standard macOS materials, controls, typography, spacing, focus behavior, and accessibility. Brand styling supports the platform instead of replacing it.
2. **Calm** — Keep screens quiet and legible. Prefer one clear action, restrained contrast, and progressive emphasis.
3. **Kind** — Use inviting, sentence-case language. A delayed break is not an error and must never look like one.
4. **Restful** — Motion is slow and purposeful. Avoid flashing, shaking, countdown anxiety, or decorative continuous animation.
5. **Private** — Explain local storage and aggregate idle detection in direct language without vague claims.

## Brand Assets

`BreatherLogo` is the curled, sleeping cat. `BreatherBanner` is the wider night-window illustration.

- Show the logo at no less than 36 pt; 44 pt is the standard reminder size.
- Preserve its aspect ratio and transparent background. Do not crop, recolor, stretch, rotate, or place text over it.
- A cream circle is the preferred small-format backing when the surrounding material is variable.
- Use the banner only where a wide illustrative surface is appropriate, such as the Timers introduction. Use a 12 pt continuous corner radius.
- Keep the menu-bar mark monochrome and template-compatible. Use the dedicated simplified sleeping-cat template asset when the cat style is selected; never shrink the full-color cat illustration into the status item. Keep either center mark legible inside the progress ring.

## Color

Brand colors are accents. Normal app content continues to use semantic macOS colors such as `primary`, `secondary`, native materials, and system control tints.

| Token | Hex | Use |
| --- | --- | --- |
| Ink | `#0F1A52` | Text over the illustrated banner and dark brand linework |
| Cream | `#FFF0DC` | Logo backing and warm resting surfaces |
| Terracotta | `#D96F49` | Primary brand accent and attention state |
| Coral | `#F28D79` | Secondary illustration accent |
| Lavender | `#A795AC` | Quiet supporting accent |

Do not use red for a normal break reminder. Reserve system red and destructive roles for genuinely destructive actions such as confirming Emergency Exit or deleting data. Do not use heavy gradients as chrome.

## Typography and Copy

- Use the system font. Use monospaced digits only for timers.
- Use native text styles (`headline`, `subheadline`, `body`, `caption`) before fixed sizes.
- Use sentence case: “Long break ready,” never “LONG BREAK READY.”
- Prefer short, human copy: “Break soon,” “Click to start,” and “Continue Break.”
- Do not use alarmist copy, warning triangles, artificial urgency, or multiple competing calls to action.

## Layout and Shape

- Base spacing: 8 pt. Common spacing steps: 8, 12, 16, and 24 pt.
- Reminder HUD corner radius: 16 pt, continuous.
- Banner corner radius: 12 pt, continuous.
- Prefer native section grouping and separators over stacks of custom cards.
- Use capsules only when the control or data naturally calls for one. Do not turn every label and action into a pill.

## Native macOS Surfaces

- **Menu bar:** use `MenuBarExtra`, a monochrome template symbol, and a progress ring without countdown text.
- **App window:** use native sidebar navigation, `Form`, `Section`, `Table`, Charts, toolbar controls, and system selection styling.
- **Reminder HUD:** use a nonactivating borderless `NSPanel` hosting an active `.hudWindow` `NSVisualEffectView`. Keep it compact and preserve keyboard focus in the current app.
- **Break overlay:** use the wallpaper or selected local image beneath high-contrast content. Emergency Exit remains reachable on every display.

## Break Reminder States

The HUD is one large pointer target with one purpose: start the scheduled break.

### Waiting (0–15 seconds)

- 44 pt sleeping-cat logo on a cream circle.
- “Break soon” or “Long break soon,” plus “Click to start.”
- A native play symbol on the trailing edge.
- A thin neutral border and a terracotta progress bar.

### Ready (after 15 seconds)

- Change the title to “Break ready” or “Long break ready.”
- Use a 2 pt terracotta border, a light warm inner tint, and a slow 1.2-second pulse.
- Let the cat breathe between 100% and 106% scale.
- Do not force the break. Continued input can defer it indefinitely.
- With Reduce Motion enabled, keep the warm border and tint static and do not scale the logo.

## Motion and Accessibility

- Respect Reduce Motion everywhere; fades should become immediate and reminder scaling should stop.
- Never flash or blink. Attention changes must be gradual and remain readable at every phase.
- All controls must retain native keyboard and VoiceOver behavior.
- Keep countdown accessibility labels stable so VoiceOver is not prompted every second.
- Never communicate a state using color alone; title changes accompany the warm attention treatment.
- Maintain strong contrast over all wallpaper and user-image backgrounds.

## Do / Do Not

Do use native materials, semantic color, sentence case, a single clear action, and the sleeping cat as a gentle brand cue.

Do not use red warnings for expected states, all-caps banners, warning icons, thick orange outlines, dark alarm gradients, oversized marketing text, or a row of competing pill buttons in a compact utility HUD.
