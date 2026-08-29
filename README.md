# MaxUsage

<p align="left">
  <strong>English</strong> | <a href="app/macos/docs/README-zh-CN.md">简体中文</a>
</p>

Intelligently recommends which AI coding subscription (Claude, Codex, Antigravity, OpenCode, Cursor, and more) to use right now to maximize your quotas.

<p align="center">
  <img src="app/macos/assets/recommendation-en-v2.jpg" alt="MaxUsage Smart Recommendation" />
</p>
<p align="center">
  <img src="app/macos/assets/quotas-en-v2.jpg" alt="MaxUsage Quotas Overview" />
</p>

---

## Why MaxUsage?

I subscribe to 6 different AI coding tools and wanted to maximize usage across all of them. Checking each one's usage page by hand is tedious:

<p align="center">
  <strong>Claude Code</strong><br/>
  <img src="app/macos/docs/images/claude-code.jpg" alt="Claude Code Usage" width="700" /><br/><br/>
  <strong>Codex</strong><br/>
  <img src="app/macos/docs/images/codex.jpg" alt="Codex Usage" width="700" /><br/><br/>
  <strong>agy (Antigravity, by Google)</strong><br/>
  <img src="app/macos/docs/images/agy.jpg" alt="Antigravity Usage" width="700" /><br/><br/>
  <strong>OpenCode</strong><br/>
  <img src="app/macos/docs/images/opencode%20go.jpg" alt="OpenCode Usage" width="700" /><br/><br/>
  <strong>GLM Coding Plan</strong><br/>
  <img src="app/macos/docs/images/z.ai.jpg" alt="Z.ai Usage" width="700" /><br/><br/>
  <strong>SuperGrok</strong><br/>
  <img src="app/macos/docs/images/grok-usage.jpg" alt="Grok Usage" width="700" />
</p>

MaxUsage shows all remaining quotas and reset times, and tells you which one to use first.

---

## Download

[Download the latest DMG](https://github.com/1c7/max-usage/releases/latest/download/MaxUsage.dmg), open it, and drag **MaxUsage** into your `/Applications` folder.

### Homebrew

```sh
brew install 1c7/tap/max-usage
```

> **"Apple could not verify..." on first launch?** The DMG is ad-hoc signed, not notarized, so macOS blocks it by default. Go to **System Settings → Privacy & Security**, scroll to the blocked-app notice, and click **Open Anyway** — then open MaxUsage again and confirm. (Or run `xattr -cr /Applications/MaxUsage.app` in Terminal.)

---

## Privacy

MaxUsage is open source and 100% local — it reads credentials already on your Mac and talks only to each provider's own official API, the same one your CLI already uses. Read the full breakdown in [Privacy & Usage Data](app/macos/docs/privacy.md).

---

## Acknowledgements

**MaxUsage** is created and maintained by [Cheng Zheng](https://github.com/1c7), built upon [OpenUsage](https://github.com/robinebers/openusage). Licensed under [MIT](LICENSE).
