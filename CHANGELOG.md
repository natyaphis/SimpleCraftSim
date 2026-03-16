# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

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
