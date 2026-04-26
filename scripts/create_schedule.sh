#!/bin/bash
# 创建日程脚本
# 用法: ./create_schedule.sh "日程名称" "时间" "重复规则" "标签"
# 必要字段：日程名称、时间、重复规则、标签

set -e

NAME="$1"
TIME="$2"
REPEAT="$3"
TAG="$4"

BASE_TOKEN="YOUR_BASE_TOKEN"
SCHEDULE_TABLE="YOUR_SCHEDULE_TABLE_ID"
TODAY=$(date +"%Y-%m-%d")

# 检查必要字段
MISSING=""
if [ -z "$NAME" ]; then
    MISSING="${MISSING}日程名称、"
fi
if [ -z "$TIME" ]; then
    MISSING="${MISSING}时间（如20:00）、"
fi
if [ -z "$REPEAT" ]; then
    MISSING="${MISSING}重复规则（每天/每周一/每周二...）、"
fi
if [ -z "$TAG" ]; then
    MISSING="${MISSING}标签（健康/学习/工作/生活）、"
fi

if [ -n "$MISSING" ]; then
    echo "❌ 缺少必要信息：${MISSING%,*}"
    echo "请补充完整后再试。"
    exit 1
fi

# 验证重复规则
VALID_REPEATS=("每天" "每周一" "每周二" "每周三" "每周四" "每周五" "每周六" "每周天" "每周日" "每周三、周日")
REPEAT_VALID=false
for r in "${VALID_REPEATS[@]}"; do
    if [ "$REPEAT" == "$r" ]; then
        REPEAT_VALID=true
        break
    fi
done

if [ "$REPEAT_VALID" = false ]; then
    echo "❌ 重复规则无效：$REPEAT"
    echo "有效选项：每天、每周一、每周二、每周三、每周四、每周五、每周六、每周天/每周日、每周三、周日"
    exit 1
fi

# 验证标签
VALID_TAGS=("健康" "学习" "工作" "生活")
TAG_VALID=false
for t in "${VALID_TAGS[@]}"; do
    if [ "$TAG" == "$t" ]; then
        TAG_VALID=true
        break
    fi
done

if [ "$TAG_VALID" = false ]; then
    echo "❌ 标签无效：$TAG"
    echo "有效选项：健康、学习、工作、生活"
    exit 1
fi

# 检查是否已存在同名日程
EXISTING=$(python3 << EOF
import subprocess
import json

base_token = "$BASE_TOKEN"
table_id = "$SCHEDULE_TABLE"
name = "$NAME"

cmd = f'lark-cli base +record-list --base-token "{base_token}" --table-id "{table_id}" --as user 2>/dev/null'
result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

try:
    data = json.loads(result.stdout)
    records = data.get("data", {}).get("data", [])
    for r in records:
        if r[6] == name:  # 标题字段
            print("exists")
            break
except:
    pass
EOF
)

if [ "$EXISTING" == "exists" ]; then
    echo "⚠️ 日程已存在：$NAME"
    echo "如需修改，请使用「成长，修改日程」命令"
    exit 0
fi

# 写入多维表格
echo "📝 正在创建日程：$NAME..."

RESULT=$(python3 << EOF
import subprocess
import json
from datetime import datetime

base_token = "$BASE_TOKEN"
table_id = "$SCHEDULE_TABLE"
name = "$NAME"
time = "$TIME"
repeat = "$REPEAT"
tag = "$TAG"
today = "$TODAY"

record = {
    "标题": name,
    "时间": time,
    "频率": repeat,
    "分类": tag,
    "是否启用": True
}

json_str = json.dumps(record, ensure_ascii=False)
cmd = f'lark-cli base +record-upsert --base-token "{base_token}" --table-id "{table_id}" --json \'{json_str}\' --as user 2>/dev/null'
result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

try:
    data = json.loads(result.stdout)
    if data.get("ok"):
        record_id = data.get("data", {}).get("record", {}).get("record_id_list", [""])[0]
        print(f"success|{record_id}")
    else:
        print("fail|")
except:
    print("fail|")
EOF
)

if [[ "$RESULT" != success* ]]; then
    echo "❌ 写入多维表格失败"
    exit 1
fi

RECORD_ID=$(echo "$RESULT" | cut -d'|' -f2)
echo "✅ 已写入多维表格"

# 创建飞书日历事件
echo "📅 正在创建飞书日历事件..."

# 创建日历事件
CALENDAR_RESULT=$(python3 << EOF
import subprocess
import json
from datetime import datetime, timedelta

name = "$NAME"
time_str = "$TIME"
repeat = "$REPEAT"
tag = "$TAG"
record_id = "$RECORD_ID"
today = "$TODAY"

# 构建ISO 8601格式时间
start_dt = datetime.strptime(f"{today} {time_str}", "%Y-%m-%d %H:%M")
end_dt = start_dt + timedelta(minutes=30)

start_iso = start_dt.strftime("%Y-%m-%dT%H:%M:%S+08:00")
end_iso = end_dt.strftime("%Y-%m-%dT%H:%M:%S+08:00")

# 构建RRULE
rrule_map = {
    "每天": "FREQ=DAILY",
    "每周一": "FREQ=WEEKLY;BYDAY=MO",
    "每周二": "FREQ=WEEKLY;BYDAY=TU",
    "每周三": "FREQ=WEEKLY;BYDAY=WE",
    "每周四": "FREQ=WEEKLY;BYDAY=TH",
    "每周五": "FREQ=WEEKLY;BYDAY=FR",
    "每周六": "FREQ=WEEKLY;BYDAY=SA",
    "每周天": "FREQ=WEEKLY;BYDAY=SU",
    "每周日": "FREQ=WEEKLY;BYDAY=SU",
    "每周三、周日": "FREQ=WEEKLY;BYDAY=WE,SU"
}
rrule = rrule_map.get(repeat, "FREQ=DAILY")

description = f"分类：{tag}\\n频率：{repeat}\\n来自成长计划助手"

cmd = f'LARK_CLI_NO_PROXY=1 lark-cli calendar +create --summary "{name}" --start "{start_iso}" --end "{end_iso}" --rrule "{rrule}" --description "{description}" --as user 2>&1'
result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

# 解析结果获取事件ID
try:
    data = json.loads(result.stdout)
    event_id = data.get("data", {}).get("event_id", "")
    if event_id:
        print(f"success|{event_id}")
    else:
        print(f"fail|{result.stdout}")
except:
    print(f"fail|{result.stdout}")
EOF
)

if [[ "$CALENDAR_RESULT" == success* ]]; then
    EVENT_ID=$(echo "$CALENDAR_RESULT" | cut -d'|' -f2)
    echo "✅ 已创建飞书日历事件"
    
    # 设置为私密状态
    python3 << EOF
import subprocess
import json

event_id = "$EVENT_ID"
data = json.dumps({"visibility": "private"})
cmd = f'LARK_CLI_NO_PROXY=1 lark-cli calendar events patch --calendar-id primary --event-id "{event_id}" --data \'{data}\' --as user 2>/dev/null'
subprocess.run(cmd, shell=True, capture_output=True, text=True)
EOF
    echo "🔒 已设置为私密状态"
    
    # 更新多维表格的飞书日历事件ID
    python3 << EOF
import subprocess
import json

base_token = "$BASE_TOKEN"
table_id = "$SCHEDULE_TABLE"
record_id = "$RECORD_ID"
event_id = "$EVENT_ID"

record = {"飞书日历事件ID": event_id}
json_str = json.dumps(record, ensure_ascii=False)
cmd = f'lark-cli base +record-upsert --base-token "{base_token}" --table-id "{table_id}" --record-id "{record_id}" --json \'{json_str}\' --as user 2>/dev/null'
subprocess.run(cmd, shell=True, capture_output=True, text=True)
EOF
else
    echo "⚠️ 创建飞书日历事件失败，但多维表格已记录"
fi

echo ""
echo "✅ 日程已录入：$NAME"
echo "   时间：$TIME"
echo "   重复：$REPEAT"
echo "   标签：$TAG"
