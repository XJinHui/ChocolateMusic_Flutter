# Account Page UI Design

## Goal

Replace the desktop `AccountPage` placeholder with a static account switcher
that feels native to a music player. The page shows one current listening
identity, lets the user browse one music provider at a time, and switches the
current identity only when an account is selected. It must not read or modify
`Management`, local files, or a network service.

## Information architecture

The page has three deliberate layers instead of a stack of similar cards:

1. **Current listening identity.** A single dark stage establishes the active
   account as the page's visual focal point. It contains the profile avatar,
   provider mark, account name, source, and connected-account count.
2. **Provider rail.** A horizontal, keyboard-focusable segmented rail changes
   the account directory context. It includes every provider and its account
   count. It does not change the current listening identity.
3. **Account directory.** A quiet, bordered list shows only the accounts for
   the provider selected in the rail. Selecting a row updates the dark stage
   and moves the rail to that row's provider.

## Static preview model

Preview data remains inside `AccountPage.dart` and is generated from an
ordered provider collection. Each provider has an id, name, optional official
SVG asset, and accounts. Each account has a stable id, nickname, avatar label,
and avatar color. The preview includes KuGou, NetEase Cloud, and Navidrome. A
future provider can still omit an official asset and use the generic
music-note fallback.

## Visual system

The visual identity is a softly illuminated music-library surface, not a
generic settings page. It uses restrained light-glass controls on a clean,
pure white canvas.

- Page canvas: `#FFFFFF`, with no decorative background effects.
- Primary ink: `#18243A` for headings and account names.
- Stage ink: provider-specific blue or red, presented as one uninterrupted
  gradient surface with a low-opacity white border.
- Accent blue: existing `AppColors.selectedText` for active provider and
  selected account; selection is always paired with a check and text.
- Glass surface: translucent white with a soft cool outline and a diffuse
  shadow; it remains sufficiently opaque for text contrast.
- Type scale: 32 page title, 24 active identity, 18 directory title, 16 account
  name, and 12–14 labels and counts.
- Spacing follows an 8px rhythm. The page max content width is 960px.

The distinctive element is a white record-label disc suspended at the right
side of the listening stage. Subtle concentric grooves and a provider-tinted
centre frame the active provider mark. It remains a relevant music artifact,
not a second nested stage, and disappears at narrow widths rather than
competing with the account name.

### Surface refinement

- The stage uses a 32px corner radius and no internal background overlay; the
  account directory uses 28px; provider controls and selected-account insets
  use fully rounded or 18px corners according to their size.
- The provider rail sits in one frosted tray rather than individual hard-edged
  tiles. The selected provider receives a translucent accent fill plus a
  provider-color dot, so color is not its only state indicator.
- Account rows are inset inside the directory and use a rounded selected state
  rather than a vertical selection bar. Hover and focus remain visible through
  gentle surface lifting and clear focus outlines.
- The disabled `添加账号` entry stays visibly unavailable through muted ink,
  translucent fill, disabled semantics, and no click behavior.

## Interaction and accessibility

`添加账号` is currently a disabled placeholder. It has no tap behavior and
does not open a page or dialog; actual login, persistence, and network behavior
remain out of scope.

The current identity stage follows the selected account's provider, not the
provider merely being browsed in the rail. KuGou uses sky blue, NetEase Cloud
uses red, and Navidrome uses its provider blue. The stage border, record-disc
ring, shadow, and avatar ink follow that provider theme while primary text
stays white and secondary content uses high-opacity white for contrast.

- Provider rail controls use Material `InkWell` with visible keyboard focus,
  selected semantics, 44px minimum target height, hover feedback, and a 180ms
  color transition.
- Account rows use the same interaction primitive and announce their provider,
  name, and selected status through `Semantics`.
- The stage content uses an `AnimatedSwitcher` with a 180ms fade/vertical
  transition when an account is selected. Provider filtering uses the same
  contained transition; neither animation moves adjacent layout.
- Long provider names and account names truncate after one line; the full value
  remains available in the semantic label.
- There is no add, delete, logout, persistence, login, or network behavior in
  this UI-only iteration.

## Responsive behavior

At widths below 700px, the record-label disc is omitted and the stage's profile
content receives the full width. The provider rail wraps within the page rather
than introducing horizontal scrolling. The directory remains a single scroll
surface and never nests a scrolling list.

## Validation

- Widget test: provider rail filters the directory without changing the current
  identity; selecting an account updates the current identity and selected
  state.
- `flutter analyze` for changed files.
- Full `flutter test` suite.

## Future data integration

When data integration is approved, adapt a future provider-to-account source to
the page's preview model and dispatch the selected provider/account through
`Management`. The page must not rely on `AccountData.data` provider indexes;
stable provider and account ids remain the integration boundary.
