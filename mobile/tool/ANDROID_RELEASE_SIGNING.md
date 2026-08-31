# Android 发布签名

Release 变体必须使用固定的 Android 发布密钥。项目不会生成密钥，也不会把私钥提交到 Git。

## 必需环境变量

- `KILO_ANDROID_KEYSTORE`：本地 `.jks` 或 `.keystore` 文件的绝对路径。
- `KILO_ANDROID_KEYSTORE_B64`：CI 使用的 Base64 密钥内容。与路径二选一。
- `KILO_ANDROID_STORE_PASSWORD`：keystore 密码。
- `KILO_ANDROID_KEY_ALIAS`：发布 key alias。
- `KILO_ANDROID_KEY_PASSWORD`：发布 key 密码。

本地 PowerShell：

```powershell
$env:KILO_ANDROID_KEYSTORE = 'C:\secrets\kilo-release.jks'
$env:KILO_ANDROID_STORE_PASSWORD = '从安全密码管理器读取'
$env:KILO_ANDROID_KEY_ALIAS = 'kilo-release'
$env:KILO_ANDROID_KEY_PASSWORD = '从安全密码管理器读取'
.\tool\build_android_cn.ps1
```

Codemagic 的 `Environment variables` 中添加同名变量，并将 `KILO_ANDROID_KEYSTORE_B64`、三个密码变量和 alias 标记为 Secret。把 Base64 内容通过 Codemagic 的 Secret 变量注入，不要把 `.jks` 文件上传到仓库。Codemagic 的构建脚本会在 ignored 的 `build/kilo-signing/` 下临时还原密钥。

## 构建命令

```powershell
.\tool\build_android_cn.ps1
.\tool\build_android_global.ps1
```

对应包名固定为：

- 国区：`com.kilostrength.kilo_strength`
- 海外：`com.kilostrength.kilo_strength.global`

脚本同时生成签名 APK 与 AAB，并输出 SHA-256。缺少任一变量或密钥文件时，构建在 Flutter/Gradle 之前失败，不会退回 debug 签名。
