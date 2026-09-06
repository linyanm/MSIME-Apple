# iOS 的分发路线还没有决定

这份文档记录一个**尚未做出的决定**，以及不做决定的代价。它不描述现状，现状是：iOS 还没有向终端用户分发过任何东西。

## 问题

iOS 的自定义键盘只能通过 App Store 或 TestFlight 安装，没有第三方分发渠道。而 App Store 的服务条款对下载内容附加了设备数量限制与 DRM，这构成 GPLv3 第 6 节之外的**额外限制**，与 GPLv3 冲突。2010 年 VLC 与 GNU Go 被下架就是这个原因。

这不是理论问题：`README.md` 里已经写明 iOS 产物是未签名的 `.xcarchive`，供有 Developer 账号的维护者自行重签，`release.yml` 也照此发布。也就是说，这条路的终点还没选，代码却在一直往前走。

## 为什么不能简单地「作者自己加个例外」

GPLv3 第 7 节允许版权人为自己的作品附加许可例外，本项目的 Apple 端代码是单一版权人，这部分确实可以自己解决。

卡住的是数据：iOS bundle 里的 `msime.db` 由 [rime-ice](https://github.com/iDvel/rime-ice) 构建，rime-ice 是 GPL-3.0（见 `THIRD_PARTY_NOTICES.txt`）。**第三方 GPLv3 作品的例外必须由其版权人授予**，作者无权代为放行。

## 三个可选路线

**一、只做侧载与 TestFlight，不上 App Store。** 代价是几乎放弃 iOS 的普通用户——TestFlight 有 10000 人上限和 90 天过期，侧载对非开发者不现实。好处是零法律风险、零额外工作，且与项目「100% 开源」的立场最一致。

**二、上 App Store，并解决数据的许可。** 需要向 rime-ice 的维护者取得 App Store 分发的 §7 例外授权，或者把 iOS 的 `msime.db` 换成一份不含 GPL 数据的词库（另建一套来源可控的中文词表）。前者取决于对方是否愿意，后者是实打实的工程量，且会让 iOS 与其他平台的候选质量出现差异。

**三、iOS 前端整体重新授权**（例如改为 MIT / Apache-2.0，仅前端代码）。这不解决 `msime.db` 的问题，因此只有在路线二的数据问题先解决之后才成立，不能单独作为答案。

## 需要做什么

选一条，写进 `README.md` 与 [apple-platform-architecture.md](apple-platform-architecture.md)，并在这里记下决定和理由。**在决定之前，iOS 不应该向 App Store 提交，也不应该在任何面向用户的材料里承诺上架。**

如果倾向路线二，第一步是给 rime-ice 开一个 issue 说明用途并请求授权——这一步成本最低，也最可能推翻或确认整条路线。越早问越好：等到 iOS 快发版才问，答案是「不行」的话，前面所有工作都要重做。
