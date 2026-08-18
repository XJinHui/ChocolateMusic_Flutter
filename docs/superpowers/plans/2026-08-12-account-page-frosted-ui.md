# Account Page Frosted UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refine the desktop account switcher into a rounder, lighter, translucent music-library interface without changing its static account-switching behavior.

**Architecture:** Keep all preview state and account-selection callbacks in `AccountPage`. Add semantic account-page color tokens in `AppColors`, then compose the visual layers with Flutter `BoxDecoration`, clipped surfaces, and existing Material interaction primitives. The page background, stage, provider tray, and account directory receive stable keys so widget tests can verify the visual structure without asserting implementation internals beyond their public decorations.

**Tech Stack:** Flutter Material, flutter_svg, flutter_test.

## Global Constraints

- Keep `添加账号` disabled with `onPressed: null`; do not add a dialog, route, persistence, login, or network behavior.
- Preserve KuGou sky blue, NetEase Cloud red, and Navidrome blue as active-stage themes.
- Maintain a 44px minimum provider interaction height, selected semantics, visible focus, and 150–300ms state motion.
- Preserve the current single-scroll responsive layout and hide the record disc below 700px.

---

### Task 1: Add a visual regression contract

**Files:**
- Modify: `test/account_page_test.dart`

**Interfaces:**
- Consumes: `AccountPage` widget.
- Produces: expectations for `account-page-backdrop`, `listening-stage`, `provider-rail-tray`, and `account-directory` keys.

- [ ] **Step 1: Write failing widget tests**

```dart
testWidgets('renders the account page on a cool-mist backdrop', (tester) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountPage())));

  final DecoratedBox backdrop = tester.widget<DecoratedBox>(
    find.byKey(const Key('account-page-backdrop')),
  );
  expect((backdrop.decoration as BoxDecoration).gradient, isNotNull);
});

testWidgets('uses rounded glass surfaces for account controls', (tester) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountPage())));

  expect(find.byKey(const Key('provider-rail-tray')), findsOneWidget);
  expect(find.byKey(const Key('account-directory')), findsOneWidget);
});
```

- [ ] **Step 2: Run the new tests and verify they fail because the visual keys and gradient do not exist**

Run: `flutter test --no-pub test/account_page_test.dart`

- [ ] **Step 3: Add the backdrop and frosted layout surfaces**

```dart
DecoratedBox(
  key: const Key('account-page-backdrop'),
  decoration: const BoxDecoration(
    gradient: LinearGradient(colors: [AppColors.accountMistStart, AppColors.accountMistEnd]),
  ),
  child: ...,
)
```

- [ ] **Step 4: Run the account page tests and verify they pass**

Run: `flutter test --no-pub test/account_page_test.dart`

### Task 2: Refine rounded stage, tray, directory, and record surfaces

**Files:**
- Modify: `lib/theme/app_colors.dart`
- Modify: `lib/pages/computer/AccountPage.dart`
- Modify: `test/account_page_test.dart`

**Interfaces:**
- Consumes: `AppColors.accountMistStart`, `AppColors.accountMistEnd`, glass surface tokens, and existing `_ProviderPreview` themes.
- Produces: current stage and selection interactions with the same keys and semantics as before.

- [ ] **Step 1: Write failing assertions for the 32px listening-stage radius and white record disc**

```dart
final AnimatedContainer stage = tester.widget<AnimatedContainer>(
  find.byKey(const Key('listening-stage')),
);
final BoxDecoration decoration = stage.decoration! as BoxDecoration;
expect(decoration.borderRadius, BorderRadius.circular(32));
```

- [ ] **Step 2: Run the tests and verify the current 24px radius fails the new assertion**

Run: `flutter test --no-pub test/account_page_test.dart`

- [ ] **Step 3: Implement token-driven cool-mist, glass, and rounded-surface refinements**

```dart
static const Color accountGlass = Color(0xDBFFFFFF);
static const Color accountGlassBorder = Color(0xB3FFFFFF);
static const Color accountMistStart = Color(0xFFF3F8FF);
static const Color accountMistEnd = Color(0xFFF9F5FF);
```

- [ ] **Step 4: Run targeted tests, static analysis, and the complete test suite**

Run: `flutter test --no-pub test/account_page_test.dart`

Run: `flutter analyze lib/pages/computer/AccountPage.dart lib/theme/app_colors.dart test/account_page_test.dart`

Run: `flutter test --no-pub`

- [ ] **Step 5: Check the final patch for whitespace errors**

Run: `git diff --check`
