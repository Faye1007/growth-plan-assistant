#!/bin/bash
# 删除日程脚本（同步飞书日历）
# 用法: ./delete_schedule.sh "日程名称"

set -e

# 加载环境变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../.env" ]; then
    export $(grep -v '^#' "$SCRIPT_DIR/../.env" | xargs)
fi

NAME="$1"

if [ -z "$NAME" ]; then
    echo "用法: ./delete_schedule.sh \"日程名称\""
    exit 1
fi

# 从环境变量读取配置
if [ -z "$BASE_TOKEN" ]; then
    echo "❌ 请先在.env文件中配置BASE_TOKEN"
    exit 1
fi
TABLE_ID="tblAO5xVkCvkVW07"

# 1. 查询多维表格获取记录ID和飞书日历事件ID
RECORDS=$(lark-cli base +record-list --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" --as user 2>/dev/null)

RECORD_ID=$(echo "$RECORDS" | grep -A10 "\"$NAME\"" | grep -o '"rec[^"]*"' | head -1 | tr -d '"' || echo "")
EVENT_ID=$(echo "$RECORDS" | grep -A10 "\"$NAME\"" | grep -o '"evt[^"]*"' | head -1 | tr -d '"' || echo "")

if [ -z "$RECORD_ID" ]; then
    echo "❌ 未找到日程: $NAME"
    exit 1
fi

# 2. 删除飞书日历事件
if [ -n "$EVENT_ID" ]; then
    lark-cli calendar +delete --event-id "$EVENT_ID" --as user > /dev/null 2>&1 || echo ""
fi

# 3. 删除多维表格记录
lark-cli base +record-delete \
  --base-token "$BASE_TOKEN" \
  --table-id "$TABLE_ID" \
  --record-id "$RECORD_ID" \
  --as user > /dev/null 2>&1

echo "✅ 日程已删除: $NAME"
