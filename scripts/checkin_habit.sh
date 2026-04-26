#!/bin/bash
# 打卡习惯脚本
# 用法: 
#   ./checkin_habit.sh "习惯名称"              # 无复盘，只更新习惯表
#   ./checkin_habit.sh "习惯名称" "复盘内容"   # 有复盘，更新习惯表+写入打卡记录表

set -e

NAME="$1"
REVIEW="$2"

if [ -z "$NAME" ]; then
    echo "用法: ./checkin_habit.sh \"习惯名称\" [\"复盘内容\"]"
    exit 1
fi

BASE_TOKEN="YOUR_BASE_TOKEN"
HABIT_TABLE="YOUR_HABIT_TABLE_ID"
CHECKIN_TABLE="YOUR_CHECKIN_TABLE_ID"
TODAY=$(date +"%Y-%m-%d")

# 查询习惯数据
HABIT_DATA=$(lark-cli base +record-list \
  --base-token "$BASE_TOKEN" \
  --table-id "$HABIT_TABLE" \
  --as user 2>/dev/null)

# Python处理打卡逻辑
python3 -c "
import subprocess
import json
from datetime import datetime

habit_data = '''$HABIT_DATA'''
name = '$NAME'
today = '$TODAY'
base_token = '$BASE_TOKEN'
habit_table = '$HABIT_TABLE'
checkin_table = '$CHECKIN_TABLE'
review = '''$REVIEW'''

data = json.loads(habit_data)
record_id = None
current_count = 0
current_streak = 0
last_date = None

# 查找习惯
records = data['data']['data']
record_ids = data['data']['record_id_list']

for i, d in enumerate(records):
    if d[0] == name:
        record_id = record_ids[i]
        current_count = d[1] if d[1] else 0
        current_streak = d[2] if d[2] else 0
        last_date = d[5]
        break

if not record_id:
    print(f'❌ 未找到习惯: {name}')
    exit(1)

# 检查是否今日已打卡
if last_date == today:
    print(f'⚠️ 今日已打卡: {name}')
    exit(0)

# 计算连续天数
if last_date:
    last = datetime.strptime(last_date, '%Y-%m-%d')
    today_dt = datetime.strptime(today, '%Y-%m-%d')
    if (today_dt - last).days == 1:
        new_streak = current_streak + 1
    else:
        new_streak = 1
else:
    new_streak = 1

new_count = current_count + 1

# 更新习惯表
update_json = json.dumps({
    '习惯名称': name,
    '累计天数': new_count,
    '连续天数': new_streak,
    '最后打卡日期': today
}, ensure_ascii=False)

cmd = f\"lark-cli base +record-upsert --base-token '{base_token}' --table-id '{habit_table}' --record-id '{record_id}' --json '{update_json}' --as user\"
subprocess.run(cmd, shell=True, capture_output=True)

print(f'✅ 打卡成功: {name} (累计{new_count}天, 连续{new_streak}天)')

# 如果有复盘，写入打卡记录表
if review:
    checkin_json = json.dumps({
        '日期': today,
        '习惯名称': name,
        '复盘': review,
        '是否打卡': True
    }, ensure_ascii=False)
    
    cmd = f\"lark-cli base +record-upsert --base-token '{base_token}' --table-id '{checkin_table}' --json '{checkin_json}' --as user\"
    subprocess.run(cmd, shell=True, capture_output=True)
    print(f'📝 已记录复盘内容')
"
