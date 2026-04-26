#!/bin/bash
# 修改任务脚本（同步飞书任务）
# 用法: ./update_task.sh "任务名称" [--category "工作"] [--title "新名称"]

set -e

OLD_TITLE="$1"
shift

BASE_TOKEN="YOUR_BASE_TOKEN"
TABLE_ID="YOUR_TASK_TABLE_ID"

if [ -z "$OLD_TITLE" ]; then
    echo "用法: ./update_task.sh \"任务名称\" [--category \"工作\"] [--title \"新名称\"]"
    exit 1
fi

# 解析参数
NEW_TITLE=""
NEW_CATEGORY=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --title) NEW_TITLE="$2"; shift 2 ;;
        --category) NEW_CATEGORY="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# 用Python处理更新
export LARK_CLI_NO_PROXY=1

python3 << 'PYEOF'
import subprocess
import json
import os

BASE_TOKEN = os.environ.get("BASE_TOKEN", "YOUR_BASE_TOKEN")
TABLE_ID = os.environ.get("TABLE_ID", "YOUR_TASK_TABLE_ID")
OLD_TITLE = os.environ.get("OLD_TITLE", "")
NEW_TITLE = os.environ.get("NEW_TITLE", "")
NEW_CATEGORY = os.environ.get("NEW_CATEGORY", "")

# 获取记录列表
cmd = f'lark-cli base +record-list --base-token "{BASE_TOKEN}" --table-id "{TABLE_ID}" --as user 2>/dev/null'
result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

try:
    data = json.loads(result.stdout)
except:
    print(f"❌ 查询失败")
    exit(1)

# 找到目标任务
records = data.get("data", {}).get("data", [])
record_ids = data.get("data", {}).get("record_id_list", [])

target_idx = None
for i, r in enumerate(records):
    name = r[5] if len(r) > 5 else ""
    if name == OLD_TITLE:
        target_idx = i
        break

if target_idx is None:
    print(f"❌ 未找到任务: {OLD_TITLE}")
    exit(1)

record_id = record_ids[target_idx] if target_idx < len(record_ids) else ""
target_record = records[target_idx]

if not record_id:
    print(f"❌ 无法获取记录ID")
    exit(1)

# 更新飞书任务标题
task_id = target_record[4] if len(target_record) > 4 else ""
if task_id and NEW_TITLE:
    cmd = f'lark-cli task +update --task-id "{task_id}" --summary "{NEW_TITLE}" --as user 2>/dev/null'
    subprocess.run(cmd, shell=True, capture_output=True)

# 更新多维表格
update_data = {}
if NEW_TITLE:
    update_data["标题"] = NEW_TITLE
if NEW_CATEGORY:
    update_data["分类"] = NEW_CATEGORY

if update_data:
    json_str = json.dumps(update_data, ensure_ascii=False)
    cmd = f'lark-cli base +record-upsert --base-token "{BASE_TOKEN}" --table-id "{TABLE_ID}" --record-id "{record_id}" --json \'{json_str}\' --as user 2>/dev/null'
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    
    try:
        resp = json.loads(result.stdout)
        if resp.get("ok") and resp.get("data", {}).get("updated"):
            changes = []
            if NEW_TITLE:
                changes.append(f"名称 → {NEW_TITLE}")
            if NEW_CATEGORY:
                changes.append(f"分类 → {NEW_CATEGORY}")
            print(f"✅ 任务 '{OLD_TITLE}' 已更新: {', '.join(changes)}")
        else:
            print(f"⚠️ 更新可能失败: {result.stdout}")
    except:
        print(f"⚠️ 更新响应解析失败")
else:
    print("⚠️ 没有需要更新的字段")
PYEOF
