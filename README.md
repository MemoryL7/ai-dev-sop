# AI Dev SOP

> **当前版本：v0.3.0**（测试分支：`refactor/v0.3-lightweight`）

AI自动化开发SOP — 轻量级调度器，不重复定义执行细节，专注于项目上下文加载和人确认门，执行交给 superpowers skills。

## v0.3.0 核心变化

**从"全流程控制器"降级为"上下文 + 确认门 + skill 调度器"：**

| v0.2 做法 | v0.3 做法 | 原因 |
|-----------|-----------|------|
| SOP 自己定义 TDD 流程 | 交给 `test-driven-development` skill | skill 定义更聚焦，AI 更遵守 |
| SOP 自己定义审查 7 步管线 | 交给 `requesting-code-review` skill | 同上 |
| SOP 自己定义调试流程 | 交给 `systematic-debugging` skill | 同上 |
| 6 个 Phase 编号 + 嵌套子阶段 | 7 个顺序步骤，扁平化 | 减少层级，减少跳阶段的可能 |
| 堆规则打地鼠（v0.2.3→2.4→2.5） | 只保留 3 件 SOP 独有的事 | 删掉所有重复 superpowers 的内容 |

**SOP 只管 3 件事：**
1. 启动时强制读 `context/`（superpowers 不关心你的项目）
2. 方案必须人确认后才执行（superpowers 没有确认门）
3. 按步骤调度对应 skill（skill 怎么说 AI 就怎么做）

## 安装

```bash
# 从源码安装
cp -r ai-dev-sop ~/.claude/custom-plugins/plugins/
claude plugin update ai-dev-sop
```

## 功能

- **轻量调度**：7 步顺序流程，每步调度对应 superpowers skill
- **人确认门**：方案必须人确认后才执行
- **context/ 上下文**：启动时强制加载项目系统全貌
- **Stop Hook**：自动检查业务逻辑文件变更时是否生成了审查文件
- **零侵入**：无 `.ai-dev/` 目录或无 `review_check` 配置时优雅跳过

## 插件结构

```
ai-dev-sop/
├── .claude-plugin/
│   └── plugin.json
├── hooks/
│   ├── hooks.json
│   └── check-review.sh
├── skills/
│   └── ai-dev-sop/
│       ├── SKILL.md
│       └── references/
│           ├── plan-template.md
│           └── review-template.md
└── evals/
```

## review_check 配置示例

### Java 项目
```yaml
review_check:
  extensions: [".java"]
  patterns:
    - "src/main/java/.*/writer/"
    - "src/main/java/.*/service/"
  task_name_source: "requirements.md"
```

### Next.js 项目
```yaml
review_check:
  extensions: [".ts", ".tsx"]
  patterns:
    - "src/app/api/"
  task_name_source: "requirements.md"
```

## 演进路线

```
v0.2：纯 Skill，7 Phase 线性流程（main 分支，稳定版）
  │
  ├─ v0.2.0 ~ v0.2.5  渐进修补（堆规则打地鼠）
  │
v0.3 ← 当前测试：轻量级调度器（refactor/v0.3-lightweight 分支）
  │
  - 删除所有重复 superpowers 的流程定义
  - 保留 context/ 加载 + 人确认门 + skill 调度
  - 扁平化 7 步流程替代嵌套 Phase 编号
  │
  ↓ 在 DSCP 项目跑 2-3 个真实需求验证后
  │
v0.3-stable：合并到 main
```

## 版本历史

| 版本 | 日期 | 内容 |
|------|------|------|
| v0.0.1 | — | 初始版本，仅 skill |
| v0.1.0 | — | Claude Code 插件版本，新增 Stop Hook |
| v0.2.0 | — | 各阶段引用对应 skill，SOP 专注调度和自适应策略 |
| v0.2.1 | 2026-04-29 | 精简目录：砍 tasks/audits，decision-log 明确写入 Phase 3+5 |
| v0.2.2 | 2026-05-06 | 新增 context/ 系统上下文层，Phase 6 交付时同步更新 |
| v0.2.3 | 2026-05-06 | 方案确认硬停止 + Phase 3 入口校验 |
| v0.2.4 | 2026-05-06 | Phase 1+2 强制多方案对比 |
| v0.2.5 | 2026-05-06 | 阶段执行纪律：阶段标记/Skill声明/context优先/TDD无例外 |
| **v0.3.0** | **2026-05-06** | **重构：从全流程控制器降级为轻量调度器，删掉重复 superpowers 的流程定义，扁平化 7 步** |
