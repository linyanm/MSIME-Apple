# Apple 共通后端接入

`BackendAccountClient.swift` 是 iOS 与 macOS 可复用的账号网络层。服务地址固定为生产 HTTPS，拒绝重定向，禁用 Cookie 和缓存，限制普通 JSON 响应大小；不记录凭据或供应商响应。平台负责 Keychain、登录 UI、会话刷新协调和用户明确开启的同步。

当前已提供渠道查询、登录挑战、登录、刷新、账号资料、修改名称、注销会话与删除账号的传输。网络层存在不代表 UI 已接入或真实账号验收完成。

验证：`swift test --package-path shared/backend`。iOS App 和 ServiceTests 的 XcodeGen 输入包含同一份实现。
