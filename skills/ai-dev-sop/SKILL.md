---
name: ai-dev-sop
description: >
  AI自动化开发SOP。当用户要求开发新功能、修Bug、重构代码，或者提到"SOP"、"开发流程"、"按流程来"、"按SOP走"时触发此技能。
  也适用于：用户要求从需求到交付的完整开发流程、要求AI自动执行编码-测试-审查-提交、提到TDD开发、要求分阶段开发、提到风险评估或分级审查的场景。
  即使没有明确说"SOP"，只要是涉及多步骤的系统化开发任务，都应考虑使用此技能。
version: 0.3.0
---

# AI 自动化开发 SOP

## 定位

**ai-dev-sop 不是执行者，是调度器。**

- TDD 怎么做 → `test-driven-development` skill 管
- 代码审查怎么做 → `requesting-code-review` skill 管
- 方案怎么写 → `writing-plans` skill 管
- 调试怎么做 → `systematic-debugging` skill 管
- 并行开发怎么做 → `subagent-driven-development` skill 管

**ai-dev-sop 只管三件事：**
1. 启动时加载项目上下文（context/），确保 AI 理解系统全貌
2. 方案必须人确认后才执行（人确认门）
3. 按阶段调度对应 skill，skill 怎么说 AI 就怎么做

## 核心原则
- **人**：管需求 + 确认方案（唯一签字点）
- **AI**：自动执行编码→测试→审查→提交（全流程）
- **Skill 为主，SOP 为辅**：执行细节交给 skill，SOP 只管调度和确认

## .ai-dev/ 目录结构
```
.ai-dev/
├── context/                # 系统上下文（单一事实来源，反映系统当前状态）
│   ├── product.md          # 产品需求规格（最先读这个）
│   ├── overview.md         # 系统全貌：业务对象、数据源、处理流程、输出产物
│   ├── design.md           # 技术规格：架构、模块、接口设计
│   ├── data.md             # 数据规格：数据源、表结构、字段映射
│   └── ops.md              # 运维参考：API接口、部署配置、验证结果
├── requirements/           # 需求目录（一需求一文件，README.md 做索引）
│   ├── README.md           # 活跃需求 + 归档需求索引
│   ├── template.md         # 新需求模板
│   └── R{N}-{简名}.md      # 各需求文件
├── index.md                # 总索引（入口导航，一直很短）
├── risk-rules.yaml         # 风险规则（人定义，AI执行）
├── decision-log.md         # 决策日志（各阶段写入）
├── plans/vN-名称.md        # 单次迭代方案
├── templates/              # 模板文件
│   └── review-template.md  # 代码审查报告模板（从插件 references/ 复制）
├── reviews/                # 审查记录
└── deliveries/             # 交付报告
```

### context/ 维护规则

- **定位**：context/ 是系统当前状态的"活文档"，始终只反映系统**现在是什么样**
- **与 requirements/ 的区别**：requirements/ 是需求条目（做过什么、要做什么），context/ 是系统状态快照
- **更新时机**：每次迭代交付后，AI 检查并同步更新 context/
- **初始化**：项目首次使用 SOP 时，如果 context/ 不存在，AI 应从现有文档提炼创建

## Skill 路径映射

调用 skill 时，在 context 中注入 `SOP_ROOT=.ai-dev`，以下路径替换生效：

| Skill 默认路径 | SOP 实际路径 |
|---------------|-------------|
| `docs/plans/` | `.ai-dev/plans/` |
| `reviews/` | `.ai-dev/reviews/` |
| `deliveries/` | `.ai-dev/deliveries/` |
| `tests/` | 按项目约定（不改） |

## Stop Hook（自动审查检查）

本插件注册了 `Stop` Hook，在 Claude Code 每次准备停止时自动检查：

1. 从 `.ai-dev/risk-rules.yaml` 读取 `review_check` 配置
2. 检查 git 暂存区/工作区中是否有业务逻辑文件被修改
3. 如果有修改但 `.ai-dev/reviews/` 下没有对应审查文件，输出提醒
4. 无 `.ai-dev/` 目录或无 `review_check` 配置时优雅跳过（零侵入）

**Hook 脚本位置**：`${CLAUDE_PLUGIN_ROOT}/hooks/check-review.sh`

---

## 执行流程

### 第一步：加载上下文（强制）

**必须先读 `.ai-dev/context/` 全部文件**，建立系统全貌认知后再做任何事。

按以下顺序读取：
1. `product.md` — 产品需求规格（系统应该做什么，功能全景、业务规则）
2. `overview.md` — 业务对象、数据流转、输出产物（技术面）
3. `data.md` — 数据源、表结构、字段映射
4. `design.md` — 架构、模块、接口设计
5. `ops.md` — API接口、部署配置（按需）

如果 context/ 不存在，先从项目现有文档提炼创建。

### 第二步：需求变更管理

- 新需求进来 → 在 `requirements/` 下创建新文件（按 template.md 格式），更新 README.md 索引
- 生成变更diff（+新增 ~修改 -删除）
- 人确认变更 → 更新对应需求文件 + README.md 索引
- 项目首次使用时，初始化 `risk-rules.yaml` 的 `review_check` 配置
- 复制审查模板：`cp ${CLAUDE_PLUGIN_ROOT}/references/review-template.md .ai-dev/templates/review-template.md`

### 第三步：方案设计（人确认门）

→ 加载 `writing-plans` skill，按其流程执行方案设计。

**多方案对比（强制）**：方案设计必须至少列出 2 个可行路径，按以下维度对比后推荐最优方案：
- 改动范围（涉及哪些文件/模块）
- 侵入性（是否改动核心链路、是否影响其他功能）
- 数据可靠性（数据是否完整、是否存在时序依赖）
- **已有数据可用性**（context/ 或 DetailStore 或其他内存数据中是否已有）
- **推荐理由**：明确说明为什么推荐这个方案

**人确认门（硬停止）**：
1. 输出方案后，以 `[方案待确认]` 结尾，**立即停止输出**
2. **绝对禁止**在同一轮对话中执行任何代码修改
3. 人确认后才能进入第四步；人说"部分确认"则只执行被确认的部分

### 第四步：编码实现

→ 加载 `test-driven-development` skill，按 TDD 流程执行（RED → GREEN → REFACTOR）。

- 小任务（单文件/单方法）直接执行
- 大任务（多文件/多模块）→ 加载 `subagent-driven-development` skill，dispatch 子 agent 并行执行
- 遇到 BUG → 加载 `systematic-debugging` skill（4 阶段根因排查）
- TDD 降级条件（必须记录到 `decision-log.md`）：项目无测试框架 / 仅配置变更 / 紧急 hotfix

### 第五步：代码审查

→ 加载 `requesting-code-review` skill，按其完整管线执行。

- 生成审查报告 → 填写 `.ai-dev/reviews/review-{任务名}.md`
- 审查结果追加到 `.ai-dev/decision-log.md`
- FAIL → 返回第四步修复

### 第六步：集成验证

- 编译 + 冒烟测试
- FAIL → `systematic-debugging` skill → 修复 → 重试(≤3次)
- 3+失败 → **暂停等人工**

### 第七步：交付

- git commit → 生成 delivery-report.md → 更新 index.md → **同步更新 context/** → 推送通知
- context 同步：架构变更→design.md / 数据变更→data.md / API变更→ops.md / 业务变更→overview.md / 功能变更→product.md

---

## 风险规则（risk-rules.yaml）
```yaml
risk_rules:
  high:     # 🔴 高风险（任一命中）
    - path_match: "**/.env"
    - path_match: "**/config/**"
    - content_match: "DELETE|DROP|TRUNCATE"
    - content_match: "password|secret|token"
    - dependency_change: true
    - file_count_gt: 10
  medium:   # 🟡 中风险（无🔴命中时检查）
    - path_match: "*/api/**"
    - path_match: "*/auth/**"
    - content_match: "CREATE|ALTER"
    - scope: "new_file"
  # 🟢 低风险（默认，以上都未命中）

review_strategy:
  high: "异质模型审查 + 安全扫描 + 人审确认"
  medium: "独立子agent审查 + 安全扫描"
  low: "AI自审 + lint + 测试通过即通过"

review_check:
  extensions: [".java"]
  patterns:
    - "src/main/java/.*/writer/"
    - "src/main/java/.*/service/"
    task_name_source: "requirements/README.md"
```

## SOP合规自查

| 检查项 | 预期 | 方法 |
|--------|------|------|
| context/ 已读 | 启动时读了 product.md + overview.md + data.md | 检查对话记录 |
| requirements/ | 需求有独立文件 + README.md 索引已更新 | `ls .ai-dev/requirements/` |
| 人确认门 | 方案输出后有 `[方案待确认]` + 人确认后才执行 | 检查对话记录 |
| Skill 已加载 | 各步骤有 `→ 加载 xxx skill` 声明 | 检查对话记录 |
| TDD 已执行 | 测试先于实现 | 检查对话记录 / `decision-log.md` 降级理由 |
| 审查报告 | `reviews/` 有记录 | `ls .ai-dev/reviews/` |
| context 已同步 | 交付后 context/ 已更新（含 product.md） | 对比 git diff |
