# 11 — Design System

The reference designs are `docs/design/home_screen_reference.png` (hero home screen) and `docs/design/all_screens_reference.jpeg` (12 screens). Visual language: **plum `#631D3F` + butter `#FFEC8E` on a warm butter-cream background, with restrained accent colors** (brand refresh, 2026-10-01; the original reference images predate it and show the earlier green), rounded cards, soft shadows, friendly illustrated AI assistant.

## Color tokens
| Token | Hex | Use |
|---|---|---|
| `primary` | `#631D3F` (plum) | Primary buttons (butter label), active tab, mic button, Ask-AI center FAB |
| `primaryDark` | `#4A142E` | Pressed state, text on butter |
| `primaryLight` | `#8A3A62` | Links, "Normal/Good" status text |
| `mint50` | `#FFF6CC` | Butter tint: hero cards, unselected chips (token name kept from the green palette) |
| `mint100` | `#FFEC8E` (butter) | Selected chips and nav indicator, highlight tiles, label colour on plum |
| `surface` | `#FFFFFF` | Cards |
| `background` | `#FFFAEB` | App background (butter cream) |
| `textPrimary` | `#2B0E1C` | Titles |
| `textSecondary` | `#6D5361` | Subtitles |
| `border` | `#F0E3C2` | Card borders, dividers |
| `danger` | `#D93A3A` | SOS, errors, heart icon |
| `dangerBg` | `#B3261E` → `#7A1410` | Emergency screen gradient |
| `warning` | `#F2A23A` | Medicine/reminder accent |
| Accent tiles | teal (now a plum tint) `#F7E6EE`/`#8A3A62`, rose `#FDE8E8`/`#E0474C`, lavender `#EDE9FB`/`#7B61D9`, peach `#FFF0E0`/`#F28C28`, sky `#E6F0FD`/`#2F6FDE` | Quick-action icon tiles (Talk to Doctor, Home Checkup, Upload Report, Order Medicines…) |

Dark mode: background `#0E1714`, surface `#16221E`, primary `#3DBB8C`, text `#E6F0EC`.

## Typography
Font family **Inter** for body text, with **Fraunces** (a soft serif, via `google_fonts`) for display, headline and large titles in the apps (web: Inter via next/font). Dark mode uses deep plum surfaces (`#1A0D13` / `#28141E`) with butter as the brand colour. Scale: Display 28/34 bold (greeting name), Title 20/26 semibold, Subtitle 16/22 semibold, Body 14/20 regular, Caption 12/16 medium. Minimum body size 14. Support OS text scaling up to 200% without clipping.

## Shape & spacing
Spacing 4-pt grid (4, 8, 12, 16, 20, 24, 32). Card radius 20, tile radius 16, button radius 28 (pill), input radius 28. Card shadow `0 4 16 rgba(11,93,69,0.06)`. Screen side padding 20.

## Components
- **Bottom navigation**: Home, Care, **Ask AI** (raised circular center button, primary, pulse/ECG icon), Records, Profile.
- **AI hero card**: robot illustration left, "Hi, I'm your AI Health Assistant" + subtitle, pill input "How can I help you today?" with a plum mic button.
- **Quick action tile**: 56px rounded-square tinted tile with a colored icon, a 2-line label and a caption.
- **Promo banner**: "Care for every stage of life" with an image and a white pill CTA. It shows only contextual care content, never ads.
- **Insight card**: icon, label, big value, status text in green. Render it **only when real data exists** (HOME-05).
- **Doctor card**: photo, name, specialty, experience, rating, fee, "Available now" green dot, heart/favorite.
- **Date selector**: horizontal day chips, with the selected day in filled primary.
- **Slot grid**: 3 columns of time pills, with the selected pill in filled primary.
- **Primary button**: full-width pill, primary fill, white text, height 52. **Secondary**: outlined primary.
- **Emergency screen**: full red gradient, huge circular white-ringed SOS button, and action cards "Send Location" and "Call Ambulance, Helpline 108".
- **Chat**: assistant bubbles are white with the avatar. User bubbles are primary plum with white text. Quick-reply chips are outlined butter. Safety-alert bubbles are red-tinted with a call-to-action.
- **AI content marker**: any AI-generated text carries an "AI-generated · not a diagnosis" label. In the clinician portal, AI summaries sit in a visually distinct (lavender) panel with source chips.

## Accessibility
Touch targets ≥48dp; all icons have semantic labels; color is never the only status signal; contrast AA; screen-reader order follows the visual order; large-text layout tested; voice input is available on the AI screen.

## Localization
English (`en`), Hindi (`hi`) and Telugu (`te`) at launch. All UI strings are localization keys (Flutter ARB / web JSON). Medical terms use the clinician-reviewed glossary and fall back to English for high-risk terms.
