#!/bin/bash
# 月数据查询脚本
# 用法: ./query_month.sh
#
# 检索范围：
# - 固定日程表：tblAO5xVkCvkVW07
# - 任务表：tblI3CavMGlKSbml
# - 习惯表：tblo7lOdFkpP635C
# - 打卡记录表：tblcnWfMx7PcTjTx
# - 灵感表：tblmpYc94WArjAjI
#
# 不包含：心情感悟（属于人生笔记内容）

set -e

# 加载环境变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../.env" ]; then
    export $(grep -v '^#' "$SCRIPT_DIR/../.env" | xargs)
fi

# 从环境变量读取配置
if [ -z "$BASE_TOKEN" ]; then
    echo "❌ 请先在.env文件中配置BASE_TOKEN"
    exit 1
fi

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
  --table-id "tblI3CavMGlKSbml" \
  --as user 2>/dev/null | head -100
echo ""

# 2. 习惯打卡统计
echo "✅ 习惯打卡"
lark-cli base +record-list \
  --base-token "$BASE_TOKEN" \
  --table-id "tblcnWfMx7PcTjTx" \
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
