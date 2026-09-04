# Android 隔离打包标准流程

本文是形域 Android Debug APK 的默认打包规范。后续本地打包应直接使用仓库脚本，不再从共享的 `mobile/` 目录手工执行 `flutter build apk`。

## 标准命令

在仓库根目录运行：

```powershell
.\mobile\tool\build_android_debug_isolated.ps1 -Flavor cn
```

脚本默认构建当前 `HEAD` 并使用生产 API `https://api.kilostrength.cn`。海外渠道使用：

```powershell
.\mobile\tool\build_android_debug_isolated.ps1 -Flavor global
```

构建特定提交时显式传入提交：

```powershell
.\mobile\tool\build_android_debug_isolated.ps1 -Flavor cn -Commit c4bdcf1
```

只有已经在相同提交上单独通过质量检查时，才可以临时添加 `-SkipQualityChecks`。正常交付不得跳过 `flutter analyze` 和 `flutter test`。

## 脚本保证的构建边界

1. 使用 `git archive` 从指定提交生成源码快照，未提交的工作区改动不会进入 APK。
2. 全程只使用 WSL 内的 Linux 原生 Flutter 3.44.2、JDK 17 和 Android SDK，不读取 Windows 生成的 `.dart_tool`。
3. 快照解压到 WSL 原生 ext4 的 `/tmp/kilo-android-build-<UUID>`，不在 `/mnt/e` 上执行 Gradle。
4. 每次使用独立的 `.dart_tool`、`build` 和 `android/.gradle`，不共享项目构建缓存。
5. 仓库级独占锁禁止两个任务同时打 Android 包。遇到构建占用提示时必须等待，不能绕过锁另启 Gradle。
6. 依次执行 `flutter pub get`、`flutter analyze`、`flutter test --no-pub` 和单次 `flutter build apk`。
7. 产物以版本、构建号、分支、提交和渠道命名，复制到 `artifacts/`，同时生成 `.sha256` 文件。
8. 无论成功或失败，脚本只清理自己创建且名称匹配安全前缀的临时快照。

## 本次故障总结

本轮慢构建和不稳定并非 Flutter 业务代码始终无法编译，而是构建环境与执行方式不一致。

### Windows 与 WSL 路径混用

Windows 生成的 `.dart_tool/package_config.json` 包含 `E:/DevTools/flutter`、`E:/DevCaches/Pub` 等路径，交给 WSL 后会成为无效 Linux 路径。反向复用也同样不可靠。

结论：同一次构建的依赖解析、分析、测试和 APK 编译必须在同一个操作系统及同一套工具链内完成。

### 多个构建写入同一缓存

前一个 Flutter/Gradle 进程尚未退出时再次构建，两个进程会同时写入 `mobile/build`。曾出现：

```text
kernel_blob.bin.jar already contains entry
assets/flutter_assets/kernel_blob.bin
```

结论：构建必须单实例运行，并使用任务专属快照目录。

### WSL 挂载盘 I/O 不稳定

直接在 `/mnt/e/fitness app/...` 构建会跨越 Windows 文件系统边界。工程包含大量 Gradle 小文件，APK 超过 300 MB，挂载盘处理速度和稳定性都较差。

结论：源码必须先进入 WSL 的 `/tmp` 原生 ext4，再运行 Flutter 和 Gradle；只在成功后把最终 APK 复制回 `artifacts/`。

### 当前 Windows 主机存在 Java 回环异常

Windows 原生 JDK 17 在 Gradle daemon 建立本地连接时曾返回：

```text
java.io.IOException: Unable to establish loopback connection
SocketException: Invalid argument: connect
```

同一问题在不同 JDK 发行版和最小 `gradlew help` 中都可复现，说明它属于当前宿主网络或 Java 运行环境，而不是 Dart 业务代码问题。

结论：在该主机问题修复并完成独立复测之前，标准脚本固定使用 WSL 原生工具链，不自动先尝试 Windows 再降级，避免一次任务启动两轮 Gradle。

## 2026-09-05 成功基线

本次按隔离原则成功生成 `xingyu-1.0.33-build35-phone-auth-apple-watch-cn-debug.apk`：

- 大小：314,833,261 字节
- SHA256：`5f48dcc7e1f28dc286491adda2f52a0d86d334cc996462ecc4d3fd5329b08aff`
- 包名：`com.kilostrength.kilo_strength`
- 版本：`1.0.33 (35)`
- minSdk：24
- targetSdk：36
- API：`https://api.kilostrength.cn`

## 交付前核验

每次打包完成后至少核对：

- 脚本输出的源码提交是预期提交。
- APK 文件名中的版本、构建号、分支和渠道正确。
- `.sha256` 与重新执行 `Get-FileHash -Algorithm SHA256 <APK>` 的结果一致。
- APK 包名、`versionCode`、`versionName`、minSdk 和 targetSdk 正确。
- APK 包含 `android.permission.INTERNET`。
- 编译注入的 API Base URL 是目标环境，正式交付不得误用 localhost。
- 安装到 Android 设备后至少完成一次启动、登录和核心训练流程冒烟测试。

## 禁止事项

- 禁止 Windows 和 WSL 在同一个源码目录轮流运行 `flutter pub get`。
- 禁止直接在共享工作区运行多个 Flutter/Gradle 构建。
- 禁止在 `/mnt/e` 等 WSL 挂载盘内运行正式打包。
- 禁止前一次 Gradle 未结束就再次执行打包。
- 禁止把固定名称的 `app-debug.apk` 当作最终交付物。
- 禁止在有未提交改动时误认为 APK 包含这些改动；标准脚本只构建 Git 提交。
- 禁止因清理缓存而删除仓库根目录、用户目录或非本次脚本创建的路径。

## 失败处理

失败后保留完整日志，先定位失败阶段：依赖下载、静态检查、测试、Gradle 编译或产物复制。不要立即重复执行同一命令。

若提示构建锁占用，检查现有任务并等待其结束。若工具链缺失，修复 WSL 用户目录 `.local/toolchains` 中的 Linux 原生 Flutter、JDK 和 Android SDK；不要临时改回 Windows SDK 或复用 Windows `.dart_tool`。若是依赖网络问题，优先沿用项目和工具链已经配置的镜像，不要反复并行重试。
