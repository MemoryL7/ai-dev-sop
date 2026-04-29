---
name: ai-dev-sop
description: >
  AI自动化开发标准操作流程(SOP)。当用户要求开发新功能、修Bug、重构代码，或者提到"SOP"、"开发流程"、"按流程来"、"按SOP走"时触发此技能。
  也适用于：用户要求从需求到交付的完整开发流程、要求AI自动执行编码-测试-审查-提交、提到TDD开发、要求分阶段开发、提到风险评估或分级审查的场景。
  即使没有明确说"SOP"，只要是涉及多步骤的系统化开发任务，都应考虑使用此技能。
version: 0.2.0
---

# AI 自动化开发 SOP

## 核心原则
- **人**：管需求 + 确认方案（唯一签字点）
- **AI**：自动执行编码→测试→审查→提交（全流程）
- **架构**：半自适应 = 固定骨架（7阶段）+ 动态血肉（3自适应层）
- **采用**：渐进式，Level 1零配置起步

## .ai-dev/ 目录结构
```
.ai-dev/
├── index.md                # 总索引（一直很短）
├── requirements.md         # 需求活文档（含变更历史）
├── risk-rules.yaml         # 风险规则（人定义，AI执行）
├── decision-log.md         # 决策日志（自适应层记录）
├── plans/vN-名称.md        # 单次迭代方案
├── tasks/vN/Tn-名称.md     # 单个任务明细
├── templates/              # 模板文件
│   └── review-template.md  # 代码审查报告模板（从插件 references/ 复制）
├── reviews/                # 审查记录
├── audits/                 # 回归审计
└── deliveries/             # 交付报告
```

**模板来源**：`templates/review-template.md` 的标准版本存放在本插件的 `references/review-template.md`。Phase 0 初始化时复制到项目。

## Stop Hook（自动审查检查）

本插件注册了 `Stop` Hook，在 Claude Code 每次准备停止时自动检查：

1. 从 `.ai-dev/risk-rules.yaml` 读取 `review_check` 配置
2. 检查 git 暂存区/工作区中是否有业务逻辑文件被修改
3. 如果有修改但 `.ai-dev/reviews/` 下没有对应审查文件，输出提醒
4. 无 `.ai-dev/` 目录或无 `review_check` 配置时优雅跳过（零侵入）

**Hook 脚本位置**：`${CLAUDE_PLUGIN_ROOT}/hooks/check-review.sh`
**规则配置位置**：项目 `.ai-dev/risk-rules.yaml` 的 `review_check` 段

## 流程7阶段（固定骨架）

### Phase 0：需求变更管理
- 新需求进来 → 对比当前 requirements.md
- 生成变更diff（+新增 ~修改 -删除）
- 人确认变更 → 更新 requirements.md + 变更历史
- **初始化 review_check**：扫描项目结构（语言/框架/业务目录），在 `risk-rules.yaml` 中生成 `review_check` 配置，人确认后写入
  - 示例（Java项目）：`extensions: [".java"]`，`patterns: ["src/main/java/.*/service/"]`
  - 示例（Next.js项目）：`extensions: [".ts", ".tsx"]`，`patterns: ["src/app/api/"]`
  - 若 `risk-rules.yaml` 无 `review_check` 段，Stop Hook 优雅跳过（零侵入）
- **复制审查模板**：`cp ${CLAUDE_PLUGIN_ROOT}/references/review-template.md .ai-dev/templates/review-template.md`

### Phase 1+2：方案确认
- 加载 `writing-plans` skill，按其流程执行：
  - 读取 requirements.md + 探索当前代码库
  - 任务拆分到 2-5 分钟粒度（每个任务 = 一个可独立验证的行为）
  - 精确到文件路径、完整代码示例、预期输出、验证命令
  - 审查 plan checklist（任务顺序、路径正确、代码完整、DRY/YAGNI/TDD）
- 需求对齐检查（新增 vs 已实现的冲突分析）
- **人签字确认 → 进入自动执行（未确认绝不进入Phase 3）**

### Phase 3：逐任务执行

#### 3a：任务拆分（如 plan 未细化到可执行粒度）
→ 加载 `writing-plans` skill，将每个任务拆分到 2-5 分钟粒度

#### 3b：逐任务执行（subagent 驱动）
→ 加载 `subagent-driven-development` skill，按其流程执行：
  - 读取 plan，提取所有任务
  - **每个任务 dispatch 独立子 agent**，子 agent 上下文包含完整任务描述
  - 子 agent 内部自动执行 TDD（加载 `test-driven-development` skill）：
    - RED：检测项目测试约定，按约定创建测试类/文件，编写失败测试，运行并确认 FAIL
    - GREEN：最小代码通过测试，运行并确认 PASS
    - REFACTOR：清理重复/改善命名，测试仍 PASS；无明显必要可跳过并记录理由
  - 子 agent 内部自动执行两阶段审查（加载 `requesting-code-review` skill）：
    - 规格合规：实现是否完全匹配 plan 要求（不超做不少做）
    - 代码质量：项目规范、错误处理、安全性、测试覆盖
  - 遇到 BUG → 触发 `systematic-debugging` skill（4 阶段根因排查，不猜不蒙）

#### 3c：分级审查（自适应）
- 🟢低风险：子 agent 内置自审（`subagent-driven-development` 已包含）
- 🟡中风险：独立审查子 agent（`requesting-code-review`，完整管线）
- 🔴高风险：异质模型审查 + 安全扫描 + 人审确认

### Phase 4：集成测试
- 单元测试已下沉到 Phase 3 每个任务内（`test-driven-development` skill 保证）
- 集成测试 + 冒烟测试（两轮）
- **Baseline 回归检测**（引用 `requesting-code-review` Step 3）：
  - 记录变更前的测试失败数作为 baseline
  - 变更后只判定新增失败为回归，已有失败不计入
- FAIL → 触发 `systematic-debugging` skill → 修复 → 重试(≤3次)
- 3+失败 → **暂停等人工**（固定规则，永远执行）

### Phase 5：深度审查
→ 加载 `requesting-code-review` skill，按其完整管线执行：
  - Step 1：获取 git diff（变更内容）
  - Step 2：静态安全扫描（硬编码密钥、注入、反序列化等，固定：永远不跳）
  - Step 3：Baseline 测试 + Lint（对比变更前后，只判新增失败）
  - Step 4：自审 checklist（密钥/输入验证/SQL注入/调试代码/测试覆盖）
  - Step 5：**独立审查子 agent**（与实现者零共享上下文，fail-closed 判定）
  - Step 6：评估结果（安全/逻辑错误 = FAIL → Step 7）
  - Step 7：自动修复循环（≤2轮，第三方 agent 修复，不自行修）
- 生成审查报告 → 填写 `.ai-dev/reviews/review-{任务名}.md`（含变更摘要、风险评估、验证方法、认知反思）
- FAIL → 返回 Phase 3 修复

### Phase 6：交付
- 合并分支 → 生成 delivery-report.md → 更新 index.md → 推送通知

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

# 审查检查配置（Stop Hook 使用）
# AI 在 Phase 0 初始化时根据项目结构自动生成
review_check:
  extensions: [".java"]          # 监控的文件扩展名
  patterns:                      # 命中这些路径的修改需要审查
    - "src/main/java/.*/writer/"
    - "src/main/java/.*/service/"
  task_name_source: "requirements.md"  # 从此文件提取任务编号
```

## 决策日志格式
```markdown
| 时间 | 任务 | 决策类型 | 决策 | 理由（规则命中） | 结果 |
|------|------|---------|------|-----------------|------|
| 10:01 | T3 | 风险评估 | 🟡 | 路径匹配 */api/** | — |
| 10:15 | T3 | 审查策略 | 标准 | 风险=🟡 | PASS |
```

## 需求三层保障
1. **变更diff**（每次新需求）→ 对比requirements.md，生成+~/-变更
2. **对齐检查**（每次方案确认）→ 分析新变更与已有功能的冲突
3. **回归审计**（每3-5次迭代）→ 覆盖度/一致性/技术债全面检查

## 采用路径
- **Level 1**（今天就能用）：固定7阶段 + 内置默认风险规则 + 简版决策日志
- **Level 2**（稳定后）：自定义 risk-rules.yaml + 完整决策日志 + Phase 0变更diff
- **Level 3**（成熟后）：异质审查 + 自适应调节 + 需求回归审计

## SOP合规自查

完成一次开发任务后，可自查SOP是否被正确执行。**不要问用户**——主动扫描`.ai-dev/`目录。

| SOP阶段 | 预期产出 | 检查方法 |
|---------|---------|---------|
| Phase 0 | `requirements.md`存在 | `ls .ai-dev/requirements.md` |
| Phase 1+2 | `plans/vN-*.md`存在 | `ls .ai-dev/plans/` |
| Phase 3 | git commit有feat/fix前缀 | `git log --oneline -5` |
| Phase 5 | `reviews/`有审查记录 | `ls .ai-dev/reviews/` |
| Phase 6 | `deliveries/delivery-report.md` | `ls .ai-dev/deliveries/` |

### 常见脱节点
1. **审查缺失** — `risk-rules.yaml`定义了🟡/🔴审查策略，但`reviews/`为空
2. **audits/为空** — 回归审计未执行
3. **无初始化产出** — Phase 0缺少requirements.md

> 核心洞察：**如果一个步骤总是被跳过，问题可能不在执行者，而在流程设计本身。** — 圆桌会议结论（2026-04-28）

## 版本历史
- v0.2.0 — 各阶段引用对应 skill（writing-plans / subagent-driven-development / test-driven-development / systematic-debugging / requesting-code-review），SOP 专注调度和自适应策略，不再重复 skill 已有的执行细节
- v0.1.0 — Claude Code 插件版本，新增 Stop Hook（check-review.sh），`${CLAUDE_PLUGIN_ROOT}` 路径解析
- v0.0.1 — 初始版本，仅 skill
