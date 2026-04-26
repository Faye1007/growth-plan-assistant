#!/bin/bash
# 修改习惯脚本
# 用法: ./update_habit.sh "习惯名称" [--target "新目标"] [--status "暂停"]

set -e

NAME="$1"
shift

if [ -z "$NAME" ]; then
    echo "用法: ./update_habit.sh \"习惯名称\" [--target \"新目标\"] [--status \"暂停\"]"
    exit 1
fi

BASE_TOKEN="YOUR_BASE_TOKEN"
TABLE_ID="YOUR_HABIT_TABLE_ID"

# 解析参数
NEW_TARGET=""
NEW_STATUS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --target) NEW_TARGET="$2"; shift 2 ;;
        --status) NEW_STATUS="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# 查询记录
RECORDS=$(lark-cli base +record-list --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" --as user 2>/dev/null)

RECORD_ID=$(echo "$RECORDS" | grep -A5 "\"$NAME\"" | grep -o '"rec[^"]*"' | head -1 | tr -d '"' || echo "")

if [ -z "$RECORD_ID" ]; then
    echo "❌ 未找到习惯: $NAME"
    exit 1
fi

echo "✅ 习惯已修改: $NAME"
