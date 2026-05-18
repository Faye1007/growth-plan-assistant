#!/bin/bash
# 记录灵感脚本
# 用法: ./record_idea.sh "灵感内容"
# 必要字段：灵感内容

set -e

# 加载环境变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../.env" ]; then
    export $(grep -v '^#' "$SCRIPT_DIR/../.env" | xargs)
fi

CONTENT="$1"

# 从环境变量读取配置
if [ -z "$BASE_TOKEN" ]; then
    echo "❌ 请先在.env文件中配置BASE_TOKEN"
    exit 1
fi
IDEA_TABLE="tblmpYc94WArjAjI"
TODAY=$(date +"%Y-%m-%d")

# 检查必要字段
if [ -z "$CONTENT" ]; then
    echo "❌ 缺少灵感内容"
    echo "请输入灵感内容，如：成长，灵感：想学一门新乐器"
    exit 1
fi

# 写入多维表格
echo "📝 正在记录灵感..."

RECORD_ID=$(python3 << EOF
import subprocess
import json

base_token = "$BASE_TOKEN"
table_id = "$IDEA_TABLE"
content = """$CONTENT"""
today = "$TODAY"

record = {
    "日期": today,
    "灵感内容": content,
    "状态": "待评估"
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
echo "✅ 灵感已录入"
echo "   日期：$TODAY"
echo "   内容：$CONTENT"
