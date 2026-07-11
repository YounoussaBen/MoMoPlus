# MoMo Plus Design System

> Version 1.0 — implementation contract  
> Status: approved; Batch 0 in progress  
> Updated: 11 July 2026  
> Applies to: Flutter mobile app (`mobile/`)  
> Reference direction: the supplied finance-app and deep-green Healiza images

This document is the source of truth for the MoMo Plus mobile redesign. It defines the visual language, interaction rules, accessibility requirements, implementation boundaries, rollout sequence, and approval process. A screen is not complete because it looks polished in one state; it is complete only when its flow, states, themes, motion, and tests follow this system.

The words **must**, **should**, and **may** are intentional:

- **Must** is required for approval.
- **Should** is the default and needs a reason to break.
- **May** is optional.

---

## 1. Product direction

### Design concept: Quiet Energy

MoMo Plus should feel calm enough for high-stakes money decisions and energetic enough to communicate speed. The visual formula is:

**black/white structure + deep MoMo green action + generous rounded surfaces + exceptionally clear financial information**

The reference work is a direction, not a template. We will adopt its hierarchy, restraint, tonal separation, rounded geometry, and focused use of forest green while keeping MoMo Plus recognizable, accessible, and suited to users and agents in Ghana.

### Product qualities

Every screen should feel:

- **Clear:** the next action and current financial state are immediately understandable.
- **Calm:** no unnecessary boxes, lines, shadows, colors, or competing calls to action.
- **Fast:** common actions stay close to the thumb and avoid unnecessary steps.
- **Trustworthy:** amounts, fees, parties, statuses, and consequences are never hidden.
- **Consistent:** the user and agent experiences share one system even when their tasks differ.
- **Alive:** motion acknowledges input and explains state changes without becoming decoration.

### Non-goals

- Do not copy the reference brand, exact compositions, or visual assets.
- Do not make every surface green or every number oversized.
- Do not hide labels merely to make the interface look minimal.
- Do not trade accessibility or financial clarity for visual similarity.
- Do not visually redesign broken flows without fixing their state and navigation behavior.

---

## 2. Reference-image analysis

### 2.1 Color and theme

The references use a very small palette:

- Near-black is the structural base for dashboards, charts, navigation, and numeric entry.
- White or soft off-white is the base for readable transaction content.
- The original finance references use a bright yellow-lime accent, while the approved Healiza reference uses a calmer solid forest green.
- Deep forest green adds depth without introducing a second competing brand color.
- Pale green and muted gray-green create hierarchy through background tone.

The strongest lesson is restraint. Color is not decoration; it carries meaning. The approved primary is the solid forest green sampled from the Healiza reference (`#2A5F49` in light mode), with a slightly lifted dark-mode variant for surface contrast. The lime in the existing logo may remain a small brand highlight, but it is no longer the primary interface color.

### 2.2 Composition and hierarchy

The reference screens have a consistent reading order:

1. Small navigation or account context.
2. One dominant amount, balance, or task.
3. One primary action or compact segmented choice.
4. Supporting metrics or recent activity.
5. Persistent navigation or completion action.

The screen does not present many equally weighted cards. It establishes one hero, then lets secondary information recede.

### 2.3 Surface separation

Sections are separated by background tone, spacing, and shape—not by strokes or elevation. Common patterns include:

- A dark page with a slightly lighter content section.
- A dark header flowing into a forest-green value surface.
- A green task area flowing into a dark sticky action area.
- A white transaction section placed against a dark or colored upper canvas.
- Muted filled rows nested inside a larger section.

The shadows visible beneath the phones in the supplied images belong to the promotional mockup, not the in-app interface. They are not a UI treatment to copy.

### 2.4 Shape language

- Major cards and sheets use generous 20–28 px corners.
- Controls use 12–18 px corners.
- Filters, statuses, segmented controls, and small actions are pill-shaped.
- Icon actions are circular or rounded-square, with consistent dimensions.
- The shape system is soft, but not bubbly: only one or two large curved surfaces dominate a screen.

### 2.5 Typography

- Financial amounts carry the strongest weight and scale.
- Titles are compact and confident rather than oversized everywhere.
- Labels and metadata are small but retain contrast.
- Numeric data uses tabular figures so values do not jump while changing.
- Weight and size create hierarchy; many text colors are not required.

### 2.6 Iconography

- Icons use a consistent rounded, simple vocabulary.
- Inactive states use outline icons; active states may use filled equivalents.
- Icons sit on a 20–24 px grid and receive generous touch areas.
- Color is reserved for the selected destination, primary action, or meaningful status.
- Chevrons indicate navigation only; decorative chevrons are avoided.

### 2.7 Data visualization

- Charts are part of the page composition rather than framed widgets.
- One green line, a subtle fill, and sparse labels communicate the trend.
- Grid lines and chart chrome are minimized.
- A selected value is shown in a compact pill anchored to its point.

### 2.8 Interaction language inferred from the design

The references suggest direct manipulation: pills switch views, keypad values update in place, charts reveal focused values, and large bottom actions complete the task. MoMo Plus will use short transitions, clear pressed states, purposeful haptics, and bottom-anchored actions for multi-step financial flows.

---

## 3. Core design principles

### 3.1 Financial clarity first

Amounts, currency, fees, repayment terms, counterparties, deadlines, and status must be explicit. Never make the user infer what will happen after pressing a money-related action.

### 3.2 One visual hero per screen

A screen may emphasize one balance, request, task, or status. Other content must be visually quieter. If everything is a card, nothing is important.

### 3.3 Deep green means action or active state

Use brand green for primary actions, selected navigation, selected filters, progress, and focused data. Do not use green as a generic background for unrelated content.

### 3.4 Structure with surfaces, not decoration

Use canvas color, section color, interactive fill, spacing, and rounded clipping to separate content. Structural borders, divider lines, and drop shadows are prohibited by default.

Allowed exceptions are:

- A visible keyboard/accessibility focus indicator.
- A high-risk error state when fill and text alone are insufficient.
- A selected map boundary or chart axis required to understand data.
- Brand marks and real-world document boundaries.

Exceptions must be semantic and cannot be used as general decoration.

### 3.5 Reveal complexity progressively

Show the decision needed now. Put explanations close to the decision, advanced detail behind disclosure, and irreversible consequences in a confirmation step.

### 3.6 Design every state

Loading, refreshing, empty, partial, success, pending, offline, permission denied, validation error, server error, and terminal states are part of the screen—not afterthoughts.

### 3.7 Preserve context

Back navigation, deep links, authentication, connection recovery, and task completion should return users to a sensible place. A user should not lose a filled form or land on an unrelated home screen without explanation.

### 3.8 Motion explains change

Motion should show where content came from, what changed, and whether an action succeeded. It must not delay the task.

---

## 4. Theme architecture

MoMo Plus will support three appearance preferences:

- **System** — follows the device and is the default.
- **Light** — the white theme.
- **Dark** — the black theme.

The setting must persist across launches. Both themes are equal products; dark mode is not a color inversion performed after the light screen is complete.

### 4.1 Theme model

Feature code must use semantic theme values. It must not choose a color because it “looks green” or “looks gray.” For example:

- Use `surfaceSection`, not `Colors.white`.
- Use `textSecondary`, not `Colors.grey`.
- Use `statusWarning`, not `Colors.orange`.
- Use `actionPrimary`, not the legacy `AppColors.primary`.

Flutter implementation should use `ColorScheme` plus a MoMo Plus `ThemeExtension` for roles not covered by Material. A persisted theme controller owns `ThemeMode`. Raw feature-level colors are allowed only for transparent, map-provider content, mobile-network brand marks, photographs, and other real-world assets.

### 4.2 Semantic color tokens

| Token | Light | Dark | Purpose |
|---|---:|---:|---|
| `canvas` | `#F2F8EC` | `#090B09` | App/page background and separation gutters |
| `surfaceSection` | `#FFFFFF` | `#121512` | Primary content sections and sheets |
| `surfaceSubtle` | `#E9ECE6` | `#1A1E1A` | Secondary grouped content |
| `surfaceInteractive` | `#E2E7DF` | `#232823` | Tappable rows, inputs, controls |
| `surfaceDisabled` | `#E1E3DF` | `#252825` | Disabled controls |
| `surfaceInverse` | `#171A17` | `#F4F7F2` | High-contrast inverse surface |
| `textPrimary` | `#0D100D` | `#F6F8F4` | Titles, amounts, primary content |
| `textSecondary` | `#5B625B` | `#A8AFA8` | Supporting body text |
| `textMuted` | `#697069` | `#858C85` | Metadata and tertiary labels |
| `textDisabled` | `#939993` | `#666D66` | Disabled content only |
| `brandAccent` | `#2A5F49` | `#34795D` | Primary action/selection fill |
| `onBrandAccent` | `#FFFFFF` | `#FFFFFF` | Content on primary green |
| `brandStrong` | `#24513F` | `#83D0AB` | Accessible green text/icons |
| `brandSoft` | `#DCEBE4` | `#19372B` | Low-emphasis brand container |
| `navigationSurface` | `#101310` | `#151815` | Bottom navigation |
| `onNavigation` | `#F5F7F3` | `#F5F7F3` | Inactive nav content |
| `success` | `#247A3B` | `#74E59A` | Completed/verified/available |
| `successContainer` | `#E3F6E8` | `#193322` | Success background |
| `warning` | `#8A5900` | `#FFCA72` | Pending/time-sensitive |
| `warningContainer` | `#FFF0D3` | `#3A2A0F` | Warning background |
| `error` | `#B42318` | `#FFB4AB` | Failed/destructive/overdue |
| `errorContainer` | `#FDE7E5` | `#3D201D` | Error background |
| `info` | `#0B63A5` | `#91CAFF` | Neutral informational state |
| `infoContainer` | `#E2F1FC` | `#173047` | Info background |
| `scrim` | `#0000008F` | `#000000A3` | Modal background |

Contrast notes:

- `onBrandAccent` on `brandAccent` is approximately 7.4:1 in light mode and 5.2:1 in dark mode.
- Light `brandStrong` on a white section is approximately 9.0:1.
- Light and dark primary/secondary text combinations meet WCAG AA for their intended sizes.
- White text is the approved foreground on the solid primary green.
- Green text must not be used for long body copy. It is an action/state color.

### 4.3 Hero gradients

Gradients may be used only for a screen's single hero surface, an onboarding illustration background, or a chart fade. They must not be used on ordinary list rows or every card.

- **Primary hero:** solid `brandAccent`; no gradient required.
- **Forest hero:** `#2A5F49` → `#183B29`
- **Dark chart fade:** `#83D0AB33` → `#83D0AB00`

Rules:

- Maximum one prominent gradient per screen.
- Use two or three stops from one color family.
- Keep text contrast valid at every point.
- No gradient may substitute for a status color.

### 4.4 Theme switching behavior

- Theme changes should cross-fade in 180 ms.
- System bars, native launch screen, maps, dialogs, sheets, and overlays must switch with the app.
- Theme changes must not reset navigation, forms, scroll positions, or loaded data.
- Map styling must have explicit light and dark JSON styles.
- The theme preference must be available from Settings as System / Light / Dark, not a misleading binary toggle.

---

## 5. Typography

Use the bundled platform families initially: SF Pro Text on iOS and Roboto on Android. A future brand-font change must be evaluated as its own system-wide decision; screens may not choose custom fonts independently.

| Role | Size / line | Weight | Use |
|---|---:|---:|---|
| `displayAmount` | 40 / 44 | 700 | Hero balance or transaction-entry amount |
| `displayLarge` | 34 / 38 | 700 | Onboarding statement only |
| `screenTitle` | 28 / 34 | 700 | Top-level page title |
| `titleLarge` | 22 / 28 | 700 | Major section/status title |
| `titleMedium` | 18 / 24 | 600 | Section title and modal title |
| `titleSmall` | 16 / 22 | 600 | Row title and card title |
| `bodyLarge` | 16 / 24 | 400 | Primary reading text |
| `bodyMedium` | 14 / 20 | 400 | Supporting text |
| `labelLarge` | 14 / 18 | 600 | Buttons, filters, prominent labels |
| `labelMedium` | 12 / 16 | 600 | Statuses and compact controls |
| `caption` | 12 / 16 | 400 | Metadata; never critical instruction alone |

Rules:

- Currency amounts use tabular figures.
- Hero amounts use no more than two decimal places and may visually de-emphasize decimals without hiding them from accessibility APIs.
- Body copy must not use weights above 500.
- Avoid all-caps except short conventional codes such as `GHS`, `OTP`, or a mobile network name.
- Screen titles are left-aligned unless a focused step or platform convention clearly benefits from a centered title.
- A screen should normally use no more than four text roles.
- Text must scale with device accessibility settings without clipping. Do not globally disable scaling.

### Money formatting

- Display Ghanaian currency as `GHS 1,560.00`.
- Use `GHS` anywhere currency could be ambiguous.
- Keep the sign and amount together when wrapping.
- Read amounts accessibly as “one thousand five hundred and sixty Ghana cedis.”
- Negative, overdue, or owed values require a text label or icon in addition to color.

---

## 6. Layout, spacing, and density

All spacing derives from a 4 px base grid.

| Token | Value | Typical use |
|---|---:|---|
| `space0` | 0 | No gap |
| `space1` | 4 | Tight icon/text relationship |
| `space2` | 8 | Compact internal gap |
| `space3` | 12 | Row/icon gap |
| `space4` | 16 | Default component padding |
| `space5` | 20 | Screen horizontal gutter |
| `space6` | 24 | Section internal padding |
| `space8` | 32 | Major section gap |
| `space10` | 40 | Hero breathing room |
| `space12` | 48 | Large transition spacing |

Rules:

- Default phone horizontal gutter: 20 px.
- Compact phones below 360 logical px may use 16 px.
- Section separation band: 8 px of `canvas`, not a 1 px divider.
- Primary scroll content must clear the bottom navigation or sticky action plus safe area.
- Full-width colored heroes may extend to the screen edge; their content still aligns to the 20 px grid.
- Avoid one-off 2, 3, 6, 10, 14, and 28 px layout gaps unless optical alignment requires it and is documented.
- Respect safe areas and keyboard insets. Sticky actions must remain usable with the keyboard open.

### Responsive behavior

- Design and test at 320, 360, 390, and 430 logical px widths.
- At large text sizes, horizontal field pairs stack vertically.
- Lists and forms should cap readable width on tablets; do not stretch controls across the entire screen.
- Landscape is supported for camera, maps, and essential task recovery even if portrait remains preferred.

---

## 7. Shape and elevation

### Radius tokens

| Token | Value | Use |
|---|---:|---|
| `radiusSmall` | 12 | Compact controls, icon containers |
| `radiusMedium` | 16 | Inputs, buttons, rows |
| `radiusLarge` | 20 | Cards and grouped sections |
| `radiusXLarge` | 28 | Sheets and hero surfaces |
| `radiusPill` | 999 | Chips, segmented controls, statuses |

### No-border / no-shadow policy

- Default elevation is zero.
- `BoxShadow`, `Divider`, and decorative `BorderSide` are prohibited in redesigned feature UI.
- A parent `canvas` and child `surfaceSection` create section separation.
- A `surfaceInteractive` fill indicates a tappable row or field.
- Whitespace separates rows inside a continuous section.
- Modal hierarchy comes from a scrim and a contrasting sheet surface, not a shadow.
- Pressed state comes from fill/opacity/scale, not elevation.

---

## 8. Icon system

Use one rounded Material icon family until a custom icon set is approved.

### Sizes

- 16 px: inline status or metadata.
- 20 px: list row and compact action.
- 24 px: app bar and navigation.
- 28 px: primary feature icon.
- 32 px+: empty-state illustration only, not ordinary controls.

### Rules

- Minimum touch target is 48 × 48 logical px even when the glyph is smaller.
- Use outlined icons for inactive/default state and the matching rounded/filled icon for active state.
- Use `arrow_back_rounded`, `close_rounded`, and `chevron_right_rounded` consistently.
- Do not mix Material and Cupertino icon languages on the same screen.
- Do not place every icon inside a colored tile. Containers are reserved for hero actions, statuses, and important categories.
- Mobile-network logos retain their source colors and must not be recolored by the theme.
- Every icon-only action needs a semantic label.
- Bottom-navigation icons must retain text labels; financial navigation should not rely on icon recognition alone.

Known cleanup: `AppLogo` currently loads the dark logo for both branches. The white branch must use `logo-white.png` when the foundation is implemented.

---

## 9. Core components

### 9.1 Screen scaffold

Every screen should start from a shared scaffold that owns:

- Theme-aware `canvas`.
- Safe area and system overlay style.
- Standard horizontal gutter.
- App bar pattern.
- Bottom navigation/sticky action clearance.
- Loading, error, and offline overlay conventions.

### 9.2 App bar

- Standard height: 56 px plus safe area.
- Prefer a transparent/canvas app bar with a left-aligned title.
- Use a compact logo on dashboard screens only.
- App-bar icon buttons use a 40–48 px tonal hit area with no outline.
- Maximum two trailing actions. Additional actions move to an overflow sheet.
- A solid green app bar is not a default pattern.

### 9.3 Bottom navigation

User destinations: Home, Discover, Activity, More.  
Agent destinations: Home, Earnings, Activity, More.

- Share one implementation; only destination data changes.
- Dock navigation to the bottom instead of floating it over content.
- Use `navigationSurface` with no blur, gradient veil, border, or shadow.
- Selected item uses `brandAccent` and `onBrandAccent`; inactive content uses `onNavigation` at reduced emphasis.
- Keep labels visible at 11–12 px.
- Height: 68 px plus safe area.
- Tab reselection returns the branch to its initial route and may scroll the root screen to top.
- Switching tabs preserves each branch's state.

### 9.4 Buttons

#### Primary

- Forest-green fill, white content, 56 px height, 16 px radius.
- One primary button per visible decision area.
- Use a verb that describes the result: “Request GHS 200”, not “Continue,” when the consequence is known.

#### Secondary

- `surfaceInteractive` fill, `textPrimary` content, no border.

#### Tertiary

- Text/icon only, transparent background.

#### Destructive

- `errorContainer` fill with `error` content.
- Destructive confirmation must name the object/action.

States:

- Press: 0.98 scale and stronger tonal fill over 90 ms.
- Loading: preserve width and label context; show progress without shifting layout.
- Disabled: disabled fill/content, no opacity so low that the label becomes unreadable.
- Success: replace the spinner with a check briefly only when the next state is not immediate.

### 9.5 Inputs

- Filled `surfaceInteractive`; no default outline.
- 56 px minimum height; 16 px radius; 16 px horizontal padding.
- Persistent or floating labels are preferred to placeholder-only fields in financial forms.
- Focus uses caret, label/accent color, and a subtle `brandSoft` fill change.
- Error uses `errorContainer`, error icon/text, and an accessible message. A focus/error ring is an allowed exception when required.
- Prefix/suffix controls retain 48 px targets.
- Numeric and OTP inputs use the appropriate keyboard and autofill hints.
- Amount entry should emphasize one large editable value instead of a row of generic form controls.

### 9.6 Section surface

A section is the primary structural unit.

- Parent page uses `canvas`.
- Section uses `surfaceSection` and 20–24 px internal padding.
- Section corner radius is 20 px when inset; full-width sections may use only top/bottom corners where they transition to another tone.
- Adjacent sections have an 8 px `canvas` band.
- Titles and “See all” actions align on one baseline.

### 9.7 List row

- Minimum height: 64 px.
- Default internal padding: 12–16 px.
- Rows are separated by 8–12 px whitespace or a tonal parent/child change, never a divider line.
- Leading icon/avatar: 40–44 px.
- Title, metadata, value, and status follow consistent alignment.
- Use a chevron only when the entire row opens another destination.
- Amount and status should not compete in the same trailing column.

### 9.8 Hero/value card

- One per screen maximum.
- May use a solid primary-green surface or the restrained forest gradient.
- Amount or current task is the focal point.
- Supporting metrics are limited to two or three.
- Critical actions remain clearly labeled and do not depend on tapping the entire card.
- Do not auto-advance a hero carousel while the user is reading financial data.

### 9.9 Segmented control and filters

- Pill container on `surfaceInteractive`.
- Selected segment uses `brandAccent` in either theme.
- Two to four options maximum before using a sheet/menu.
- Selection animates over 180 ms and updates route/query state when the filter is navigational.

### 9.10 Status treatment

Every status maps to semantic color, icon, and plain language.

| Meaning | Tone | Example labels |
|---|---|---|
| Neutral | Info/neutral | Draft, Scheduled |
| Waiting | Warning | Pending review, Awaiting agent |
| In progress | Brand/info | Sending, Repaying, Meeting set |
| Positive terminal | Success | Completed, Verified, Approved |
| Negative terminal | Error | Rejected, Failed, Cancelled |
| Urgent | Error | Overdue, Action required |

Never show backend enum strings directly. Never rely on color alone.

### 9.11 Bottom sheets and dialogs

- Use bottom sheets for contextual choices, filters, explanations, and short confirmations.
- Use full screens for multi-step tasks, maps, cameras, forms with keyboards, and lengthy content.
- Sheets use 28 px top corners and `surfaceSection`; no top border or shadow.
- A small drag handle may use a muted filled pill.
- Destructive or irreversible actions require explicit confirmation.
- Do not mix Cupertino and Material presentation by device unless the entire interaction is intentionally adaptive.

### 9.12 Feedback and notifications

- Success feedback is brief and confirms the result, not just “Success.”
- Error feedback explains what failed and how to recover.
- Top in-app notifications use a tonal surface and one entrance transition; no border or stacked shadows.
- Toasts/snackbars must not cover bottom actions or navigation.
- Notifications must use real data or be removed; hardcoded sample notifications are not shippable.

### 9.13 Loading, empty, error, and offline

- Initial loading: skeleton that matches the final layout.
- Refreshing: keep usable content visible and show a subtle progress affordance.
- Empty: explain the state and offer one relevant action.
- Error: preserve known content when safe, name the failure, and provide retry.
- Offline: show cached data as stale with a clear timestamp when available.
- Permission denied: explain why permission helps and always offer a non-permission fallback where possible.
- No infinite spinner may be the only escape from a blocked financial flow.

---

## 10. Screen patterns

### Dashboard/home

Order:

1. Compact account header and notification action.
2. Greeting or role context.
3. One active financial hero or calm empty hero.
4. Two to four primary quick actions.
5. Current obligations/requests.
6. Recent activity.

Rules:

- Active time-sensitive work comes before promotional or empty content.
- User and agent home screens share the same primitives and state vocabulary.
- A countdown must use stable-width tabular figures and pause when the screen is not visible.
- A carousel may be manually swipeable but must not auto-advance financial content.

### Transaction/activity list

- Default grouping is by time or status, not arbitrary card type.
- Filters are compact and persist in the URL/query state.
- A list item shows type, counterparty, time, amount, and status with a predictable hierarchy.
- Swipe actions are avoided for destructive financial operations.

### Transaction/loan detail

Order:

1. Plain-language status.
2. Amount and role/counterparty.
3. One next action.
4. Timeline or progress.
5. Terms, fees, wallet, meeting, or payment details.
6. Help/cancellation when eligible.

The role × status combination determines content. Detail screens must be tested against the full state matrix rather than only the happy path.

### Money entry

- Make the amount the visual focus.
- Always show currency.
- Show available limits or fees before submission.
- Disable submission until the value is valid, and explain why.
- Review high-impact details before committing.
- Keep the final action reachable above the keyboard.

### Map/discovery

- Map and list are two views of the same agent data and selection.
- A draggable tonal sheet presents results without shadow.
- Selected map markers and selected list rows stay synchronized.
- Location-disabled, denied, loading, empty, error, and approximate-location states are designed explicitly.
- Provide a list/manual-location fallback and semantic descriptions for nonvisual users.

### Onboarding and compliance

- Explain why information is needed before asking for it.
- Show progress by named step, not an unexplained bar alone.
- Allow safe back navigation without losing completed draft data.
- KYC status has explicit loading, not started, pending, rejected, approved, and error states.
- Pending users must have refresh, support, and sign-out paths.
- A load failure must never be interpreted as permission to start a duplicate submission.

---

## 11. Motion and haptics

### Motion tokens

| Token | Duration | Use |
|---|---:|---|
| `instant` | 90 ms | Press/opacity response |
| `fast` | 150 ms | Icon and small-state change |
| `standard` | 220 ms | Route and content transition |
| `emphasized` | 320 ms | Sheet, success, major state change |
| `data` | 420 ms | Chart draw or amount update |

Easing:

- Enter: `easeOutCubic`.
- Exit: `easeInCubic`.
- Shared/state transition: `easeInOutCubic`.
- A light spring may be used for a user-dragged sheet, never for error or money confirmation copy.

### Transition rules

- Forward route: fade + 8 px upward/leftward movement depending on platform hierarchy.
- Back route: reverse the forward direction.
- Modal: rise from bottom with scrim fade.
- Tab switch: 150 ms cross-fade; do not slide the whole navigation stack.
- Selection pill: animate position/fill for 180 ms.
- Amount updates: subtle cross-fade or digit roll only when it improves comprehension.
- Chart: draw once on entry; do not restart on every rebuild.
- Success: compact confirmation, then move to the result state.

### Haptics

- Light: navigation selection, chip selection, keypad entry.
- Medium: successful high-intent confirmation.
- Warning: destructive confirmation or failed verification only when appropriate.
- Never vibrate repeatedly for polling, countdowns, or passive status changes.

### Reduced motion

When reduced motion is enabled:

- Replace translations, springs, looping Lottie, shimmer, and chart drawing with short fades or static states.
- Remove forced animation delays.
- Preserve feedback through text, icon, and haptic settings that the user permits.

---

## 12. Accessibility and trust requirements

- Normal text contrast: minimum 4.5:1.
- Large text and meaningful UI graphics: minimum 3:1.
- Touch target: minimum 48 × 48 logical px.
- Support text scaling to at least 200% for essential flows.
- Never communicate status, selection, or error with color alone.
- Provide semantic labels for icon actions, charts, avatars, network logos, and map markers.
- Announce async completion and errors to assistive technologies.
- Focus order follows the visual/task order.
- Keyboard focus remains visible; this is an approved border exception.
- Sensitive values may be obscured, but the user controls reveal/hide behavior.
- Confirm the amount, counterparty, source wallet, destination, and fees before irreversible actions.
- Countdown timers must also communicate the actual deadline.
- Do not use dark patterns, fake urgency, or preselected consent.

---

## 13. UX correctness gates

Visual redesign must not conceal existing flow defects. The following are foundation-level requirements:

### Session isolation

Loan, transaction, wallet, and agent-profile data must be scoped/reset by authenticated user. Signing out and into another account must never display the previous account's financial data, even briefly.

### Auth bootstrap

Routing must wait for authenticated profile/KYC/guarantor state to resolve. A returning approved user must not flash through KYC or another gate while profile data is loading.

### KYC state model

Loading, not started, pending, rejected, approved, and load error must be distinct states. Pending users need refresh, support, and sign-out. Errors need retry and may not reopen the submission wizard implicitly.

### Durable navigation inputs

Wallet verification, loan request, and transaction creation routes must not force-cast transient maps. Required identifiers belong in durable path/query state or guarded route data, with a recoverable invalid-link screen.

### Return location

Authentication, connection recovery, and prerequisites should preserve a safe intended destination where appropriate.

### Polling and lifecycle

Polling starts only for an authenticated, visible, status-relevant screen; pauses in the background; and stops at terminal states. Duplicate root/detail pollers must be consolidated.

### One state owner

Each feature has one authoritative session-scoped data source. Screens may own form drafts but may not create competing server caches that need manual synchronization.

---

## 14. Flutter implementation contract

The foundation should evolve toward this structure:

```text
mobile/lib/core/ui/
├── theme/
│   ├── app_theme.dart
│   ├── app_theme_controller.dart
│   ├── app_theme_extension.dart
│   ├── app_spacing.dart
│   ├── app_radii.dart
│   └── app_motion.dart
└── widgets/
    ├── app_screen.dart
    ├── app_section.dart
    ├── app_list_row.dart
    ├── app_icon_button.dart
    ├── app_bottom_navigation.dart
    ├── app_status.dart
    ├── app_state_view.dart
    ├── app_button.dart
    └── app_text_field.dart
```

Exact filenames may change, but ownership must remain centralized.

### Code rules

- Feature widgets consume semantic theme roles through context/theme extensions.
- Feature code does not introduce raw hex colors, `Colors.white`, generic gray/orange/blue statuses, `BoxShadow`, or `Divider`.
- Repeated screen-private UI becomes a shared component when it appears twice or is part of the system vocabulary.
- User and agent shells share one implementation.
- User/agent status mapping shares one semantic model.
- Route transitions are centralized in the router.
- Async state uses an explicit loading/data/empty/error model.
- Business behavior is preserved during a visual slice unless the slice explicitly includes a flow change.
- Existing unreachable/legacy screens are not redesigned blindly; consolidate or remove them after route coverage proves they are unused.

### Current baseline to eliminate

The audit found:

- Light theme only; zero feature reads from `ColorScheme`.
- 184 hardcoded `Colors.white` uses across 37 files.
- 29 additional raw hex colors and 275 direct Material color calls.
- 346 inline `TextStyle` declarations.
- 240 inline paddings and 221 inline circular radii.
- 39 dividers, 35 borders, and 16 shadows.
- Duplicate user/agent shells, home patterns, More patterns, status logic, and notification pages.
- Several 1,000–1,800-line screens that must be decomposed as their slices are redesigned.

These numbers are migration indicators, not a reason for a single risky rewrite.

---

## 15. Redesign batches and approval checkpoints

Only one batch is active at a time. Each batch is implemented in both themes, verified, handed to the product owner for device testing, and approved before the next begins. Feedback discovered in a later batch may update the system, but approved screens must then be reconciled.

### Batch 0 — Foundation and correctness

Scope:

- Finalize this document.
- Semantic light/dark themes and persisted System/Light/Dark preference.
- Spacing, radius, motion, icon, status, and typography tokens.
- Shared button, field, section, list row, state view, sheet, and navigation primitives.
- Session isolation, auth bootstrap, guarded route inputs, and KYC state correctness.
- Baseline route/session/theme tests.

Approval proof:

- Theme gallery/component harness in light and dark.
- No stale data after an account-switch test.
- Redirect scenario table passes.
- Text contrast and large-text smoke checks pass.

### Batch 1 — Entry and trust

Screens:

- Splash and onboarding.
- Sign in and sign up.
- Connection error/recovery.
- KYC wizard and all KYC status screens.
- Mandatory guarantor onboarding.

Test focus:

- First launch, returning launch, offline launch.
- Keyboard and validation states.
- Every KYC state and retry path.
- Background approval refresh, support, sign-out, relaunch, and draft recovery.

### Batch 2 — Navigation and dashboards

Screens:

- Shared user/agent bottom navigation.
- User Home and Agent Home.
- Shared Activity.
- Real notifications decision/screen.
- User More and Agent More.

Test focus:

- Both roles and every home state.
- Tab preservation/reselection and Android/iOS back.
- Hidden-tab polling/countdown behavior.
- Light/dark, large text, and reduced motion.

### Batch 3 — Wallet and account prerequisites

Screens:

- Wallet list.
- Add wallet/network selection.
- OTP verification and resend.
- Default/reverify/delete actions.
- Guarantor management.
- Profile and functional appearance settings.

Test focus:

- Success, invalid OTP, timeout, resend, cancel, restoration.
- Keyboard/autofill.
- Returning a selected wallet to the calling flow.
- Cross-account isolation.

### Batch 4 — Discover and agent selection

Screens:

- Map/list discovery.
- Location permission and service-disabled states.
- Radius filter and manual fallback.
- Selected agent preview and agent detail.
- Directions/Street View handoff where retained.

Test focus:

- Permission denied/limited/disabled.
- Loading, empty, partial, error, and content.
- Map/list selection synchronization.
- Screen-reader alternative to map interaction.

### Batch 5 — Get Funds flow

Screens:

- Loan request.
- Borrower and agent loan detail.
- Accept/reject/cancel/disburse/repay/default/failure states.
- Payment history and reason sheets.

Test focus:

- Full role × status matrix.
- Limits, fees, wallet prerequisite, invalid amount.
- Polling lifecycle, deadlines, recovery, and terminal states.

### Batch 6 — Cash Services flow

Screens:

- Cash-in/cash-out creation.
- Meeting-point selection.
- Transaction detail for both roles.
- Verification, accept/reject/cancel, meeting, and dual confirmation.

Test focus:

- Full role × status matrix.
- Location and wallet prerequisites.
- Unsaved-form back behavior.
- Verification and terminal state recovery.

### Batch 7 — Agent workspace

Screens:

- Earnings and filters/charts.
- Availability.
- Limits.
- Service area.
- Certification submission/status.

Test focus:

- Edits propagate immediately to Home and eligibility rules.
- Map light/dark modes.
- Drafts, permission failure, validation, pending/rejected/approved states.

### Batch 8 — Account, support, and release sweep

Screens:

- Remaining profile/settings/support behavior.
- Sign-out and destructive account actions.
- Global empty/loading/error/offline states.
- Consolidation/removal of unreachable legacy screens.

Release proof:

- Golden screenshots for light/dark and key async states.
- Small-phone, large-text, reduced-motion, and screen-reader checks.
- Back, deep-link, restoration, offline recovery, and account-switch regression.
- No redesigned screen contains an unapproved border, divider, or shadow.

---

## 16. Per-batch working agreement

For every batch:

1. **Audit:** document current behavior, data states, entry points, and known defects.
2. **Flow proposal:** state what stays, what changes, and why before large behavior changes.
3. **Implement:** build with shared tokens/components and preserve out-of-scope business behavior.
4. **Verify:** run analysis/tests and inspect all required states in both themes.
5. **Handoff:** provide changed-screen list, test steps, known limits, and screenshots when available.
6. **Owner test:** product owner tests on device/emulator and returns consolidated feedback.
7. **Revise:** address feedback within the same batch.
8. **Approve:** mark the batch approved in the tracker below before opening the next one.

### Approval tracker

| Batch | Status | Approval date | Notes |
|---|---|---|---|
| 0 — Foundation and correctness | In progress | 11 July 2026 | Direction approved; implementation started |
| 1 — Entry and trust | Not started | — | — |
| 2 — Navigation and dashboards | Not started | — | — |
| 3 — Wallet and prerequisites | Not started | — | — |
| 4 — Discover and agent selection | Not started | — | — |
| 5 — Get Funds | Not started | — | — |
| 6 — Cash Services | Not started | — | — |
| 7 — Agent workspace | Not started | — | — |
| 8 — Account/support/release | Not started | — | — |

---

## 17. Definition of done for a redesigned screen

A screen is ready for approval only when:

- It uses semantic tokens and shared components.
- It works in light and dark themes without raw structural colors.
- It has no decorative border, divider, or shadow.
- Primary and secondary hierarchy is immediately clear.
- Financial values and consequences are explicit.
- Loading, empty, error, offline, permission, and success states relevant to it exist.
- Back, deep-link, resume, and keyboard behavior are correct.
- Motion follows tokens and reduced-motion behavior exists.
- Touch targets, contrast, scaling, and semantics pass the accessibility checklist.
- Polling/listeners stop when the screen/session no longer needs them.
- Widget/state/route tests cover meaningful behavior.
- Static analysis and the existing test suite pass.
- Product-owner device testing is complete.

---

## 18. Approved foundation decisions

The following decisions were accepted when Batch 0 began:

1. Use the **Quiet Energy** direction: near-black/white foundations with a solid forest-green accent.
2. Use **white content on primary green**, with accessible theme-specific green variants.
3. Use **tonal section separation** with no decorative borders, dividers, shadows, or navigation blur.
4. Keep **bottom-navigation labels visible** for clarity despite the more icon-heavy reference.
5. Use **System / Light / Dark** appearance choices.
6. Keep the existing platform font families for the first implementation rather than introducing a new font dependency.
7. Make **correctness and session isolation part of Batch 0** before visually redesigning gated financial flows.
8. Begin screen work with **Entry and trust** after the foundation is approved.

This document is now the implementation contract. Material changes discovered during implementation must be recorded here and reconciled across previously approved screens.
