# MaxUsage

<p align="left">
  <a href="../../README.md">English</a> | <strong>简体中文</strong>
</p>

如果你订阅了 2 个以上 AI 套餐，想最大化用量，本软件会根据剩余额度与重置时间，智能推荐应该用哪一个 AI 订阅套餐来最大化用量。

<p align="center">
  <img src="../assets/recommendation-zh-v2.jpg" alt="MaxUsage 智能推荐" />
</p>
<p align="center">
  <img src="../assets/quotas-zh-v2.jpg" alt="MaxUsage 额度总览" />
</p>

---

## 故事背景

我（本软件作者）订阅了 6 个 AI 套餐（如下图）。我想知道如何用量最大化，手动查 6 个用量非常麻烦：

<p align="center">
  <strong>Claude Code</strong><br/>
  <img src="images/claude-code.jpg" alt="Claude Code 用量" width="700" /><br/><br/>
  <strong>Codex</strong><br/>
  <img src="images/codex.jpg" alt="Codex 用量" width="700" /><br/><br/>
  <strong>agy（Antigravity，Google 出品）</strong><br/>
  <img src="images/agy.jpg" alt="Antigravity 用量" width="700" /><br/><br/>
  <strong>OpenCode</strong><br/>
  <img src="images/opencode%20go.jpg" alt="OpenCode 用量" width="700" /><br/><br/>
  <strong>GLM Coding Plan</strong><br/>
  <img src="images/z.ai.jpg" alt="Z.ai 用量" width="700" /><br/><br/>
  <strong>SuperGrok</strong><br/>
  <img src="images/grok-usage.jpg" alt="Grok 用量" width="700" />
</p>

MaxUsage 分析所有订阅的剩余额度与重置时间，直接告诉你应该先用哪一个

---

## 安装方式 1：Homebrew（推荐）

```sh
brew install 1c7/tap/max-usage
```

### 安装方式 2：下载安装包

前往 [GitHub Releases](https://github.com/1c7/max-usage/releases/latest) 下载最新的 Universal DMG 安装包，打开后将 **MaxUsage** 拖入 `/Applications`（应用程序）文件夹即可。

> **系统要求**：macOS 15 (Sequoia) 或更高版本。原生支持 Apple Silicon (M系列芯片) 与 Intel 架构 Mac。

---

---

## 备注

**MaxUsage** 由 [郑诚 (Cheng Zheng)](https://github.com/1c7) 开发与维护。

本项目基于 [OpenUsage](https://github.com/robinebers/openusage)（由 [Robin Ebers](https://itsbyrob.in/x)、[Mert](https://github.com/validatedev) 与 [David](https://github.com/davidarny) 原创开发）进行深度定制与重构。非常感谢原作者团队。

---

## 开源协议

[MIT](../../LICENSE)
