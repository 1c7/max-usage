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
Hey Product Hunt 👋 I built MaxUsage because I pay for 6 AI coding subscriptions and got tired
of checking 6 different usage dashboards myself — it's open source, 100% local, and free. Would 
love your feedback!
```

## 竞品定位笔记（给你自己看的，不是发布内容）

PH 上已经有的"又一个用量仪表盘"类竞品：

- **Usage4Claude** —— 只支持 Claude，免费开源，主打"100% local，数据永不离开你的 Mac"，拿到 109 upvotes。说明这个受众确实在意隐私这个点。
- **TokenBar** —— 支持 20+ providers，付费（$4.99–$15），UI 花哨（Liquid Glass、3D 图），但本质还是只展示数字。
- **OpenUsage**（MaxUsage 的上游项目）从没自己上过 PH——这方面没有直接先例要担心。

MaxUsage 跟这两家真正的差异：只有它会**主动推荐**现在该用哪个订阅（按 quota 剩余量 + 重置时间的最早截止算法），而不是单纯展示数字。发布时应该主打这一点，而不是"支持 6 个 provider"这种功能罗列。

## 发布视频

`assets/maxusage-launch.mp4` —— 10 秒，1920×1080，无配音。四个镜头，每个刚好够读完：6个订阅的痛点 → 推荐功能(配 Recommended 截图) → 额度总览(配 Quotas 截图) → 隐私免费 + CTA。

素材来源跟 Gallery 图一样，都是拿真实产品截图做的动态排版，不是 AI 生成的假界面。这一步做完了：上传到 YouTube(需要你自己的账号)，把链接填进 PH 表单的 Launch Video 那一栏。

## 图片素材（`assets/` 文件夹）

- `assets/thumbnail-240.png` —— Thumbnail，240×240，从 app 图标导出
- `assets/gallery-ph-slide1.png` —— Gallery 图 1，"Know which subscription to use next"，配 Recommended 面板截图
- `assets/gallery-ph-slide2.png` —— Gallery 图 2，"Every quota. Every reset. One glance."，配 Quotas 面板截图
- `assets/gallery-ph-slide3.png` —— Gallery 图 3，纯文案版，主打 "100% local, open source, free"

三张 Gallery 图都是 1270×760，直接按顺序上传即可。素材是拿 README 里现成的两张产品截图裁出面板部分，配上标题文案合成的，不是新拍的。

## 发布前检查清单

- [x] Tagline
- [x] Description
- [x] First comment（发布上线后马上发）
- [x] Thumbnail（240×240）
- [x] Gallery 图片 —— 3 张，1270×760
- [x] 发布视频（10秒，无配音）—— `assets/maxusage-launch.mp4`，还差你上传到 YouTube 拿链接
- [ ] Topics/tags —— 至少选 "Menu Bar Apps"，可以再加一个开发者工具类的 tag
- [ ] 链接：`github.com/1c7/max-usage`，勾选 open-source
- [ ] 上线前确认 `v1.1.1` 是最新版，DMG 下载链接能正常下载
