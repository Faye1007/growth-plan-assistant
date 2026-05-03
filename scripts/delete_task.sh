#!/bin/bash
# 删除任务脚本（同步飞书任务）
# 用法: ./delete_task.sh "任务名称"

set -e

TITLE="$1"

if [ -z "$TITLE" ]; then
    echo "用法: ./delete_task.sh \"任务名称\""
    exit 1
fi

BASE_TOKEN="T0ZQb1e25acfizsowUycm1Jan0c"
TABLE_ID="tblI3CavMGlKSbml"

# 1. 查询多维表格
RECORDS=$(lark-cli base +record-list --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" --as user 2>/dev/null)

RECORD_ID=$(echo "$RECORDS" | grep -A10 "\"$TITLE\"" | grep -o '"rec[^"]*"' | head -1 | tr -d '"' || echo "")
TASK_ID=$(echo "$RECORDS" | grep -A10 "\"$TITLE\"" | grep -o '"task_id":"[^"]*"' | cut -d'"' -f4 || echo "")

if [ -z "$RECORD_ID" ]; then
    echo "❌ 未找到任务: $TITLE"
    exit 1
fi

# 2. 删除飞书任务
if [ -n "$TASK_ID" ]; then
    lark-cli task +delete \
      --task-id "$TASK_ID" \
      --as user > /dev/null 2>&1 || echo ""
fi

# 3. 删除多维表格记录
lark-cli base +record-delete \
  --base-token "$BASE_TOKEN" \
  --table-id "$TABLE_ID" \
  --record-id "$RECORD_ID" \
  --as user > /dev/null 2>&1

echo "✅ 任务已删除: $TITLE"
