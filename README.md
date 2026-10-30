# Switkher

**Every window. Every tab. One keystroke away.**

Switkher is a keyboard first window and tab switcher for macOS. Search across open windows and browser tabs, then jump straight to the one you need. It lives in the menu bar and keeps its window data on your Mac.

[Website](https://switkher.parikshithv.in/) · [Download the latest release](https://github.com/ParikshithV/Switkher/releases/latest) · [Source](https://github.com/ParikshithV/Switkher)

## Features

- Search windows across displays and Spaces, including minimized windows.
- Find browser and app tabs alongside windows, then expand a window to see its tabs.
- Use typo tolerant search across app names and window titles.
- Assign favorite apps to letters to open their last window or launch them.
- Open the switcher with a shortcut or by holding a modifier key.
- Optionally replace ⌘Tab with window switching.
- Customize shortcuts, sorting, and other behavior from the menu bar.

## Get started

Switkher requires **macOS 14 Sonoma or later**.

1. [Download the latest release](https://github.com/ParikshithV/Switkher/releases/latest) and move Switkher to Applications.
2. Open Switkher and grant Accessibility access when prompted. This lets it inspect and activate windows and tabs.
3. Press **⌥ Space** to search, or hold **⌥** to bring up the switcher.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| **⌥ Space** | Search all windows and tabs |
| **Hold ⌥** | Open the switcher after a short delay |
| **⌥ Tab** | Cycle through recently used windows; release to switch |
| **1–9** | Jump to a numbered result |
| **A–Z** | Open a favorite app assigned to that letter |
| **→** | Expand a window to show its tabs |
| **↑ / ↓** | Move through results |
| **Return** | Switch to the selected result |
| **Esc** | Close the switcher |

Shortcuts can be customized in the menu bar settings. The modifier key and delay for long press can also be changed.

## Privacy

Switkher uses the macOS Accessibility API to find and activate windows and tabs. Window information stays on your Mac; Switkher makes no network requests and collects no analytics. No account is required.

## Build from source

The macOS app is an Xcode project. Open `Switkher.xcodeproj` in Xcode, select the `Switkher` scheme, and build or run it on macOS 14 or later.

The landing page is in `website/` and uses Astro. To run it locally:

```sh
cd website
npm install
npm run dev
```

Build the website with `npm run build`. Deploy with `npm run deploy` when Cloudflare credentials and configuration are available.

## License

Switkher is released under the [MIT License](LICENSE).
