# Product Hunt 发布素材 — MaxUsage

## Tagline（≤60 字符）

```
The no-brainer way to max out your AI subscriptions
```

## Description

```
I pay for 6 AI coding subscriptions — Claude, Codex, Cursor, Antigravity, OpenCode, and Grok.
MaxUsage sits in your menu bar and tells you which one to use right now, based on remaining
quota and reset time — so nothing goes to waste and nothing runs dry mid-task.

100% local and open source. It reads credentials already on your Mac and only talks to each
provider's own API. Free forever.
```

## First comment（以开发者身份发的第一条评论）

```
Hey Product Hunt 👋

I built MaxUsage because I pay for 6 different AI coding subscriptions and kept either wasting
quota on the wrong one or hitting a wall mid-task on the one I actually needed.

Most usage trackers in this space are just prettier progress bars — they show you numbers, but
you still have to do the math yourself. MaxUsage does the math: it looks at what's left on each
subscription AND when each one resets, and tells you which one to reach for right now.

A few things I care about that I'd love feedback on:
- It's open source and 100% local — no account, no server, no telemetry beyond an anonymous
  opt-out toggle. Your credentials never leave your Mac.
- It's free. I'm not trying to sell you a $5/month usage tracker.

Would love to hear what you think
```

## 竞品定位笔记（给你自己看的，不是发布内容）

PH 上已经有的"又一个用量仪表盘"类竞品：

- **Usage4Claude** —— 只支持 Claude，免费开源，主打"100% local，数据永不离开你的 Mac"，拿到 109 upvotes。说明这个受众确实在意隐私这个点。
- **TokenBar** —— 支持 20+ providers，付费（$4.99–$15），UI 花哨（Liquid Glass、3D 图），但本质还是只展示数字。
- **OpenUsage**（MaxUsage 的上游项目）从没自己上过 PH——这方面没有直接先例要担心。

MaxUsage 跟这两家真正的差异：只有它会**主动推荐**现在该用哪个订阅（按 quota 剩余量 + 重置时间的最早截止算法），而不是单纯展示数字。发布时应该主打这一点，而不是"支持 6 个 provider"这种功能罗列。

## 发布前检查清单

- [ ] Tagline
- [ ] Description
- [ ] First comment（发布上线后马上发）
- [ ] Gallery 图片 —— 1270×760
- [ ] 发布视频（≤60秒，可以不出镜/不配音）—— 还没做
- [ ] Topics/tags —— 至少选 "Menu Bar Apps"，可以再加一个开发者工具类的 tag
- [ ] 链接：`github.com/1c7/max-usage`，勾选 open-source
- [ ] 上线前确认 `v1.1.1` 是最新版，DMG 下载链接能正常下载
