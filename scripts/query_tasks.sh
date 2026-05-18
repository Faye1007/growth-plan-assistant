#!/bin/bash
# 查询今日任务脚本

set -e

# 加载环境变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../.env" ]; then
    export $(grep -v '^#' "$SCRIPT_DIR/../.env" | xargs)
fi

TODAY=$(date +"%Y-%m-%d")

echo "📅 今日任务 ($TODAY)"
echo "--------------------"

# 查询飞书任务
lark-cli task +get-my-tasks \
  --complete=false \
  --page-all \
  --as user 2>/dev/null | head -50

echo ""
echo "--------------------"
echo "查询完成"
