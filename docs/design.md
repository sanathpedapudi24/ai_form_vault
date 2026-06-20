---
name: AI Form Vault
description: "Store once. Understand forever. Reuse everywhere."
colors:
  primary: "#6366F1"
  primary-light: "#818CF8"
  primary-dark: "#4F46E5"
  neutral-bg: "#FAFAFA"
  neutral-surface: "#FFFFFF"
  neutral-bg-tertiary: "#E8E8ED"
  text-primary: "#1C1C1E"
  text-secondary: "#6C6C70"
  text-tertiary: "#AEAEB2"
  border-light: "#E5E5EA"
  border-default: "#D1D1D6"
  success: "#34C759"
  warning: "#FF9500"
  error: "#FF3B30"
  info: "#5AC8FA"
  category-identity: "#6366F1"
  category-education: "#5856D6"
  category-finance: "#34C759"
  category-medical: "#FF3B30"
  category-travel: "#FF9500"
  category-family: "#FF2D55"
  category-other: "#8E8E93"
typography:
  display:
    fontFamily: "Inter, -apple-system, sans-serif"
    fontSize: 28
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: -0.5
  headline:
    fontFamily: "Inter, -apple-system, sans-serif"
    fontSize: 22
    fontWeight: 600
    lineHeight: 1.3
    letterSpacing: -0.3
  title:
    fontFamily: "Inter, -apple-system, sans-serif"
    fontSize: 16
    fontWeight: 600
    lineHeight: 1.4
  body:
    fontFamily: "Inter, -apple-system, sans-serif"
    fontSize: 14
    fontWeight: 400
    lineHeight: 1.5
  label:
    fontFamily: "Inter, -apple-system, sans-serif"
    fontSize: 10
    fontWeight: 500
    letterSpacing: 0.5
rounded:
  sm: 8
  md: 12
  lg: 16
  xl: 24
  full: 9999
spacing:
  xs: 4
  sm: 8
  md: 12
  lg: 16
  xl: 20
  xxl: 24
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "#FFFFFF"
    rounded: "{rounded.md}"
    padding: "24px 14px"
  button-primary-hover:
    backgroundColor: "{colors.primary-dark}"
    textColor: "#FFFFFF"
    rounded: "{rounded.md}"
    padding: "24px 14px"
  button-outlined:
    backgroundColor: "transparent"
    textColor: "{colors.primary}"
    rounded: "{rounded.md}"
    padding: "24px 14px"
  card-default:
    backgroundColor: "{colors.neutral-surface}"
    rounded: "{rounded.xl}"
    padding: "{spacing.xxl}"
  input-default:
    backgroundColor: "{colors.neutral-bg-tertiary}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.md}"
    padding: "16px 14px"
  chip-default:
    backgroundColor: "{colors.neutral-bg-tertiary}"
    textColor: "{colors.text-secondary}"
    rounded: "{rounded.full}"
    padding: "12px 6px"
---

# Design System: AI Form Vault

## 1. Overview

**Creative North Star: "The Knowledge Graph"**

AI Form Vault is a document intelligence platform organized around identity — people, facts, and the relationships between them. The design system serves a product that replaces the mental overhead of file cabinets with an AI that understands document *content*. Every screen in the app is a tool, not a canvas; the UI stays quiet so the data speaks.

The system is **Clean & Professional**. It borrows from the iOS Settings / Notes tradition: white surfaces, restrained indigo accent, functional typography, minimal ornament. This is not a brand surface — it is a productivity tool where confidence and clarity are the primary aesthetic goals.

**Anti-reference:** The system explicitly rejects the AI-generated look — no gradient text, no glassmorphism-as-decoration, no purple/cyan dark-mode palettes, no side-stripe accent borders. The app should feel engineered, not generated.

### Key Characteristics:
- White and near-white backgrounds with indigo (#6366F1) as the single accent voice
- Inter typeface across all roles — one family, multiple weights
- Subtle shadow layering for depth (Apple-style), no shadows at rest
- Light and airy components: thin borders, generous whitespace, rounded corners
- iOS-native feel with Cupertino page transitions on both platforms

## 2. Colors

A restrained, single-accent palette. Indigo carries all interactive and semantic weight; the neutral ramp is cool-leaning, close to Apple's system colors.

### Primary
- **Indigo** (#6366F1): Buttons, active states, category identity, navigation active icon. The only accent color. Used sparingly — rarity is the point.
- **Indigo Light** (#818CF8): Gradient partner, hover states, secondary accent.
- **Indigo Deep** (#4F46E5): Pressed state for buttons.

### Neutral
- **Pure White** (#FFFFFF): Card backgrounds, surface, primary app bar.
- **Off-White** (#FAFAFA): Scaffold background, secondary surfaces.
- **Tertiary Gray** (#E8E8ED): Input fill, chip background, skeleton loading.
- **Near Black** (#1C1C1E): Primary body text, headings.
- **Secondary Gray** (#6C6C70): Secondary text, subtitles.
- **Tertiary Text** (#AEAEB2): Placeholder, captions, muted labels.
- **Border Light** (#E5E5EA): Card borders, dividers, subtle separation.
- **Border Default** (#D1D1D6): Stronger borders, active outlines.

### Semantic
- **Success Green** (#34C759): Completion states, verified badges, positive indicators.
- **Warning Orange** (#FF9500): Incomplete fields, pending review, medium confidence.
- **Error Red** (#FF3B30): Missing required fields, errors, destructive actions.
- **Info Blue** (#5AC8FA): Informational banners, helper indicators.

### Category
Six document-category colors mirroring iOS vibrancy: Identity (Indigo), Education (Purple #5856D6), Finance (Green #34C759), Medical (Red #FF3B30), Travel (Orange #FF9500), Family (Pink #FF2D55), Other (Gray #8E8E93). Each used only as the icon container tint in the vault grid — never as surface color.

### Named Rules
**The Accent Scarcity Rule.** The primary indigo appears on ≤10% of any given screen. Its rarity signals interactivity; if everything is indigo, nothing is interactive.

**The White Canvas Rule.** Surfaces at rest are white. Color comes from content (document thumbnails, category icons, semantic badges), not from background tints.

## 3. Typography

**Display Font:** Inter (with -apple-system / system-ui fallback)
**Body Font:** Inter (same family)
**Label Font:** Inter (same family)

**Character:** Single-family restraint. Inter at 400/500/600/700 weights provides the entire hierarchy without font switching. The pairing is with itself — a deliberate choice for a productivity app where loading speed and typographic consistency matter more than display drama.

### Hierarchy
- **Display** (700, 28px, 1.2): Hero stats, large completeness percentages. One per screen max.
- **Headline** (600, 22px, 1.3, -0.3px letter-spacing): Screen titles, profile names, modal titles.
- **Title Medium** (600, 16px, 1.4): Section headers, card titles, list item names.
- **Title Small** (600, 14px, 1.4): Button labels, chip labels, field labels.
- **Body Large** (400, 16px, 1.5): Greeting text, multi-line descriptions.
- **Body Medium** (400, 14px, 1.5): Default body, detail text, document metadata.
- **Body Small** (400, 12px, 1.5): Secondary metadata, timestamps, footnotes.
- **Label Small** (500, 10px, uppercase 0.5px tracking): Badge text, stat labels, small captions.

### Named Rules
**The One Family Rule.** Inter is the only font family. No serif, no mono, no display face. Hierarchy is achieved through weight and size alone.

## 4. Elevation

The system uses **subtle shadow layering** (Apple-style). Surfaces at rest are flat — no shadows. Depth is created through soft shadows on interactive or elevated elements only.

### Shadow Vocabulary
- **Card Rest** (none): Cards are flat at rest. Depth is signaled by the 0.5px light border, not a shadow.
- **Card Elevated** (0 4px 12px rgba(0,0,0,0.04)): Soft, diffuse shadow on press or modal context.
- **Modal / Sheet** (0 -4px 20px rgba(0,0,0,0.08)): Top shadow for bottom sheets and floating panels.
- **Floating Pill Nav** (0 8px 24px rgba(0,0,0,0.08)): Bottom navigation pill, floating above content with frosted glass backdrop.

### Named Rules
**The Flat-By-Default Rule.** No shadows at rest. A shadow is a signal that says "this element is elevated above the surface."

## 5. Components

### Buttons
- **Shape:** Gently rounded (12px). Never pill-shaped except tags/chips.
- **Primary:** Indigo solid fill, white text, 14px vertical padding, 24px horizontal. Hover → Indigo Deep. No shadow at rest.
- **Outlined:** Transparent fill, 1.5px indigo border, indigo text. Used for secondary actions (Download, Cancel).
- **Ghost/Text:** No border, no fill, indigo text on tinted transparent background (alpha 0.08). Used for Sign In, Sign Out.

### Inputs / Text Fields
- **Style:** Tertiary gray fill with no border at rest.
- **Focus:** 1.5px indigo border replaces the fill-only treatment. No glow, no shadow.
- **Error:** Red border, red tinted fill.
- **Shape:** 12px radius. Internal padding 16px horizontal, 14px vertical.

### Cards / Containers
- **Corner Style:** Generously rounded (24px) on standalone cards. Inset cards within sheets use 12-16px.
- **Background:** Pure white.
- **Shadow Strategy:** None at rest.
- **Border:** 0.5px light border on all cards.
- **Internal Padding:** 20-24px for standalone cards.

### Chips / Tags
- **Shape:** Pill-shaped (full radius).
- **Style:** Tertiary gray fill, secondary gray text. Selected → indigo fill, white text.
- **Padding:** 12px horizontal, 6px vertical.

### Navigation
- **Style:** Floating pill with frosted glass (BackdropFilter blur, 75% white opacity). 5 slots: Home, Vault, Add (center, elevated), Search, Profile.
- **Active state:** Indigo icon with 12% indigo background circle.
- **Profile badge:** Red dot when profile is incomplete.
- **Height:** 64px pill, 88px from bottom.

### Profile Section Tiles
- **Style:** Frosted glass card (75% white, blur), 24px radius, 44px gradient icon container, status icon trailing.
- **Padding:** 16px horizontal, 16px vertical.

### Bottom Sheet
- **Style:** White surface, 32px top radius, drag handle (40x4 rounded bar).
- **Padding:** 24px horizontal, 24px bottom, 12px top.
- **Elevation:** Top shadow (0 -4px 20px rgba(0,0,0,0.08)).

## 6. Do's and Don'ts

### Do:
- **Do** use the indigo accent on ≤10% of any screen.
- **Do** keep body text at Near Black (#1C1C1E) for ≥4.5:1 contrast.
- **Do** use subtle shadows only for elevation signaling. Cards at rest are flat.
- **Do** use Inter across the entire app. One family.
- **Do** nest content, not cards. Refactor if a card contains another card.
- **Do** use Cupertino page transitions on both platforms.
- **Do** show confidence scores transparently.

### Don't:
- **Don't** use gradient text, glassmorphism for decoration, or side-stripe accent borders.
- **Don't** use purple/violet gradients or cyan-on-dark palettes (AI-generated look).
- **Don't** pair two similar sans-serifs. Inter is the only family.
- **Don't** use shadows on every card. Flat by default.
- **Don't** use borderRadius > 24px on cards. Pill shapes are for chips/tags only.
- **Don't** nest cards. Use tonal layering instead.
- **Don't** use bounce or elastic easing for transitions.
- **Don't** use text below 12px (bodySmall minimum).
- **Don't** use pure black (#000) text or pure white (#FFF) as background.
- **Don't** hide ambiguity. Show confidence scores instead of fabricating certainty.
