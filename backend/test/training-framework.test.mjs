import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const backendRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const chunks = JSON.parse(fs.readFileSync(path.join(backendRoot, 'knowledge', 'training-framework.zh-CN.json'), 'utf8'));

test('训练方法知识库只保存可复用方法，不包含角色称呼', () => {
  assert.ok(chunks.length >= 18);
  const serialized = JSON.stringify(chunks);
  assert.doesNotMatch(serialized, /谭成义|谭师|谭式体系|焚决/);
  assert.ok(chunks.every((chunk) => chunk.id.startsWith('kn_framework_')));
});

test('训练方法知识库覆盖计划、进阶、恢复和安全边界', () => {
  const tags = new Set(chunks.flatMap((chunk) => chunk.tags));
  for (const required of ['训练计划', '渐进超负荷', '恢复', '安全']) {
    assert.equal(tags.has(required), true, `缺少知识主题：${required}`);
  }
  assert.ok(chunks.some((chunk) => chunk.content.includes('2–4周')));
  assert.ok(chunks.some((chunk) => chunk.content.includes('夜间痛')));
});

test('训练方法知识条目具有稳定、可检索且不重复的结构', () => {
  const ids = new Set();
  for (const chunk of chunks) {
    assert.equal(typeof chunk.id, 'string');
    assert.equal(typeof chunk.title, 'string');
    assert.equal(typeof chunk.source, 'string');
    assert.equal(typeof chunk.content, 'string');
    assert.ok(Array.isArray(chunk.tags) && chunk.tags.length >= 2);
    assert.ok(chunk.title.trim().length >= 6);
    assert.ok(chunk.content.trim().length >= 80);
    assert.equal(ids.has(chunk.id), false, `重复知识 ID：${chunk.id}`);
    ids.add(chunk.id);
  }
});

test('训练方法知识库覆盖计划前评估、平台期、替换和反馈边界', () => {
  const serialized = JSON.stringify(chunks);
  for (const topic of ['计划契约', '平台期', '动作替换', '单变量', '休息日']) {
    assert.match(serialized, new RegExp(topic), `缺少决策主题：${topic}`);
  }
  assert.match(serialized, /泵感和酸痛.*不能单独证明增肌/);
  assert.match(serialized, /没有任何单一器械或动作是不可替代的/);
});
