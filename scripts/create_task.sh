#!/bin/bash
# 创建任务脚本
# 用法: ./create_task.sh "任务名称" "截止日期" "分类" ["备注"] ["时间"]
# 必要字段：任务名称、截止日期、分类
# 时间参数可选，格式如 "14:00"。如果明确指定了时间，才设置提醒；否则不提醒

set -e

NAME="$1"
DEADLINE="$2"
CATEGORY="$3"
NOTE="$4"
TIME="$5"  # 可选：具体时间，如 "14:00"

BASE_TOKEN="YOUR_BASE_TOKEN"
TASK_TABLE="YOUR_TASK_TABLE_ID"

# 飞书任务清单ID
TASK_LISTS='{"学习":"YOUR_STUDY_LIST_ID","工作":"YOUR_WORK_LIST_ID","生活":"YOUR_LIFE_LIST_ID"}'

# 检查必要字段
MISSING=""
if [ -z "$NAME" ]; then
    MISSING="${MISSING}任务名称、"
fi
if [ -z "$DEADLINE" ]; then
    MISSING="${MISSING}截止日期（如2026-04-20）、"
fi
if [ -z "$CATEGORY" ]; then
    MISSING="${MISSING}分类（学习/工作/生活）、"
fi

if [ -n "$MISSING" ]; then
    echo "❌ 缺少必要信息：${MISSING%,*}"
    echo "请补充完整后再试。"
    exit 1
fi

# 验证分类
if [[ ! "$CATEGORY" =~ ^(学习|工作|生活)$ ]]; then
    echo "❌ 分类无效：$CATEGORY"
    echo "有效选项：学习、工作、生活"
    exit 1
fi

# 验证日期格式
if [[ ! "$DEADLINE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "❌ 日期格式无效：$DEADLINE"
    echo "正确格式：YYYY-MM-DD（如2026-04-20）"
    exit 1
fi

# 写入多维表格
echo "📝 正在创建任务：$NAME..."

RECORD_ID=$(python3 << EOF
import subprocess
import json

base_token = "$BASE_TOKEN"
table_id = "$TASK_TABLE"
name = "$NAME"
deadline = "$DEADLINE"
category = "$CATEGORY"
note = """$NOTE"""
time_val = "$TIME" if "$TIME" else None

record = {
    "标题": name,
    "日期": deadline,
    "分类": category,
    "状态": "待办"
}

if note:
    record["复盘"] = note
if time_val:
    record["时间"] = time_val

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

echo "✅ 已写入多维表格"

# 同步到飞书任务
echo "📋 正在同步到飞书任务..."

FEISHU_TASK_ID=$(python3 << EOF
import subprocess
import json

name = "$NAME"
deadline = "$DEADLINE"
category = "$CATEGORY"
note = """$NOTE"""
time_val = "$TIME" if "$TIME" else None

task_lists = {"学习": "YOUR_STUDY_LIST_ID", "工作": "YOUR_WORK_LIST_ID", "生活": "YOUR_LIFE_LIST_ID"}
list_id = task_lists.get(category, task_lists["学习"])

# 如果有具体时间，使用该时间作为截止时间，并设置提醒
# 如果没有具体时间，使用当天23:59，但不设置提醒
if time_val:
    due_time = f"{deadline}T{time_val}:00+08:00"
    # 设置提醒：截止时间前10分钟
    reminders_json = '"reminders": [{"relative_fire_minute": 10}]'
else:
    due_time = f"{deadline}T23:59:00+08:00"
    # 不设置提醒
    reminders_json = ''

note_arg = f"--description '{note}'" if note else ""
assignee = "ou_bcd239840ee3b62fdff78c75c7a2c75f"

# 使用 --data 传递完整参数
data_obj = {
    "summary": name,
    "due": {"timestamp": None},  # 需要转换
    "assignee": assignee
}

if note:
    data_obj["description"] = note

if time_val:
    # 有具体时间，设置提醒
    data_obj["reminders"] = [{"relative_fire_minute": 10}]
# 没有具体时间，不设置 reminders 字段，即不提醒

# 计算截止时间戳
from datetime import datetime
import pytz
tz = pytz.timezone('Asia/Shanghai')
if time_val:
    dt = tz.localize(datetime.strptime(f"{deadline} {time_val}", "%Y-%m-%d %H:%M"))
else:
    dt = tz.localize(datetime.strptime(f"{deadline} 23:59", "%Y-%m-%d %H:%M"))
data_obj["due"] = {"timestamp": str(int(dt.timestamp() * 1000))}

data_str = json.dumps(data_obj, ensure_ascii=False)

cmd = f"LARK_CLI_NO_PROXY=1 lark-cli task +create --tasklist-id '{list_id}' --data '{data_str}' --as user 2>&1"
result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

try:
    data = json.loads(result.stdout)
    task_id = data.get("data", {}).get("guid", "")
    print(task_id)
except:
    print("")
EOF
)

if [ -n "$FEISHU_TASK_ID" ]; then
    echo "✅ 已同步到飞书任务"
    if [ -n "$TIME" ]; then
        echo "⏰ 已设置提醒：$TIME 前10分钟"
    else
        echo "🔕 未设置提醒（未指定具体时间）"
    fi
    
    # 更新多维表格的飞书任务ID
    python3 << EOF
import subprocess
import json

base_token = "$BASE_TOKEN"
table_id = "$TASK_TABLE"
record_id = "$RECORD_ID"
feishu_id = "$FEISHU_TASK_ID"

record = {"飞书任务ID": feishu_id}
json_str = json.dumps(record, ensure_ascii=False)
cmd = f'lark-cli base +record-upsert --base-token "{base_token}" --table-id "{table_id}" --record-id "{record_id}" --json \'{json_str}\' --as user 2>/dev/null'
subprocess.run(cmd, shell=True, capture_output=True, text=True)
EOF
else
    echo "⚠️ 同步飞书任务失败，但多维表格已记录"
fi

echo ""
echo "✅ 任务已录入：$NAME"
echo "   截止：$DEADLINE${TIME:+ $TIME}"
echo "   分类：$CATEGORY"
