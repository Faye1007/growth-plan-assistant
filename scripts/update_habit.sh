#!/bin/bash
# 修改习惯脚本
# 用法: ./update_habit.sh "习惯名称" [--name "新名称"] [--target "新目标"] [--status "启用/暂停"]

set -e

NAME="$1"
shift

if [ -z "$NAME" ]; then
    echo "用法: ./update_habit.sh \"习惯名称\" [--name \"新名称\"] [--target \"新目标\"] [--status \"启用/暂停\"]"
    exit 1
fi

BASE_TOKEN="T0ZQb1e25acfizsowUycm1Jan0c"
TABLE_ID="tblo7lOdFkpP635C"

# 解析参数
NEW_NAME=""
NEW_TARGET=""
NEW_STATUS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --name) NEW_NAME="$2"; shift 2 ;;
        --target) NEW_TARGET="$2"; shift 2 ;;
        --status) NEW_STATUS="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# 查询并更新
python3 << EOF
import subprocess
import json

name = "$NAME"
new_name = "$NEW_NAME"
new_target = "$NEW_TARGET"
new_status = "$NEW_STATUS"

# 获取记录列表
cmd = f'lark-cli base +record-list --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" --as user 2>/dev/null'
result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
data = json.loads(result.stdout)

# 查找记录
record_id = None
if data.get("data", {}).get("data"):
    records = data["data"]["data"]
    record_ids = data["data"]["record_id_list"]
    for i, r in enumerate(records):
        if r[0] == name:
            record_id = record_ids[i]
            break

if not record_id:
    print(f"❌ 未找到习惯: {name}")
    exit(1)

# 构建更新字段
update_fields = {}
if new_name:
    update_fields["习惯名称"] = new_name
if new_target:
    update_fields["目标"] = new_target
if new_status:
    update_fields["是否启用"] = new_status == "启用"

if not update_fields:
    print("⚠️ 没有要更新的字段")
    exit(0)

# 执行更新
json_str = json.dumps(update_fields, ensure_ascii=False)
cmd = f'lark-cli base +record-upsert --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" --record-id "{record_id}" --json \'{json_str}\' --as user 2>/dev/null'
subprocess.run(cmd, shell=True, capture_output=True)

changes = []
if new_name:
    changes.append(f"名称: {name} → {new_name}")
if new_target:
    changes.append(f"目标: {new_target}")
if new_status:
    changes.append(f"状态: {new_status}")

print(f"✅ 习惯已修改: {', '.join(changes)}")
EOF
