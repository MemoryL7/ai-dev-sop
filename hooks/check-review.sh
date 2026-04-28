#!/bin/bash
# check-review.sh — 业务逻辑文件变更时检查是否生成了审查文件
# 通用版本：从 .ai-dev/risk-rules.yaml 读取规则，不硬编码任何项目细节
# 作为 Claude Code 插件 Stop Hook 运行
#
# stdin: JSON payload (Claude Code hook wire protocol)
# stdout: JSON response (Claude Code 格式)

set -euo pipefail

# ─── 读取 stdin JSON ───
INPUT_JSON=""
if [[ ! -t 0 ]]; then
    INPUT_JSON=$(cat)
fi

# 提取 cwd（Claude Code 传入的当前工作目录）
CWD=$(echo "$INPUT_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cwd',''))" 2>/dev/null || echo "")
if [[ -z "$CWD" ]]; then
    CWD=$(pwd)
fi

# ─── 定位项目根目录 ───
find_project_root() {
    local dir="$1"
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.ai-dev" ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

PROJECT_ROOT=""
if [[ -d "$CWD/.ai-dev" ]]; then
    PROJECT_ROOT="$CWD"
else
    PROJECT_ROOT="$(find_project_root "$CWD" 2>/dev/null)" || true
fi

if [[ -z "$PROJECT_ROOT" || ! -d "$PROJECT_ROOT/.ai-dev" ]]; then
    # 无 .ai-dev 目录，优雅跳过
    echo '{}'
    exit 0
fi

AI_DEV_DIR="$PROJECT_ROOT/.ai-dev"
RULES_FILE="$AI_DEV_DIR/risk-rules.yaml"
REVIEWS_DIR="$AI_DEV_DIR/reviews"

# ─── 检查规则文件 ───
if [[ ! -f "$RULES_FILE" ]]; then
    echo '{}'
    exit 0
fi

# ─── 解析 review_check 配置（纯 bash YAML 解析）───
review_check_block=$(awk '
    /^review_check:/ { found=1; next }
    found && /^[a-z_]+:/ && !/^[[:space:]]/ { found=0 }
    found { print }
' "$RULES_FILE")

if [[ -z "$review_check_block" ]]; then
    echo '{}'
    exit 0
fi

# 提取 extensions
EXTENSIONS=()
extensions_raw=$(echo "$review_check_block" | grep -E "^\s+extensions:" | \
    sed -E 's/^[^:]*:[[:space:]]*//' | sed -E 's/#.*//' | xargs 2>/dev/null || true)
if [[ -n "$extensions_raw" ]]; then
    extensions_raw=$(echo "$extensions_raw" | tr -d '[]"' | tr ',' '\n' | sed 's/^ *//;s/ *$//')
    while IFS= read -r ext; do
        [[ -n "$ext" ]] && EXTENSIONS+=("$ext")
    done <<< "$extensions_raw"
fi

# 提取 patterns
PATTERNS=()
while IFS= read -r pattern; do
    [[ -n "$pattern" ]] && PATTERNS+=("$pattern")
done <<< "$(echo "$review_check_block" | grep -E '^\s+patterns:' -A 50 | \
    grep -oE '^\s+-\s+"[^"]+"' | sed -E 's/^\s+-\s+"([^"]*)"/\1/' 2>/dev/null || true)"

# 提取 task_name_source
TASK_NAME_SOURCE=$(echo "$review_check_block" | grep -E "^\s+task_name_source:" | \
    sed -E 's/^[^:]*:[[:space:]]*//' | sed -E 's/"//g' | xargs 2>/dev/null || true)

if [[ ${#EXTENSIONS[@]} -eq 0 && ${#PATTERNS[@]} -eq 0 ]]; then
    echo '{}'
    exit 0
fi

# ─── 工具函数 ───

build_ext_pattern() {
    if [[ ${#EXTENSIONS[@]} -eq 0 ]]; then
        echo "."
        return
    fi
    local joined=$(IFS="|"; echo "${EXTENSIONS[*]}")
    echo "(${joined})$"
}

get_modified_files() {
    local ext_pattern="$1"
    # 切到项目目录执行 git 命令
    (cd "$PROJECT_ROOT" && {
        local staged=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
        local unstaged=$(git diff --name-only --diff-filter=ACM 2>/dev/null || true)
        echo -e "$staged\n$unstaged" | sort -u | grep -E "$ext_pattern" || true
    })
}

is_business_logic() {
    local file="$1"
    if [[ ${#PATTERNS[@]} -eq 0 ]]; then
        return 0
    fi
    for pattern in "${PATTERNS[@]}"; do
        if echo "$file" | grep -qE "$pattern"; then
            return 0
        fi
    done
    return 1
}

get_task_name() {
    if [[ -n "$TASK_NAME_SOURCE" && -f "$AI_DEV_DIR/$TASK_NAME_SOURCE" ]]; then
        local task_id=$(grep -m1 -oE '[A-Z][0-9]+' "$AI_DEV_DIR/$TASK_NAME_SOURCE" 2>/dev/null || true)
        if [[ -n "$task_id" ]]; then
            echo "$task_id"
            return
        fi
    fi
    echo "task-$(date +%Y%m%d)"
}

has_review_file() {
    local task_name="$1"
    if [[ ! -d "$REVIEWS_DIR" ]]; then
        return 1
    fi
    if ls "$REVIEWS_DIR"/review-${task_name}.md 1>/dev/null 2>&1; then
        return 0
    fi
    if ls "$REVIEWS_DIR"/*${task_name}*.md 1>/dev/null 2>&1; then
        return 0
    fi
    local md_count=$(find "$REVIEWS_DIR" -name "*.md" -type f 2>/dev/null | wc -l)
    if [[ "$md_count" -gt 0 ]]; then
        return 0
    fi
    return 1
}

# ─── 主逻辑 ───
main() {
    local ext_pattern
    ext_pattern=$(build_ext_pattern)

    local modified_files
    modified_files=$(get_modified_files "$ext_pattern")

    if [[ -z "$modified_files" ]]; then
        echo '{}'
        exit 0
    fi

    local has_business_change=false
    local changed_files=()
    while IFS= read -r file; do
        if is_business_logic "$file"; then
            has_business_change=true
            changed_files+=("$file")
        fi
    done <<< "$modified_files"

    if [[ "$has_business_change" != "true" ]]; then
        echo '{}'
        exit 0
    fi

    local task_name
    task_name=$(get_task_name)

    if has_review_file "$task_name"; then
        # 审查文件存在，正常通过（输出空 JSON，不阻断）
        echo '{}'
        exit 0
    else
        # 审查文件缺失，输出 systemMessage 提醒（不阻断，Stop hook 建议 exit 0）
        local files_list=""
        for file in "${changed_files[@]}"; do
            files_list+="  - $file\n"
        done

        python3 -c "import json; print(json.dumps({
            'systemMessage': (
                '⚠️ 审查文件缺失！\n\n'
                '检测到业务逻辑文件被修改，但 .ai-dev/reviews/ 下没有对应的审查文件。\n'
                '请生成审查文件：\n'
                '  cp .ai-dev/templates/review-template.md .ai-dev/reviews/review-${task_name}.md\n\n'
                '修改的文件：\n${files_list}'
            )
        }))"
        exit 0
    fi
}

main "$@"
