# AI Dev SOP

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
1. 创建 `.ai-dev/` 目录结构
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
│       ├── SKILL.md         # SOP 完整流程
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
