#!/bin/bash
# 周数据查询脚本
# 用法: ./query_week.sh
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

# 计算本周起止日期
WEEK_START=$(date -d "last monday" +"%Y-%m-%d" 2>/dev/null || date -v-monday +"%Y-%m-%d")
WEEK_END=$(date +"%Y-%m-%d")

echo "📊 本周数据 ($WEEK_START ~ $WEEK_END)"
echo "===================="
echo ""

# 1. 任务统计
echo "📋 任务完成情况"
lark-cli base +record-list \
  --base-token "$BASE_TOKEN" \
  --table-id "YOUR_TASK_TABLE_ID" \
  --as user 2>/dev/null | grep -E "\"(已完成|未完成)\"" | wc -l | xargs -I {} echo "本周任务: {} 个"
echo ""

# 2. 习惯打卡统计
echo "✅ 习惯打卡"
lark-cli base +record-list \
  --base-token "$BASE_TOKEN" \
  --table-id "YOUR_CHECKIN_TABLE_ID" \
  --as user 2>/dev/null | grep -E "\"$WEEK_START\"" | wc -l | xargs -I {} echo "本周打卡: {} 次"
echo ""

# 3. 灵感数量
echo "💡 本周灵感"
lark-cli base +record-list \
  --base-token "$BASE_TOKEN" \
  --table-id "tblmpYc94WArjAjI" \
  --as user 2>/dev/null | wc -l | xargs -I {} echo "灵感总数: {} 条"

echo ""
echo "===================="
