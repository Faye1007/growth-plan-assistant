#!/bin/bash
# 月数据查询脚本
# 用法: ./query_month.sh
#
# 检索范围：
# - 固定日程表：YOUR_SCHEDULE_TABLE_ID
# - 任务表：YOUR_TASK_TABLE_ID
# - 习惯表：YOUR_HABIT_TABLE_ID
# - 打卡记录表：YOUR_CHECKIN_TABLE_ID
# - 灵感表：tblmpYc94WArjAjI
#
# 不包含：心情感悟（属于人生笔记内容）

set -e

BASE_TOKEN="YOUR_BASE_TOKEN"

# 计算本月起止日期
MONTH_START=$(date +"%Y-%m-01")
MONTH_END=$(date +"%Y-%m-%d")

echo "📊 本月数据 ($MONTH_START ~ $MONTH_END)"
echo "===================="
echo ""

# 1. 任务统计
echo "📋 任务完成情况"
lark-cli base +record-list \
  --base-token "$BASE_TOKEN" \
  --table-id "YOUR_TASK_TABLE_ID" \
  --as user 2>/dev/null | head -100
echo ""

# 2. 习惯打卡统计
echo "✅ 习惯打卡"
lark-cli base +record-list \
  --base-token "$BASE_TOKEN" \
  --table-id "YOUR_CHECKIN_TABLE_ID" \
  --as user 2>/dev/null | head -100
echo ""

# 3. 灵感数量
echo "💡 本月灵感"
lark-cli base +record-list \
  --base-token "$BASE_TOKEN" \
  --table-id "tblmpYc94WArjAjI" \
  --as user 2>/dev/null | head -50

echo ""
echo "===================="
