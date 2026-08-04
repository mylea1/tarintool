# KILO Mock API

零依赖 Node.js 本地服务，用于同时启动和检查 Web 原型所需的后端接口路径。它不保存用户训练数据，也不执行真实动作识别或知识库检索。

默认地址：`http://127.0.0.1:8790`

健康检查：`GET /health`

支持的原型接口：

- `POST /v1/analysis/jobs`
- `GET /v1/analysis/jobs/{id}`
- `GET /v1/analysis/jobs/{id}/result`
- `POST /v1/analysis/jobs/{id}/ack`
- `POST /v1/coach/answer`
- `POST /v1/coach/plan-draft`
- `GET /v1/content/exercises`
- `GET /v1/content/plans`
