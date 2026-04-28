---
name: ai-dev-sop
description: >
  AI自动化开发标准操作流程(SOP)。当用户要求开发新功能、修Bug、重构代码，或者提到"SOP"、"开发流程"、"按流程来"、"按SOP走"时触发此技能。
  也适用于：用户要求从需求到交付的完整开发流程、要求AI自动执行编码-测试-审查-提交、提到TDD开发、要求分阶段开发、提到风险评估或分级审查的场景。
  即使没有明确说"SOP"，只要是涉及多步骤的系统化开发任务，都应考虑使用此技能。
version: 0.1.0
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
- AI读取 requirements.md + 当前代码库
- 输出 plan.md（精确到文件路径+完整代码+任务列表）
- 需求对齐检查（新增 vs 已实现的冲突分析）
- **人签字确认 → 进入自动执行（未确认绝不进入Phase 3）**

### Phase 3：逐任务执行（7步原子循环 × N个任务）
```
① 风险评估（自适应）→ 按 risk-rules.yaml 匹配
② TDD-RED（固定）→ 写失败测试，必须看到FAIL
③ TDD-GREEN（固定）→ 最小代码实现，测试PASS
④ TDD-REFACTOR（固定）→ 重构，测试仍PASS
⑤ 分级审查（自适应）→ 🟢自审 / 🟡独立子agent / 🔴异质模型
⑥ 需求对齐（自适应）→ 频率根据风险动态调整
⑦ commit（固定）→ feat(scope): [Tn] 描述
```
- 子agent遇到BUG → 触发 systematic-debugging

### Phase 4：集成测试
- 单元测试已下沉到Phase 3每个任务内
- 集成测试 + 冒烟测试（两轮）
- FAIL → systematic-debugging → 修复 → 重试(≤3次)
- 3+失败 → **暂停等人工**（固定规则，永远执行）

### Phase 5：深度审查
- Step 1: 生成审查报告 → 复制 `references/review-template.md` 到 `.ai-dev/reviews/review-{任务名}.md`，填写变更摘要、风险评估、验证方法、**认知反思**
- Step 2: 静态安全扫描（固定：永远不跳）
- Step 5: 独立审查子agent
- Step 7: 自动修复循环（≤2轮）
- FAIL → 返回Phase 3修复

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
- v0.1.0 — Claude Code 插件版本，新增 Stop Hook（check-review.sh），`${CLAUDE_PLUGIN_ROOT}` 路径解析
- v0.0.1 — 初始版本，仅 skill
