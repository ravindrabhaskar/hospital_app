# 11 — Design System

The reference designs are `docs/design/home_screen_reference.png` (hero home screen) and `docs/design/all_screens_reference.jpeg` (12 screens). Visual language: **white + calm green/mint with restrained accent colors**, rounded cards, soft shadows, friendly illustrated AI assistant.

## Color tokens
| Token | Hex | Use |
|---|---|---|
| `primary` | `#0B5D45` | Primary buttons, active tab, mic button, Ask-AI center FAB |
| `primaryDark` | `#08473A` | Pressed state, headings on mint |
| `primaryLight` | `#1F8A67` | Links, "Normal/Good" status text |
| `mint50` | `#EEF7F2` | Screen background tint, hero cards |
| `mint100` | `#DDEFE5` | Chips, selected date, AI card gradient end |
| `surface` | `#FFFFFF` | Cards |
| `background` | `#F6FAF8` | App background |
| `textPrimary` | `#12211B` | Titles |
| `textSecondary` | `#5B6B64` | Subtitles |
| `border` | `#E3ECE7` | Card borders, dividers |
| `danger` | `#D93A3A` | SOS, errors, heart icon |
| `dangerBg` | `#B3261E` → `#7A1410` | Emergency screen gradient |
| `warning` | `#F2A23A` | Medicine/reminder accent |
| Accent tiles | teal `#E3F4EF`/`#1F8A67`, rose `#FDE8E8`/`#E0474C`, lavender `#EDE9FB`/`#7B61D9`, peach `#FFF0E0`/`#F28C28`, sky `#E6F0FD`/`#2F6FDE` | Quick-action icon tiles (Talk to Doctor, Home Checkup, Upload Report, Order Medicines…) |

Dark mode: background `#0E1714`, surface `#16221E`, primary `#3DBB8C`, text `#E6F0EC`.

## Typography
Font family **Inter** (Flutter: `google_fonts` Inter; web: Inter via next/font). Scale: Display 28/34 bold (greeting name), Title 20/26 semibold, Subtitle 16/22 semibold, Body 14/20 regular, Caption 12/16 medium. Minimum body size 14. Support OS text scaling up to 200% without clipping.

## Shape & spacing
Spacing 4-pt grid (4, 8, 12, 16, 20, 24, 32). Card radius 20, tile radius 16, button radius 28 (pill), input radius 28. Card shadow `0 4 16 rgba(11,93,69,0.06)`. Screen side padding 20.

## Components
- **Bottom navigation**: Home, Care, **Ask AI** (raised circular center button, primary, pulse/ECG icon), Records, Profile.
- **AI hero card**: robot illustration left, "Hi, I'm your AI Health Assistant" + subtitle, pill input "How can I help you today?" with a green mic button.
- **Quick action tile**: 56px rounded-square tinted tile with a colored icon, a 2-line label and a caption.
- **Promo banner**: "Care for every stage of life" with an image and a white pill CTA. It shows only contextual care content, never ads.
- **Insight card**: icon, label, big value, status text in green. Render it **only when real data exists** (HOME-05).
- **Doctor card**: photo, name, specialty, experience, rating, fee, "Available now" green dot, heart/favorite.
- **Date selector**: horizontal day chips, with the selected day in filled primary.
- **Slot grid**: 3 columns of time pills, with the selected pill in filled primary.
- **Primary button**: full-width pill, primary fill, white text, height 52. **Secondary**: outlined primary.
- **Emergency screen**: full red gradient, huge circular white-ringed SOS button, and action cards "Send Location" and "Call Ambulance, Helpline 108".
- **Chat**: assistant bubbles are white with the avatar. User bubbles are primary green with white text. Quick-reply chips are outlined mint. Safety-alert bubbles are red-tinted with a call-to-action.
- **AI content marker**: any AI-generated text carries an "AI-generated · not a diagnosis" label. In the clinician portal, AI summaries sit in a visually distinct (lavender) panel with source chips.

## Accessibility
Touch targets ≥48dp; all icons have semantic labels; color is never the only status signal; contrast AA; screen-reader order follows the visual order; large-text layout tested; voice input is available on the AI screen.

## Localization
English (`en`), Hindi (`hi`) and Telugu (`te`) at launch. All UI strings are localization keys (Flutter ARB / web JSON). Medical terms use the clinician-reviewed glossary and fall back to English for high-risk terms.
