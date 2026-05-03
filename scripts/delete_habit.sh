#!/bin/bash
# 删除习惯脚本
# 用法: ./delete_habit.sh "习惯名称"

set -e

NAME="$1"

if [ -z "$NAME" ]; then
    echo "用法: ./delete_habit.sh \"习惯名称\""
    exit 1
fi

BASE_TOKEN="T0ZQb1e25acfizsowUycm1Jan0c"
TABLE_ID="tblo7lOdFkpP635C"

# 查询记录
RECORDS=$(lark-cli base +record-list --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" --as user 2>/dev/null)

RECORD_ID=$(echo "$RECORDS" | grep -A5 "\"$NAME\"" | grep -o '"rec[^"]*"' | head -1 | tr -d '"' || echo "")

if [ -z "$RECORD_ID" ]; then
    echo "❌ 未找到习惯: $NAME"
    exit 1
fi

# 删除记录
lark-cli base +record-delete \
  --base-token "$BASE_TOKEN" \
  --table-id "$TABLE_ID" \
  --record-id "$RECORD_ID" \
  --as user > /dev/null 2>&1

echo "✅ 习惯已删除: $NAME"
