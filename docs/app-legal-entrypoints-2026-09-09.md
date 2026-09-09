# 应用内法律文档入口

版本：1.0.4+52。

- 登录和注册页面底部提供文档入口，无需登录。
- 会员中心购买按钮上方始终提供入口，购买不可用或加载时仍可查看。
- “我的”设置提供同一入口，保留原有“隐私与 AI 授权”设置。
- 所有平台链接到 https://kilostrength.cn/privacy/ ，发布前已验证 HTTP 200。
- iOS/macOS 额外链接到 Apple 标准 EULA：https://www.apple.com/legal/internet-services/itunes/dev/stdeula/ 。该协议不作为 Android 使用条款展示。
- 使用外部浏览器打开；失败时展示可选择复制的网址。入口使用主题颜色并允许小屏换行。

## App Store Connect 仍需处理

应用内入口不能替代商店元数据。对于使用 Apple 标准 EULA 的版本，请在每种语言的 App 描述中加入完整的使用条款网址，并将隐私政策 URL 填为官网政策地址。若实际采用自定义 EULA，应在 App Store Connect 配置相应协议并同步应用内链接。

本次未修改商店元数据。Android 安装包供查看跨平台改动；iOS 应用内入口需上传包含本次修改的 iOS 构建才会生效。

## 验证

自动测试覆盖：iOS 两个文档链接目标、Android 不展示 Apple EULA、浏览器打开失败后的可复制网址、320px 宽度和 200% 字体下的深浅主题布局。
