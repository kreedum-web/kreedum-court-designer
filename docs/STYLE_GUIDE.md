# KreedumSports — Style Guide

Reference for every color and font used across the site. Pulled directly
from the current codebase (`src/config/theme.js` and
`src/components/common/GlobalStyle.jsx`) — if you add a new color or font,
update it here too so this stays accurate.

---

## Colors

### Brand tokens (`src/config/theme.js` → `COLORS`)

Use these for anything new. Import with `import { COLORS } from "../config/theme"` and reference as `COLORS.blue`, etc.

| Token          | Hex       | Swatch | Used for |
|----------------|-----------|--------|----------|
| `blue`         | `#2C62E0` | 🔵 | Primary brand blue — CTA buttons, links, accents, active states |
| `blueDark`     | `#1F49B8` | 🔵 | Hero background gradient (darker end) |
| `navy`         | `#0E1A3D` | 🟦 | Primary dark background — header (scrolled), hero, footer, contact section |
| `navySoft`     | `#16234A` | 🟦 | Defined but **not currently used** anywhere — reserved for a secondary dark surface |
| `paper`        | `#F6F8FC` | ⬜ | Light section backgrounds (Stats, Products, Locations) |
| `paperDim`     | `#EEF1F8` | ⬜ | Slightly deeper light background / input borders |
| `tint`         | `#EAF0FF` | 🔷 | Light blue chip backgrounds (ratings badge, gallery arrows) |
| `slate`        | `#4B5568` | ⬛ | Body text on light backgrounds |
| `slateLight`   | `#8A93A6` | ⬛ | Secondary/muted text on light backgrounds (labels, captions) |
| `white`        | `#FFFFFF` | ⬜ | Text on dark backgrounds, card backgrounds |

### Accent colors (used inline, not yet tokenized)

These appear directly as hex strings in components rather than in
`COLORS`. Worth promoting to `theme.js` if used again elsewhere.

| Hex | Swatch | Used for |
|-----|--------|----------|
| `#8FADFF` | 🔷 | Light-blue accent text on navy backgrounds (hero highlight word, section eyebrows, checkmarks) |
| `#25D366` | 🟢 | WhatsApp green — background of "Message us on WhatsApp" / "Get my quote" buttons |
| `#08331C` | 🟢 | Dark green text on the WhatsApp buttons above |

### Transparency overlays (rgba, derived from brand colors)

Rather than new colors, most overlays are `navy` or `white` at different
opacities:

- **Navy overlays** — `rgba(14, 26, 61, X)` where `X` ranges 0–0.92.
  Used for photo gradient overlays (Products, Gallery cards), header
  shadow, carousel arrow backgrounds.
- **White overlays** — `rgba(255, 255, 255, X)` where `X` ranges 0.06–0.95.
  Used for text/border opacity on navy backgrounds (nav links, form
  backgrounds on the Contact section, subtle dividers).

If you need a new overlay, prefer `rgba(14,26,61,X)` on light backgrounds
or `rgba(255,255,255,X)` on dark backgrounds rather than introducing a new
base color.

### Form validation

- Error text uses Tailwind's built-in `text-red-600` (light backgrounds)
  and `text-red-400` (dark backgrounds) — not a custom token.

---

## Fonts

Loaded once in `src/components/common/GlobalStyle.jsx` via Google Fonts:

```css
@import url('https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;600;700&family=Inter:wght@400;500;600&family=IBM+Plex+Mono:wght@500&display=swap');
```

| Utility class   | Font              | Weights loaded | Used for |
|-----------------|--------------------|-----------------|----------|
| `.font-display` | Space Grotesk (sans-serif) | 500, 600, 700 | Headings (`h1`/`h2`), nav logo wordmark, stat numbers |
| `.font-body`    | Inter (sans-serif)          | 400, 500, 600 | Body copy, paragraphs, buttons, form fields, nav links |
| `.font-mono`    | IBM Plex Mono (monospace)   | 500           | Eyebrows/labels (uppercase tracked text), badges, "Get Directions" |

**If you need a new weight** (e.g. Inter 700 for something bold), add it to
the `@import` URL in `GlobalStyle.jsx` — don't rely on the browser to fake
it, since only the weights above are actually downloaded.

### Type scale in use

| Tailwind class | Approx size | Where |
|-----------------|------------|-------|
| `text-xs`   | 12px | Eyebrows, badges, mono labels, fine print |
| `text-sm`   | 14px | Body copy, buttons, nav links, form labels |
| `text-base` | 16px | Larger body copy, hero paragraph |
| `text-lg`   | 18px | Card titles, section sub-headings |
| `text-xl`   | 20px | "Opening WhatsApp…" confirmation heading |
| `text-2xl`–`text-3xl` | 24–30px | Section `h2` headings (mobile) |
| `text-4xl`  | 36px | Section `h2` headings (desktop) |
| `text-5xl`–`text-6xl` | 48–60px | Hero `h1` (desktop) |

Font weights: `font-medium` (500), `font-semibold` (600), `font-bold` (700)
— matches the weights loaded above, so don't apply a weight class that
doesn't have a corresponding `wght@` value in the import URL.

---

## Quick rules for future development

1. **New color?** Add it to `COLORS` in `src/config/theme.js` first, don't
   hardcode a new hex in a component.
2. **New font?** Update the Google Fonts `@import` in `GlobalStyle.jsx`
   *and* this doc.
3. **Overlay/transparency?** Reuse `navy` or `white` at an opacity rather
   than inventing a new base color.
4. **Keep this file in sync** — it's meant to be the single source of
   truth for anyone (including future-you) deciding what color or font to
   reach for.
