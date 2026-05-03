#!/bin/bash
# 完成任务脚本
# 用法: ./complete_task.sh "任务名称" ["复盘内容"]
# 必要字段：任务名称

set -e

NAME="$1"
REVIEW="$2"

BASE_TOKEN="T0ZQb1e25acfizsowUycm1Jan0c"
TASK_TABLE="tblI3CavMGlKSbml"

# 检查必要字段
if [ -z "$NAME" ]; then
    echo "❌ 缺少任务名称"
    echo "请输入任务名称，如：成长，完成任务：修改简历"
    exit 1
fi

# 查找任务
TASK_INFO=$(python3 << EOF
import subprocess
import json

base_token = "$BASE_TOKEN"
table_id = "$TASK_TABLE"
name = "$NAME"

cmd = f'lark-cli base +record-list --base-token "{base_token}" --table-id "{table_id}" --as user 2>/dev/null'
result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

try:
    data = json.loads(result.stdout)
    records = data.get("data", {}).get("data", [])
    record_ids = data.get("data", {}).get("record_id_list", [])
    
    for i, r in enumerate(records):
        task_name = r[5]
        if task_name == name:
            feishu_id = r[4]  # 飞书任务ID在索引4的位置
            status = r[6][0] if isinstance(r[6], list) else r[6]
            record_id = record_ids[i]
            print(f"{record_id}|{feishu_id}|{status}")
            break
    else:
        print("not_found")
except:
    print("error")
EOF
)

if [ "$TASK_INFO" == "not_found" ]; then
    echo "❌ 未找到任务：$NAME"
    exit 1
fi

if [ "$TASK_INFO" == "error" ]; then
    echo "❌ 查询任务失败"
    exit 1
fi

# 解析任务信息
RECORD_ID=$(echo "$TASK_INFO" | cut -d'|' -f1)
FEISHU_TASK_ID=$(echo "$TASK_INFO" | cut -d'|' -f2)
CURRENT_STATUS=$(echo "$TASK_INFO" | cut -d'|' -f3)

if [ "$CURRENT_STATUS" == "已完成" ]; then
    echo "⚠️ 任务已完成：$NAME"
    exit 0
fi

# 更新多维表格
echo "📝 正在完成任务：$NAME..."

UPDATE_RESULT=$(python3 << EOF
import subprocess
import json

base_token = "$BASE_TOKEN"
table_id = "$TASK_TABLE"
record_id = "$RECORD_ID"
review = """$REVIEW"""

record = {"状态": "已完成"}
if review:
    record["复盘"] = review

json_str = json.dumps(record, ensure_ascii=False)
cmd = f'lark-cli base +record-upsert --base-token "{base_token}" --table-id "{table_id}" --record-id "{record_id}" --json \'{json_str}\' --as user 2>/dev/null'
result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

try:
    data = json.loads(result.stdout)
    print("success" if data.get("ok") else "fail")
except:
    print("fail")
EOF
)

if [ "$UPDATE_RESULT" != "success" ]; then
    echo "❌ 更新多维表格失败"
    exit 1
fi

echo "✅ 已更新多维表格"

# 同步到飞书任务
if [ -n "$FEISHU_TASK_ID" ]; then
    echo "📋 正在同步到飞书任务..."
    
    SYNC_RESULT=$(lark-cli task +complete --task-id "$FEISHU_TASK_ID" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo "✅ 已同步到飞书任务"
    else
        echo "⚠️ 同步飞书任务失败"
    fi
fi

echo ""
echo "✅ 任务已完成：$NAME"
if [ -n "$REVIEW" ]; then
    echo "   复盘：$REVIEW"
fi
