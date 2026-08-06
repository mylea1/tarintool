import { createServer } from "node:http";
import { randomUUID } from "node:crypto";

const host = process.env.KILO_BACKEND_HOST || "127.0.0.1";
const port = Number(process.env.KILO_BACKEND_PORT || 8790);
const deepSeekBaseUrl = (process.env.DEEPSEEK_BASE_URL || "https://api.deepseek.com").replace(/\/+$/, "");
const deepSeekModel = process.env.DEEPSEEK_MODEL || "deepseek-v4-flash";
const maxCoachQuestionLength = 4000;
const maxTrainingSummaryLength = 6000;

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

// Account and entitlement routes are intentionally contract-only in this
// prototype. They must not report a fake login, quota consumption, or admin
// mutation; the Flutter client uses its local repository until a real service
// implements these endpoints atomically.
const accountContractPaths = new Set([
  "/v1/auth/phone/login",
  "/v1/auth/apple",
  "/v1/auth/google",
  "/v1/me/entitlements",
  "/v1/redemptions/redeem",
  "/v1/usage/consume",
  "/v1/rewards/workout-completed",
  "/v1/admin/memberships/grant",
  "/v1/admin/redemption-codes",
]);

const coachAnswer = async (body) => {
  const question = typeof body?.question === "string" ? body.question.trim() : "";
  if (!question) return { status: 400, payload: { error: "question_required" } };
  if (question.length > maxCoachQuestionLength) {
    return { status: 413, payload: { error: "question_too_long", maxLength: maxCoachQuestionLength } };
  }

  const apiKey = process.env.DEEPSEEK_API_KEY;
  if (!apiKey) return { status: 503, payload: { error: "deepseek_not_configured" } };

  const useTrainingData = body.useTrainingData === true;
  const summary = useTrainingData && typeof body.trainingSummary === "string"
    ? body.trainingSummary.trim().slice(0, maxTrainingSummaryLength)
    : "";
  const userContent = summary
    ? `${question}\n\n已授权的训练摘要（仅作为上下文，不能替代医学判断）：\n${summary}`
    : question;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 30_000);
  try {
    const upstream = await fetch(`${deepSeekBaseUrl}/chat/completions`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: deepSeekModel,
        temperature: 0.2,
        messages: [
          {
            role: "system",
            content: "你是 KILO Strength 的健身辅助教练。只提供一般训练、恢复和动作记录建议，不做诊断或替代医生；遇到疼痛、伤病、药物、孕期或其他医学风险时先建议咨询合格专业人士。证据不足时明确说明不知道，不要编造数据、来源或训练记录。回答简洁、可执行，并提醒用户根据自身情况调整。",
          },
          { role: "user", content: userContent },
        ],
      }),
      signal: controller.signal,
    });
    if (!upstream.ok) {
      return {
        status: upstream.status === 429 ? 503 : 502,
        payload: { error: "deepseek_upstream_error", upstreamStatus: upstream.status },
      };
    }
    let payload;
    try {
      payload = await upstream.json();
    } catch {
      return { status: 502, payload: { error: "deepseek_invalid_response" } };
    }
    const answer = payload?.choices?.[0]?.message?.content;
    if (typeof answer !== "string" || !answer.trim()) {
      return { status: 502, payload: { error: "deepseek_empty_response" } };
    }
    return { status: 200, payload: { answer: answer.trim(), citations: [] } };
  } catch (error) {
    if (error?.name === "AbortError") {
      return { status: 504, payload: { error: "deepseek_timeout" } };
    }
    return { status: 502, payload: { error: "deepseek_upstream_unavailable" } };
  } finally {
    clearTimeout(timeout);
  }
};

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

  if (accountContractPaths.has(url.pathname)) {
    json(response, 501, {
      error: "account_service_not_configured",
      prototype: true,
      contract: "contracts/mobile-account-membership.json",
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
    const result = await coachAnswer(body);
    json(response, result.status, result.payload);
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
  console.log(`[KILO API] 后端代理已启动：http://${host}:${port}`);
  console.log(`[KILO API] 健康检查：http://${host}:${port}/health`);
  console.log("[KILO API] Coach 请求仅由服务端代理 DeepSeek；按 Ctrl+C 停止服务。");
});
