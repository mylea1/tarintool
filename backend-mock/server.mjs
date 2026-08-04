import { createServer } from "node:http";
import { randomUUID } from "node:crypto";

const host = process.env.KILO_BACKEND_HOST || "127.0.0.1";
const port = Number(process.env.KILO_BACKEND_PORT || 8790);

const json = (response, status, payload) => {
  response.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "GET,POST,OPTIONS",
    "access-control-allow-headers": "content-type",
    "cache-control": "no-store",
  });
  response.end(JSON.stringify(payload, null, 2));
};

const readJson = async (request) => {
  const chunks = [];
  for await (const chunk of request) chunks.push(chunk);
  if (!chunks.length) return {};
  try {
    return JSON.parse(Buffer.concat(chunks).toString("utf8"));
  } catch {
    return null;
  }
};

const jobs = new Map();

const server = createServer(async (request, response) => {
  const url = new URL(request.url || "/", `http://${request.headers.host || `${host}:${port}`}`);

  if (request.method === "OPTIONS") {
    response.writeHead(204, {
      "access-control-allow-origin": "*",
      "access-control-allow-methods": "GET,POST,OPTIONS",
      "access-control-allow-headers": "content-type",
    });
    response.end();
    return;
  }

  if (request.method === "GET" && url.pathname === "/health") {
    json(response, 200, {
      ok: true,
      service: "kilo-backend-mock",
      mode: "local-prototype",
      time: new Date().toISOString(),
    });
    return;
  }

  if (request.method === "POST" && url.pathname === "/v1/analysis/jobs") {
    const body = await readJson(request);
    if (body === null) return json(response, 400, { error: "invalid_json" });
    const id = randomUUID();
    jobs.set(id, { id, createdAt: Date.now(), exerciseId: body.exerciseId || "bench_press" });
    json(response, 202, {
      id,
      status: "queued",
      upload: { method: "PUT", url: `http://${host}:${port}/mock-upload/${id}`, expiresInSeconds: 900 },
      prototype: true,
    });
    return;
  }

  const jobMatch = url.pathname.match(/^\/v1\/analysis\/jobs\/([^/]+)(?:\/(result|ack))?$/);
  if (jobMatch) {
    const [, id, action] = jobMatch;
    const job = jobs.get(id);
    if (!job) return json(response, 404, { error: "job_not_found" });

    if (request.method === "GET" && !action) {
      const elapsed = Date.now() - job.createdAt;
      json(response, 200, { id, status: elapsed > 1200 ? "complete" : "processing", progress: Math.min(100, Math.round(elapsed / 12)) });
      return;
    }
    if (request.method === "GET" && action === "result") {
      json(response, 200, {
        id,
        exerciseId: job.exerciseId,
        repetitions: 8,
        evidenceQuality: "high",
        dimensions: { primaryMovement: 87, coupledSupport: 78, stability: 82 },
        topFinding: "后两次回落位置略向头部移动",
        prototype: true,
      });
      return;
    }
    if (request.method === "POST" && action === "ack") {
      jobs.delete(id);
      json(response, 200, { id, deleted: true, prototype: true });
      return;
    }
  }

  if (request.method === "POST" && url.pathname === "/v1/coach/answer") {
    const body = await readJson(request);
    if (body === null) return json(response, 400, { error: "invalid_json" });
    json(response, 200, {
      answer: "这是本地原型回答。正式版本将从审核知识库检索证据，并在证据不足时明确回答不知道。",
      citations: [
        { id: "kb-double-progression", title: "KILO 知识库：双重渐进", version: "prototype-1" },
      ],
      receivedTrainingSummary: Boolean(body.trainingSummary),
      prototype: true,
    });
    return;
  }

  if (request.method === "POST" && url.pathname === "/v1/coach/plan-draft") {
    const body = await readJson(request);
    if (body === null) return json(response, 400, { error: "invalid_json" });
    json(response, 200, {
      draft: { title: "四日上下肢草案", weeks: body.weeks || 12, daysPerWeek: body.daysPerWeek || 4, progressionMode: "double_progression" },
      requiresLocalValidation: true,
      prototype: true,
    });
    return;
  }

  if (request.method === "GET" && url.pathname === "/v1/content/exercises") {
    json(response, 200, { version: "prototype-2026.08", count: 32, downloadUrl: null, prototype: true });
    return;
  }

  if (request.method === "GET" && url.pathname === "/v1/content/plans") {
    json(response, 200, { version: "prototype-2026.08", planIds: ["hypertrophy-3", "upper-lower-4", "ppl-5", "strength-5"], prototype: true });
    return;
  }

  json(response, 404, { error: "not_found", path: url.pathname });
});

server.on("error", (error) => {
  console.error(`[KILO API] 启动失败：${error.message}`);
  process.exitCode = 1;
});

server.listen(port, host, () => {
  console.log(`[KILO API] Mock 后端已启动：http://${host}:${port}`);
  console.log(`[KILO API] 健康检查：http://${host}:${port}/health`);
  console.log("[KILO API] 当前仅用于 Web 原型，不保存用户数据。按 Ctrl+C 停止服务。");
});
