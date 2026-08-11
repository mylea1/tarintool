import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const backendRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const chunks = JSON.parse(fs.readFileSync(path.join(backendRoot, 'knowledge', 'training-framework.zh-CN.json'), 'utf8'));

test('训练方法知识库只保存可复用方法，不包含角色称呼', () => {
  assert.ok(chunks.length >= 8);
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
