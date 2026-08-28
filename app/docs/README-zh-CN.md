# MaxUsage

<p align="left">
  <a href="../../README.md">English</a> | <strong>简体中文</strong>
</p>

根据实时剩余额度与重置时间，智能推荐当前最该使用的 AI 编程订阅（Claude、Codex、Antigravity 等）。

<p align="center">
  <img src="../assets/recommendation-zh-v2.jpg" alt="MaxUsage 智能推荐" />
</p>
<p align="center">
  <img src="../assets/quotas-zh-v2.jpg" alt="MaxUsage 额度总览" />
</p>

---

## 为什么需要 MaxUsage？

我同时订阅了 5 个不同的 AI 编程工具。每次开始写代码前，我总要纠结：**“现在该用哪一个，才能在重置前把额度用满，避免浪费？”**

每天手动去查 5 个服务的网页后台非常繁琐耗时：

<p align="center">
  <img src="images/claude-code.jpg" alt="Claude Code 用量" width="700" /><br/><br/>
  <img src="images/codex.jpg" alt="Codex 用量" width="700" /><br/><br/>
  <img src="images/agy.jpg" alt="Antigravity 用量" width="700" /><br/><br/>
  <img src="images/opencode%20go.jpg" alt="OpenCode 用量" width="700" /><br/><br/>
  <img src="images/z.ai.jpg" alt="Z.ai 用量" width="700" />
</p>

**MaxUsage 让这一切只需 1 秒** —— 它在本地自动分析你所有订阅的剩余额度与重置窗口，直接告诉你下一刻最该打开谁。

---

## 安装方式

### Homebrew 一键安装（推荐）

```sh
brew install 1c7/tap/max-usage
```

### 直接下载安装包

前往 [GitHub Releases](https://github.com/1c7/max-usage/releases/latest) 下载最新的 Universal DMG 安装包，打开后将 **MaxUsage** 拖入 `/Applications`（应用程序）文件夹即可。

> **系统要求**：macOS 15 (Sequoia) 或更高版本。原生支持 Apple Silicon (M系列芯片) 与 Intel 架构 Mac。

---

## 文档与开发指引

- **功能与使用文档**：查阅 [完整文档中心](README.md) 了解支持的服务商、快捷键、代理设置、CLI 命令行以及本地 HTTP API。
- **开发者指引**：查阅 [开发与架构指南](development.md) 了解本地编译、运行测试、发布流程与架构设计。

---

## 鸣谢与致谢 (Acknowledgements)

**MaxUsage** 由 [郑诚 (Cheng Zheng)](https://github.com/1c7) 开发与维护。

本项目基于优秀的开源项目 [OpenUsage](https://github.com/robinebers/openusage)（由 [Robin Ebers](https://itsbyrob.in/x)、[Mert](https://github.com/validatedev) 与 [David](https://github.com/davidarny) 原创开发）进行深度定制与重构。非常感谢原作者团队为开源社区做出的卓越贡献！

---

## 开源协议

[MIT](../../LICENSE)
