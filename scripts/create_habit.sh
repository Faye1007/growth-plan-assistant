#!/bin/bash
# 创建习惯脚本
# 用法: ./create_habit.sh "习惯名称" "标签"
# 必要字段：习惯名称、标签

set -e

# 加载环境变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../.env" ]; then
    export $(grep -v '^#' "$SCRIPT_DIR/../.env" | xargs)
fi

NAME="$1"
TAG="$2"

# 从环境变量读取配置
if [ -z "$BASE_TOKEN" ]; then
    echo "❌ 请先在.env文件中配置BASE_TOKEN"
    exit 1
fi
HABIT_TABLE="tblo7lOdFkpP635C"
TODAY=$(date +"%Y-%m-%d")

# 检查必要字段
MISSING=""
if [ -z "$NAME" ]; then
    MISSING="${MISSING}习惯名称、"
fi
if [ -z "$TAG" ]; then
    MISSING="${MISSING}标签（健康/学习/工作/生活/爱好）、"
fi

if [ -n "$MISSING" ]; then
    echo "❌ 缺少必要信息：${MISSING%,*}"
    echo "请补充完整后再试。"
    exit 1
fi

# 验证标签
if [[ ! "$TAG" =~ ^(健康|学习|工作|生活|爱好)$ ]]; then
    echo "❌ 标签无效：$TAG"
    echo "有效选项：健康、学习、工作、生活、爱好"
    exit 1
fi

# 检查是否已存在同名习惯
EXISTING=$(python3 << EOF
import subprocess
import json

base_token = "$BASE_TOKEN"
table_id = "$HABIT_TABLE"
name = "$NAME"

cmd = f'lark-cli base +record-list --base-token "{base_token}" --table-id "{table_id}" --as user 2>/dev/null'
result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

try:
    data = json.loads(result.stdout)
    records = data.get("data", {}).get("data", [])
    for r in records:
        if r[0] == name:
            print("exists")
            break
except:
    pass
EOF
)

if [ "$EXISTING" == "exists" ]; then
    echo "⚠️ 习惯已存在：$NAME"
    echo "如需修改，请使用「成长，修改习惯」命令"
    exit 0
fi

# 写入多维表格
echo "📝 正在创建习惯：$NAME..."

RECORD_ID=$(python3 << EOF
import subprocess
import json

base_token = "$BASE_TOKEN"
table_id = "$HABIT_TABLE"
name = "$NAME"
tag = "$TAG"
today = "$TODAY"

record = {
    "习惯名称": name,
    "标签": tag,
    "累计天数": 0,
    "连续天数": 0,
    "创建日期": today,
    "是否启用": True
}

json_str = json.dumps(record, ensure_ascii=False)
cmd = f'lark-cli base +record-upsert --base-token "{base_token}" --table-id "{table_id}" --json \'{json_str}\' --as user 2>/dev/null'
result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

try:
    data = json.loads(result.stdout)
    if data.get("ok"):
        record_id = data.get("data", {}).get("record", {}).get("record_id_list", [""])[0]
        print(record_id)
    else:
        print("")
except:
    print("")
EOF
)

if [ -z "$RECORD_ID" ]; then
    echo "❌ 写入多维表格失败"
    exit 1
fi

echo ""
echo "✅ 习惯已录入：$NAME"
echo "   标签：$TAG"
echo "   创建日期：$TODAY"
echo ""
echo "💡 使用「成长，打卡：$NAME」进行打卡"
