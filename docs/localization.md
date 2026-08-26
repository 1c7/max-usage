# Localization

MaxUsage ships in English and Simplified Chinese (简体中文).

## Which language shows

The app defaults to your system language: if your top preferred language is Chinese (any variant: `zh-Hans`, `zh-Hant`, `zh-CN`, etc.), MaxUsage opens in Simplified Chinese automatically; for English and any other language, it defaults to English.

You can also explicitly select your preferred language (System, English, or 简体中文) in **Settings → General → Language**. Choosing an option applies immediately across the app and persists across launches.

## What's translated

Every string the app shows you — dashboard rows, Settings, Customize, notifications, error messages, and provider metric names — is localized. A few things are deliberately left in English everywhere: the app name, provider/brand names (Claude, Codex, Cursor, …), and CLI command names referenced in error messages (e.g. `codex`, `claude`).

## For contributors

String tables live at `Sources/OpenUsage/Resources/en.lproj/Localizable.strings` and `Sources/OpenUsage/Resources/zh-Hans.lproj/Localizable.strings`. This project builds exclusively through `swift build` (see [Architecture](architecture.md)), and SwiftPM's `swift build` only copies `.xcstrings` String Catalogs verbatim rather than compiling them — the String Catalog compiler is Xcode-only — so plain `.strings` tables are the format that actually works here, not `.xcstrings`.

When adding a new user-facing string:
- A literal passed directly to `Text("...")`, `Button("...")`, `Label("...")`, etc. auto-resolves against the tables using the literal English text as the key — add a matching `"English text" = "...";` line to both `.lproj` files.
- A string built dynamically (interpolation, a value computed in a store/model, or anything that reaches `Text` through a `String`-typed variable instead of a literal) does **not** auto-localize. Wrap it with `String(localized: "some.dotted.key", defaultValue: "English text")` at the point where the literal is written, then add matching `"some.dotted.key" = "...";` lines to both tables. Keep `%@` (String) / `%lld` (Int) placeholders positional (`%1$@`, `%2$@`, …) whenever Chinese word order differs from English.
- Run `swift build` after editing the tables — a missing key isn't a build error, it just falls back to the key/English text at runtime, so mismatched keys are easy to miss without a visual check.
