# Changelog

All notable changes to this project will be documented in this file.

## 1.1.5

- Reworked unlock mode to use a lighter implementation centered on reagent quantity helpers and flyout button state updates.
- Removed the previous unlock overrides for slot status, currency info, transaction dependency checks, and profession flyout constructor functions.
- Clear invalid visible reagent allocations when unlock mode is turned off so the form returns to legal owned-material state.
- Moved flyout unlocking to `ProfessionsFlyout*ButtonMixin.UpdateState` so spark and crest entries follow the live Blizzard button pipeline in current clients.
- Stopped writing addon fields onto Blizzard flyout buttons and removed direct `SetEnabled()` calls to reduce taint risk and avoid unrelated protected-action errors.

## 1.1.4

- Maintenance update.

## 1.1.3

- Maintenance update.

## 1.1.2 (Current CurseForge release)

- Maintenance update.

## 1.1.1

- Maintenance update.

## 1.1.0

- Maintenance update.

## 1.0.9

- Limited unlock mode to the currently open professions crafting page instead of leaking into other pages
- Restored original modified reagent flyout behavior immediately when unlock is turned off
- Automatically clears the unlock checkbox when the current crafting page closes or hides

## 1.0.8

- Changed unlock mode to apply only to the currently open crafting page instead of persisting into other professions pages
- Automatically clears the unlock checkbox when the current crafting page closes or hides

## 1.0.7

- Fixed unlock mode for recipes that require four sparks by overriding the modified reagent flyout enable check instead of only changing the displayed quantity

## 1.0.6

- Fixed unlock mode for spark-style modified reagent slots by forcing item-based flyout entries to appear even without a bag instance
- Fixed unlock mode for dependent reagent chains so spark and crest slots no longer stay disabled behind Blizzard dependency checks

## 1.0.5

- Fixed unlock mode for crest-style currency reagents shown in the character currency tab by overriding currency quantities as well as item counts
- Fixed unlock mode to bypass Blizzard's reagent-slot lock check so optional crest slots can actually be opened
- Restored immediate UI refresh when toggling unlock without reintroducing the slot relock issue

## 1.0.2

- Refreshed the professions schematic form and active reagent slots immediately when toggling the unlock checkbox
- Made reagent lock state and `999` quantity display update live when enabling or disabling the override

## 1.0.1

- Initial project setup
- Added a professions crafting unlock checkbox
- Added a live reagent-count override toggle with no reload required
- Added English and Chinese checkbox label support
- Reworked the professions UI control to use an independently created checkbox
- Removed the extra outer frame around the unlock control
- Anchored the unlock checkbox below the tracked recipe checkbox with aligned checkbox positioning
- Switched the unlock label to `GameFontHighlightSmall`
- Reduced the unlock label spacing so the text sits flush against the checkbox
- Added `Media/Logo.png` and `Media/Icon.tga` for project branding and in-game addon list display
- Moved the screenshot into `Asset/` and kept that folder excluded from release packaging
