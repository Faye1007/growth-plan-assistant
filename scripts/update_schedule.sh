#!/bin/bash
# 修改日程脚本（同步飞书日历）
# 用法: ./update_schedule.sh "日程名称" ["新时间"] ["新规则"]

set -e

# 加载环境变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../.env" ]; then
    export $(grep -v '^#' "$SCRIPT_DIR/../.env" | xargs)
fi

NAME="$1"
NEW_TIME="$2"
NEW_RULE="$3"

if [ -z "$NAME" ]; then
    echo "用法: ./update_schedule.sh \"日程名称\" [\"新时间\"] [\"新规则\"]"
    exit 1
fi

# 从环境变量读取配置
if [ -z "$BASE_TOKEN" ]; then
    echo "❌ 请先在.env文件中配置BASE_TOKEN"
    exit 1
fi
TABLE_ID="tblAO5xVkCvkVW07"

export LARK_CLI_NO_PROXY=1

# 用Python处理更新
python3 << PYEOF
import subprocess
import json
from datetime import datetime, timedelta

BASE_TOKEN = "$BASE_TOKEN"
TABLE_ID = "$TABLE_ID"
NAME = "$NAME"
NEW_TIME = "$NEW_TIME" if "$NEW_TIME" else ""
NEW_RULE = "$NEW_RULE" if "$NEW_RULE" else ""

# 获取记录列表
cmd = f'lark-cli base +record-list --base-token "{BASE_TOKEN}" --table-id "{TABLE_ID}" --as user 2>/dev/null'
result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

try:
    data = json.loads(result.stdout)
except:
    print("❌ 查询失败")
    exit(1)

records = data.get("data", {}).get("data", [])
record_ids = data.get("data", {}).get("record_id_list", [])

# 找到目标日程
target_idx = None
for i, r in enumerate(records):
    title = r[6] if len(r) > 6 else ""  # 标题字段
    if title == NAME:
        target_idx = i
        break

if target_idx is None:
    print(f"❌ 未找到日程: {NAME}")
    exit(1)

record_id = record_ids[target_idx] if target_idx < len(record_ids) else ""
target_record = records[target_idx]

if not record_id:
    print("❌ 无法获取记录ID")
    exit(1)

# 获取飞书日历事件ID
event_id = target_record[5] if len(target_record) > 5 else ""  # 飞书日历事件ID字段

# 更新飞书日历事件
if event_id and (NEW_TIME or NEW_RULE):
    update_data = {"visibility": "private"}  # 确保私密状态
    
    if NEW_TIME:
        today = datetime.now().strftime("%Y-%m-%d")
        start_dt = datetime.strptime(f"{today} {NEW_TIME}", "%Y-%m-%d %H:%M")
        end_dt = start_dt + timedelta(minutes=30)
        update_data["start_time"] = {
            "date": today,
            "timestamp": int(start_dt.timestamp())
        }
        update_data["end_time"] = {
            "date": today,
            "timestamp": int(end_dt.timestamp())
        }
    
    data_str = json.dumps(update_data, ensure_ascii=False)
    cmd = f'lark-cli calendar events patch --calendar-id primary --event-id "{event_id}" --data \'{data_str}\' --as user 2>/dev/null'
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    print("✅ 已更新飞书日历事件（私密状态）")

# 更新多维表格
update_fields = {}
if NEW_TIME:
    update_fields["时间"] = NEW_TIME
if NEW_RULE:
    update_fields["频率"] = NEW_RULE

if update_fields:
    json_str = json.dumps(update_fields, ensure_ascii=False)
    cmd = f'lark-cli base +record-upsert --base-token "{BASE_TOKEN}" --table-id "{TABLE_ID}" --record-id "{record_id}" --json \'{json_str}\' --as user 2>/dev/null'
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

changes = []
if NEW_TIME:
    changes.append(f"时间 → {NEW_TIME}")
if NEW_RULE:
    changes.append(f"规则 → {NEW_RULE}")

if changes:
    print(f"✅ 日程 '{NAME}' 已更新: {', '.join(changes)}")
else:
    print("⚠️ 没有需要更新的字段")
PYEOF
