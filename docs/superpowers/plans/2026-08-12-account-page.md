# Account Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a polished, static desktop Account Page that groups multiple preview accounts by provider and supports local account switching.

**Architecture:** Keep all preview data and selection state inside `AccountPage.dart`; render the page as a scrollable column with reusable private widgets for the overview, provider sections, account rows, avatars, and service marks. Do not use `Management`, persistence, or network APIs. Add a focused widget test covering grouped rendering and local switching.

**Tech Stack:** Flutter Material widgets, existing `AppColors`, existing Bootstrap Icons and SVG assets, `flutter_test`.

## Global Constraints

- Desktop `lib/pages/computer/AccountPage.dart` only for production UI changes.
- Static preview data must include multiple accounts for KuGou, NetEase Cloud, Navidrome, and a provider without a dedicated asset.
- Selecting an account updates only widget-local state.
- Do not add dependencies, gradients, decorative images, or data-layer integration.

### Task 1: Add the failing Account Page widget test

**Files:**
- Create: `test/account_page_test.dart`

**Interfaces:**
- Consumes: `AccountPage` from `lib/pages/computer/AccountPage.dart`.
- Produces: behavioral coverage for provider groups, current account summary,
  and local account switching.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chocolate_music/pages/computer/AccountPage.dart';

void main() {
  testWidgets('renders provider groups and switches the current account',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AccountPage())),
    );

    expect(find.text('已连接账号'), findsOneWidget);
    expect(find.text('酷狗音乐'), findsWidgets);
    expect(find.text('网易云音乐'), findsOneWidget);
    expect(find.text('Navidrome'), findsOneWidget);
    expect(find.text('当前使用'), findsOneWidget);

    await tester.tap(find.text('晚风与海'));
    await tester.pumpAndSettle();

    expect(find.text('晚风与海'), findsWidgets);
    expect(find.text('网易云音乐 · 当前使用'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/account_page_test.dart`

Expected: FAIL because the current `AccountPage` placeholder does not render
the provider groups or the `晚风与海` account.

### Task 2: Implement the static Account Page

**Files:**
- Modify: `lib/pages/computer/AccountPage.dart`

**Interfaces:**
- Consumes: `AppColors`, existing SVG assets, Material and Bootstrap Icons.
- Produces: `AccountPage`, with private `_ProviderPreview` and
  `_AccountPreview` models and local `_selectedAccountId` state.

- [ ] **Step 1: Replace the placeholder with static preview models**

Define ordered providers for KuGou (2 accounts), NetEase Cloud (3 accounts),
Navidrome (1 account), and a `Echo Radio` provider without an SVG asset. Use
stable IDs and avatar initials; initialize the first KuGou account as selected.

- [ ] **Step 2: Build the scrollable page shell**

Render a `SingleChildScrollView` with `20px` horizontal and `24px` vertical
padding, the title `账号`, a current-account overview panel, and the provider
directory. Use `LayoutBuilder` so the overview changes from a row to a column
below `620px` available width.

- [ ] **Step 3: Build reusable visual pieces**

Implement private widgets for:

- service marks using `SvgPicture.asset` with a music-note icon fallback;
- stable circular avatar placeholders;
- provider headers with account counts;
- fixed-height animated account rows with hover, selected leading indicator,
  current label, and chevron.

Keep the existing light palette and use `AppColors.floating` for hover,
`AppColors.selected` for selection, and `AppColors.border` for dividers.

- [ ] **Step 4: Wire local switching only**

On row tap, set `_selectedAccountId` and animate the overview content. No
`Management` listeners or service calls are allowed.

### Task 3: Verify and refine

**Files:**
- Modify: `test/account_page_test.dart` only if assertions need stable semantic
  selectors.

- [ ] **Step 1: Run the focused widget test**

Run: `flutter test test/account_page_test.dart`

Expected: PASS with zero failures.

- [ ] **Step 2: Run analyzer and full tests**

Run: `flutter analyze`

Run: `flutter test`

Expected: both commands exit with code 0; no new diagnostics or test failures.

- [ ] **Step 3: Review the diff**

Run: `git diff --check` and `git status --short`.

Confirm only the Account Page, its focused widget test, and the approved design
documents are changed.
