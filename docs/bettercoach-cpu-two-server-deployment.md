# BetterCoach CPU 双服务器部署方案

## 目标配置

- 业务节点：现有阿里云 ECS，继续承载 `api.kilostrength.cn`、账号、会员、AI、SQLite、任务队列和识别媒体。
- 计算节点：腾讯云轻量应用服务器，上海，4 vCPU、8 GiB、120 GB SSD、10 Mbps、Ubuntu 22.04。
- 当前阶段只运行 CPU 推理；以后 GPU Worker 继续复用相同的内部任务协议。

## 请求链路

1. App 将视频上传到阿里云 API。
2. 阿里云创建 `queued` 任务并保存原视频。
3. 腾讯云 CPU Worker 通过仅允许固定源 IP 的阿里云 Nginx 内部入口领取任务并下载视频。
4. Worker 以 10 FPS、最大 512 推理尺寸执行 `yolo11n-pose`，并以 10 FPS、最长边 960 px 输出移动端骨骼视频。
5. 长任务每 30 秒向阿里云发送心跳，避免被错误地重新入队。
6. Worker 上传预览图、骨骼视频和结构化结果；临时目录自动删除。

Worker 必须保持单进程、单任务并发。不要在 4 核机器上启动第二个 Worker。

## 阿里云业务节点

部署包含 heartbeat 路由的新后端版本，然后确认：

```bash
curl -fsS http://127.0.0.1:8790/health
sudo systemctl status kilo-api --no-pager
```

`/etc/kilo/kilo.env` 中的 `KILO_GPU_API_KEY` 是两台服务器共享的内部密钥，名称为历史兼容保留；它同时适用于 CPU Worker。密钥不得提交到 Git。

域名已经完成备案，App 和普通用户请求直接访问阿里云 HTTPS 入口 `https://api.kilostrength.cn`，不再依赖 Cloudflare 临时隧道。计算节点继续使用受限的内部 Worker 路径：安装 `aliyun-nginx-internal-worker.conf`，仅允许腾讯云固定公网 IP `115.159.4.223` 访问 `/v1/internal/gpu/`，Worker 的 `KILO_API_BASE` 使用 `http://8.145.57.235`。发布 APK 时固定传入 `--dart-define=KILO_API_BASE_URL=https://api.kilostrength.cn`。

建议保持：

```dotenv
KILO_GPU_CLAIM_TIMEOUT_SECONDS=900
KILO_MAX_UPLOAD_BYTES=262144000
```

心跳会持续刷新 `updated_at`，只有 Worker 失联超过 15 分钟，任务才会重新进入队列。

## 腾讯云 CPU 节点

### 首次安装

开放出站 HTTPS 即可，不需要开放 Worker 的入站业务端口。安装 Docker 后，从仓库复制 `deploy/cpu-worker/`，执行：

```bash
cd deploy/cpu-worker
sudo bash install.sh
sudo nano /etc/kilo/cpu-worker.env
sudo systemctl start kilo-cpu-worker
sudo journalctl -u kilo-cpu-worker -f
```

中国内地节点若无法直连 Docker Hub，将 `docker-daemon.json` 安装为
`/etc/docker/daemon.json` 并重启 Docker。该配置使用腾讯云镜像加速，同时限制容器日志轮转，避免占满系统盘。

填入与阿里云相同的 `KILO_GPU_API_KEY`。GitHub Actions 会构建：

```text
ghcr.io/mylea1/tarintool-cpu-worker:latest
```

如果 GHCR 包是 private，需要先执行 `docker login ghcr.io`，或把该容器包改为 public。
更新镜像时先手动执行 `docker pull`，确认拉取成功后再重启服务；systemd
不会在每次启动时强制拉取镜像，避免注册表临时不可用导致服务器重启后 Worker 无法启动。

### 当前配置的安全资源上限

- Docker CPU：4 核。
- Docker 内存：7 GiB，禁止 swap，给系统保留约 1 GiB。
- 临时目录：4 GiB tmpfs，任务结束自动释放。
- 推理并发：1。
- 视频：最长 45 秒、最长边输出不超过 960 px。
- 推理：目标 10 FPS、`imgsz=512`。

若实际 20 秒视频的 P95 处理时间超过 180 秒，优先依次调整：

1. `KILO_INFERENCE_IMAGE_SIZE=448`；
2. `KILO_INFERENCE_FPS=8`；
3. 将用户视频限制为 30 秒；
4. 再考虑升级 CPU 或迁移 GPU。

每次降低采样率后都要用固定测试视频复核计数准确率，不能只比较速度。

## 存储和带宽

腾讯云节点不永久保存视频，因此不需要附购 COS 或图片处理包。输入、输出和报告仍由阿里云持有。120 GB 系统盘主要用于 Docker 镜像和日志。

建议给 systemd journal 设置磁盘上限，并监控：

```bash
journalctl --disk-usage
docker system df
df -h
free -h
```

阿里云与腾讯云之间目前通过源 IP 白名单保护的公网内部入口传输视频。初期低并发可接受；正式上线前应补充 TLS 或迁移到私网。若带宽成为主要耗时，再把媒体迁移至 OSS/COS 并使用短期签名 URL，任务协议无需改变。

固定样例视频（18.57 秒、557 帧）的部署验收数据：4 核 CPU 推理和编码约 12.2 秒，骨骼结果视频约 6.17 MB；App 真实上传、排队、处理和报告展示全链路已通过。

## 验收标准

- 连续提交 10 个 20 秒以内的视频，全部串行完成，没有重复领取。
- Worker 重启后，进行中的任务在超时后可以重新领取，额度不重复扣除。
- 推理期间阿里云任务 `updated_at` 至少每 30 秒更新一次。
- 腾讯云常驻内存低于 7 GiB，系统无 OOM kill。
- 任务结束后 `/tmp` 不残留用户视频。
- App 能依次显示 `queued`、`processing`、`completed/failed`。
