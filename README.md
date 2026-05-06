# AI Dev SOP

> **当前版本：v0.2.5** — [v0.2 跑通阶段](#演进路线)

AI自动化开发SOP — 7阶段半自适应开发流程，整合TDD/审查/风险自适应，含Stop Hook自动审查检查。

## 安装

```bash
# 添加为自定义 marketplace
claude plugin marketplace add MemoryL7/ai-dev-sop

# 安装插件
claude plugin install ai-dev-sop@ai-dev-sop
```

或直接从源码安装：

```bash
cp -r ai-dev-sop ~/.claude/custom-plugins/plugins/
claude plugin update ai-dev-sop
```

## 功能

- **Skill**：完整的7阶段开发SOP（Phase 0-6），AI自动执行编码→测试→审查→提交
- **Stop Hook**：自动检查业务逻辑文件变更时是否生成了审查文件
- **通用配置**：通过项目 `.ai-dev/risk-rules.yaml` 的 `review_check` 段配置，不硬编码任何项目细节
- **零侵入**：无 `.ai-dev/` 目录或无 `review_check` 配置时优雅跳过

## 项目初始化

在项目中使用SOP时，Phase 0 会自动：
1. 创建 `.ai-dev/` 目录结构（含 `context/` 系统上下文层）
2. 根据 项目语言/框架 生成 `risk-rules.yaml` 中的 `review_check` 配置
3. 复制审查模板到 `.ai-dev/templates/review-template.md`

## 插件结构

```
ai-dev-sop/
├── .claude-plugin/
│   └── plugin.json          # 插件元数据
├── hooks/
│   ├── hooks.json           # Stop Hook 注册
│   └── check-review.sh      # 通用审查检查脚本
├── skills/
│   └── ai-dev-sop/
│       ├── SKILL.md         # SOP 完整流程（纯执行指令）
│       └── references/
│           ├── plan-template.md
│           └── review-template.md
└── evals/                   # 评估数据
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

> 核心判断：**工程化是把正确的事自动化，不是把没验证的事复杂化。** — 圆桌会议结论（2026-04-29）

```
v0.2 ← 当前：纯 Skill，7 Phase 线性流程，先跑通
  │
  ├─ v0.2.0  Phase 引用 superpowers skill，路径映射
  ├─ v0.2.1  精简目录（砍 tasks/audits）
  ├─ v0.2.2  新增 context/ 系统上下文层
  ├─ v0.2.3  方案确认硬停止 + Phase 3 入口校验
  └─ v0.2.4  Phase 1+2 多方案对比（强制）
  └─ v0.2.5  阶段执行纪律：阶段标记/Skill声明/context优先/TDD无例外
  │
  ↓ 跑通 2-3 个真实需求，验证脱节点后
  │
v0.3：融入 scale-engine 理念
  - PrematureDone 检测（改了代码必须跑测试验证）
  - BruteRetry 检测（同一策略失败 3 次强制换策略）
  - decision-log → 自进化闭环（Defect→Lesson→Rule→Hook）
  │
  ↓ 验证哪些约束真正有效后
  │
v0.4：引擎化 — 把已验证的约束做成物理 Hook
  - npm 包 / Claude Code Plugin Hook
```

## 版本历史

| 版本 | 日期 | 内容 |
|------|------|------|
| v0.0.1 | — | 初始版本，仅 skill |
| v0.1.0 | — | Claude Code 插件版本，新增 Stop Hook，`${CLAUDE_PLUGIN_ROOT}` 路径解析 |
| v0.2.0 | — | 各阶段引用对应 skill，SOP 专注调度和自适应策略 |
| v0.2.1 | 2026-04-29 | 精简目录：砍 tasks/audits，decision-log 明确写入 Phase 3+5 |
| v0.2.2 | 2026-05-06 | 新增 context/ 系统上下文层，Phase 6 交付时同步更新 |
| **v0.2.3** | **2026-05-06** | **方案确认硬停止 + Phase 3 入口校验；剥离非执行内容** |
| **v0.2.4** | **2026-05-06** | **Phase 1+2 强制多方案对比：至少2个可行路径，按改动范围/侵入性/数据可靠性对比后推荐最优** |
| **v0.2.5** | **2026-05-06** | **阶段执行纪律：阶段标记强制输出、Skill声明强制加载、Phase 0先读context、TDD无例外** |
