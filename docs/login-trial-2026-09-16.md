# 首次登录体验会员（1.0.7+55）

- 成功创建登录会话时，由服务器给尚未领取体验的免费账号发放连续 72 小时 PRO。手机注册登录、密码登录、Apple/Google 登录共用该规则。
- 重复登录、换设备和重新安装不会重置到期时间。已有体验记录不重复领取，已付费会员不覆盖权益。现有未领取体验的免费账号可在下次成功登录时领取。
- 删除完成训练赠送会员的客户端逻辑，旧 `/v1/membership/trial/activate` 接口返回 410。训练识别次数奖励不属于会员赠送，本次保留。
- 训练中的 AI 入口、聊天请求均要求有效会员，体验会员可使用；普通 AI 页面原有规则保持不变。
- 服务器已部署 `/opt/kilo/releases/login-trial-20260916`，部署前 70 项测试通过，部署后健康检查正常。原版与数据库备份位于 `/opt/kilo/backups/login-trial-20260916`。

## Apple 登录私钥

入口：https://developer.apple.com/account/resources/authkeys/list

点击加号创建 Key，勾选 Sign in with Apple，Configure 选择主 App ID `com.kilostrength.kiloStrength`，保存并注册，下载 `.p8` 并记录 Key ID。文件留在安全位置，不提交 Git。

官方步骤：https://developer.apple.com/help/account/capabilities/create-a-sign-in-with-apple-private-key

本次不涉及 Apple 登录私钥配置；账号删除的 Apple 授权撤销仍需此前说明的专用密钥。
