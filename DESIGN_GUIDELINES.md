# Pawse Design Guidelines

Pawse should feel like a considerate macOS companion: calm while the user is focused, clear when rest is ready, and never punitive. The sleeping white spitz represents permission to pause rather than an alarm demanding attention.

## Principles

1. **Native** — Start with standard macOS materials, controls, typography, spacing, focus behavior, and accessibility. Brand styling supports the platform instead of replacing it.
2. **Calm** — Keep screens quiet and legible. Prefer one clear action, restrained contrast, and progressive emphasis.
3. **Kind** — Use inviting, sentence-case language. A delayed break is not an error and must never look like one.
4. **Restful** — Motion is slow and purposeful. Avoid flashing, shaking, countdown anxiety, or decorative continuous animation.
5. **Private** — Explain local storage and aggregate idle detection in direct language without vague claims.

## Brand Assets

`PawseLogo` and `PawseHUDMascot` use the same head-only sleeping puppy master. `PawseBanner` is a calm mountain-and-lake background with no baked-in character; the UI places the separate logo and typography over it.

- Show the logo at no less than 36 pt; 44 pt is the standard reminder size.
- Preserve its aspect ratio and transparent background. Do not crop, recolor, stretch, rotate, or place text over it.
- A cream circle is the preferred small-format backing when the surrounding material is variable.
- Use the banner only where a wide illustrative surface is appropriate, such as the Timers introduction. Use a 12 pt continuous corner radius. Never place a second mascot, text, or logo directly inside the banner bitmap.
- Keep the menu-bar mark monochrome and template-compatible. It is a dog head only: use the dedicated simplified side-profile template asset when the dog style is selected; never add a body or tail, and never shrink the full-color illustration into the status item. Keep either center mark legible inside the progress ring.

The dog is one fixed animated character across every full-color surface: a rounded cream-white puppy or gentle wolf-pup head, one upright triangular ear, one relaxed ear, a short canine muzzle, a prominent navy oval nose, closed curved eyes, a small content smile, deep-navy outlines, pumpkin-orange inner-ear accents, and one orange `Z`. The full-color mark is head-only. It never includes paws, a torso, realistic fur, whiskers, or scenery. Keep the shapes broad and smooth enough to read at 24 pt.

Treat the brand mark like a frame from a simple 2D animation, not a pet portrait: bold silhouette, cel-like flat shapes, minimal internal detail, friendly asymmetry, and no hair-by-hair rendering. Do not change the ear arrangement, muzzle, nose, line weight, or rendering technique between the Logo, HUD mascot, and App Icon.

The silhouette must read as a dog before decoration is added. Never use a feline muzzle, tiny cat nose, whiskers, curled tail, resting paws, or a circular sleeping-body pose. At menu-bar size, continue using the dedicated monochrome side-profile asset rather than shrinking the full-color character.

## Color

Brand colors are accents. Normal app content continues to use semantic macOS colors such as `primary`, `secondary`, native materials, and system control tints.

| Token | Hex | Use |
| --- | --- | --- |
| Ink | `#0D2B6D` | Text over the illustrated banner and dark brand linework |
| Cream | `#FFF5E3` | Logo backing and warm resting surfaces |
| Pumpkin | `#FF7A17` | Ear, breathing, progress, and attention accents |
| Lake | `#61CFD6` | Calm illustrative water surfaces |
| Mountain | `#9CC9D9` | Quiet illustrative depth |

Do not use red for a normal break reminder. Reserve system red and destructive roles for genuinely destructive actions such as confirming Emergency Exit or deleting data. Pumpkin is a restrained brand accent, not an alarm color. Do not use gradients as chrome or inside brand illustrations.

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

- 44 × 44 pt head-only sleeping-dog mascot.
- “Break soon” or “Long break soon,” plus “Click to start.”
- A native play symbol on the trailing edge.
- A thin neutral border and a pumpkin progress bar.

### Ready (after 15 seconds)

- Change the title to “Break ready” or “Long break ready.”
- Use a 2 pt pumpkin border, a light warm inner tint, and a slow 1.2-second pulse.
- Let the dog breathe between 100% and 106% scale.
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

Do use native materials, semantic color, sentence case, a single clear action, and the sleeping dog as a gentle brand cue.

Do not use red warnings for expected states, all-caps banners, warning icons, thick orange outlines, dark alarm gradients, oversized marketing text, or a row of competing pill buttons in a compact utility HUD.
