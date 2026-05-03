#!/bin/bash
# 今日汇总脚本
# 用法: ./query_today.sh

set -e

BASE_TOKEN="T0ZQb1e25acfizsowUycm1Jan0c"

# 先同步飞书数据
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"$SCRIPT_DIR/sync_from_feishu.sh"

echo ""

python3 << 'EOF'
import subprocess
import json
from datetime import datetime

BASE_TOKEN = "T0ZQb1e25acfizsowUycm1Jan0c"
TODAY = datetime.now().strftime("%Y-%m-%d")
WEEKDAY_NAMES = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
TODAY_WEEKDAY = WEEKDAY_NAMES[datetime.now().weekday()]

def run_lark_cli(table_id):
    cmd = f'lark-cli base +record-list --base-token "{BASE_TOKEN}" --table-id "{table_id}" --as user 2>/dev/null'
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    try:
        return json.loads(result.stdout)
    except:
        return None

def should_show_schedule(frequency):
    """判断日程今天是否应该显示"""
    if not frequency:
        return False
    if frequency == "每天":
        return True
    if frequency.startswith("每周"):
        # 解析"每周X"或"每周X、Y"格式
        # 支持：每周日、每周三、周日、每周一、周三、周五 等
        days_part = frequency.replace("每周", "").replace("周", "").replace("天", "日")
        # 按"、"或"，"分割
        days = []
        for sep in ["、", "，", ","]:
            if sep in days_part:
                days = [d.strip() for d in days_part.split(sep)]
                break
        if not days:
            days = [days_part.strip()]
        
        # 标准化日期名称
        TODAY_NORMALIZED = TODAY_WEEKDAY
        normalized_days = []
        for d in days:
            d = d.strip()
            if d == "天":
                d = "日"
            normalized_days.append(d)
        
        return TODAY_NORMALIZED in normalized_days or ("日" in normalized_days and TODAY_WEEKDAY == "周日")
    return False

print(f"📅 今日汇总 ({TODAY} {TODAY_WEEKDAY})")
print("====================\n")

# 1. 今日日程（根据频率判断今天是否应该显示）
print("📅 今日日程")
data = run_lark_cli("tblAO5xVkCvkVW07")
if data and data.get("data", {}).get("data"):
    # 筛选已启用 且 今天应该显示的日程
    today_schedules = []
    seen_titles = set()  # 去重
    
    for d in data["data"]["data"]:
        if d[4] == True:  # 已启用
            frequency = d[5] if len(d) > 5 else ""  # 频率字段
            title = d[6] if len(d) > 6 else ""
            
            # 去重
            if title in seen_titles:
                continue
            
            if should_show_schedule(frequency):
                today_schedules.append(d)
                seen_titles.add(title)
    
    if today_schedules:
        # 按时间排序
        today_schedules.sort(key=lambda x: x[7] if len(x) > 7 and x[7] else "00:00")
        for s in today_schedules:
            tag = s[3] if len(s) > 3 else ""
            if isinstance(tag, list):
                tag = tag[0] if tag else ""
            title = s[6] if len(s) > 6 else ""
            time = s[7] if len(s) > 7 else ""
            print(f"- [{tag}] {title} ({time})")
    else:
        print("暂无日程")
else:
    print("暂无日程")
print()

# 2. 今日任务（截止日期=今日 且 状态=待办）
print("📋 今日任务")
data = run_lark_cli("tblI3CavMGlKSbml")
if data and data.get("data", {}).get("data"):
    # 筛选今日任务（日期格式可能是 YYYY-MM-DD HH:MM:SS）
    today_tasks = []
    completed_today = []
    seen_task_titles = set()  # 去重
    
    for d in data["data"]["data"]:
        date_val = d[1] if len(d) > 1 else ""
        status = d[6] if len(d) > 6 else ""
        title = d[5] if len(d) > 5 else ""
        
        # 去重
        if title in seen_task_titles:
            continue
        
        # 处理日期格式
        if isinstance(date_val, str) and date_val.startswith(TODAY):
            if status == "待办" or (isinstance(status, list) and "待办" in status):
                today_tasks.append(d)
                seen_task_titles.add(title)
            elif status == "已完成" or (isinstance(status, list) and "已完成" in status):
                completed_today.append(d)
                seen_task_titles.add(title)
    
    if today_tasks:
        for t in today_tasks:
            category = t[7] if len(t) > 7 else ""
            if isinstance(category, list):
                category = category[0] if category else ""
            title = t[5] if len(t) > 5 else ""
            print(f"- [{category}] {title}")
    elif completed_today:
        print("✅ 今日任务已全部完成：")
        for t in completed_today:
            title = t[5] if len(t) > 5 else ""
            print(f"- {title}")
    else:
        print("暂无今日任务")
else:
    print("暂无今日任务")
print()

# 3. 已启用习惯 + 今日打卡状态
print("✅ 习惯清单")
habits_data = run_lark_cli("tblo7lOdFkpP635C")

enabled_habits = []
if habits_data and habits_data.get("data", {}).get("data"):
    enabled_habits = [d for d in habits_data["data"]["data"] if d[6] == True]

if enabled_habits:
    for h in enabled_habits:
        name = h[0]
        last_checkin_date = str(h[5])[:10] if h[5] else ""  # 最后打卡日期，截取日期部分
        if last_checkin_date == TODAY:
            print(f"- {name} ✅ 已打卡")
        else:
            print(f"- {name} ⬜ 未打卡")
else:
    print("暂无习惯")
print()

# 4. 今日灵感
print("💡 今日灵感")
data = run_lark_cli("tblmpYc94WArjAjI")
if data and data.get("data", {}).get("data"):
    ideas = [d for d in data["data"]["data"] if d[0] == TODAY]
    if ideas:
        for i in ideas:
            print(f"- {i[1]}")
    else:
        print("暂无记录")
else:
    print("暂无记录")

print("\n====================")
EOF
