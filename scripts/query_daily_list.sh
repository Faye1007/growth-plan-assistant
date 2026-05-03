#!/bin/bash
# 每日清单脚本
# 用法: ./query_daily_list.sh
# 触发时间：每天早上7点

set -e

BASE_TOKEN="T0ZQb1e25acfizsowUycm1Jan0c"

# 先同步飞书数据
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"$SCRIPT_DIR/sync_from_feishu.sh"

echo ""

python3 << 'EOF'
import subprocess
import json
from datetime import datetime, timedelta

BASE_TOKEN = "T0ZQb1e25acfizsowUycm1Jan0c"
GROWTH_BASE_TOKEN = "T0ZQb1e25acfizsowUycm1Jan0c"  # 成长计划
LIFE_BASE_TOKEN = "T0ZQb1e25acfizsowUycm1Jan0c"    # 生活小助手（同一个）

TODAY = datetime.now().strftime("%Y-%m-%d")
WEEKDAY = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"][datetime.now().weekday()]

def run_lark_cli(table_id, base_token=BASE_TOKEN):
    cmd = f'lark-cli base +record-list --base-token "{base_token}" --table-id "{table_id}" --as user 2>/dev/null'
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    try:
        return json.loads(result.stdout)
    except:
        return None

def get_field(value):
    if isinstance(value, list):
        return value[0] if value else ""
    return value

print(f"📋 今日清单 ({TODAY} {WEEKDAY})")
print("====================\n")

# 1. 纪念日提醒（提前7天/1天/当天）
ANNIVERSARY_TABLE = "tbl6ACwhojvfd13V"
GIFT_TABLE = "tblHGcHO4PAfmtJz"

anniv_data = run_lark_cli(ANNIVERSARY_TABLE)
gift_data = run_lark_cli(GIFT_TABLE)

# 构建礼物记录（按纪念日分组）
gift_map = {}  # 纪念日名称 -> [礼物列表]
if gift_data and gift_data.get("data", {}).get("data"):
    for g in gift_data["data"]["data"]:
        anniv_name = get_field(g[0]) if len(g) > 0 else ""  # 关联纪念日
        gift_name = get_field(g[1]) if len(g) > 1 else ""  # 礼物内容
        if anniv_name and gift_name:
            if anniv_name not in gift_map:
                gift_map[anniv_name] = []
            gift_map[anniv_name].append(gift_name)

# 检查纪念日
anniv_reminders = []
if anniv_data and anniv_data.get("data", {}).get("data"):
    now = datetime.now()
    today = datetime(now.year, now.month, now.day)  # 只取日期，忽略时间
    for a in anniv_data["data"]["data"]:
        name = a[0] if len(a) > 0 else ""  # 名称
        date_str = a[5] if len(a) > 5 else ""  # 日期
        
        if not date_str:
            continue
        
        try:
            # 解析日期（格式可能是 YYYY-MM-DD 或 MM-DD）
            if len(date_str) == 10:  # YYYY-MM-DD
                anniv_date = datetime.strptime(date_str, "%Y-%m-%d")
            elif len(date_str) == 5:  # MM-DD
                month, day = date_str.split("-")
                anniv_date = datetime(today.year, int(month), int(day))
            else:
                continue
            
            # 计算距离天数
            this_year_anniv = datetime(today.year, anniv_date.month, anniv_date.day)
            if this_year_anniv < today:
                this_year_anniv = datetime(today.year + 1, anniv_date.month, anniv_date.day)
            
            days_until = (this_year_anniv - today).days
            
            # 检查是否需要提醒
            reminder_type = None
            if days_until == 0:
                reminder_type = "今天"
            elif days_until == 1:
                reminder_type = "明天"
            elif days_until == 7:
                reminder_type = "7天后"
            
            if reminder_type:
                # 查找历史礼物
                history = gift_map.get(name, [])
                anniv_reminders.append({
                    "name": name,
                    "type": reminder_type,
                    "date": this_year_anniv.strftime("%m-%d"),
                    "history": history
                })
        except:
            continue

if anniv_reminders:
    print("🎁 纪念日提醒")
    for r in anniv_reminders:
        if r["type"] == "今天":
            print(f"- 🎉 今天是 {r['name']}！")
        elif r["type"] == "明天":
            print(f"- ⏰ 明天({r['date']})是 {r['name']}，记得准备！")
        else:
            print(f"- 📅 {r['type']}({r['date']})是 {r['name']}")
        
        if r["history"]:
            print(f"  历史礼物：{', '.join(r['history'][:3])}")
    print()

# 2. 今日日程
print("📅 今日日程")

def should_show_schedule(freq, weekday):
    """判断日程是否应该在今天显示"""
    if not freq:
        return False
    if freq == "每天":
        return True
    # 解析"每周X"或"每周X、Y"格式
    weekday_map = {"一": 0, "二": 1, "三": 2, "四": 3, "五": 4, "六": 5, "日": 6}
    if freq.startswith("每周"):
        # 提取所有星期
        days = freq.replace("每周", "").replace("、", "")
        for d in days:
            if d in weekday_map and weekday_map[d] == weekday:
                return True
        return False
    return False

weekday = datetime.now().weekday()  # 0=周一, 6=周日
data = run_lark_cli("tblAO5xVkCvkVW07")
if data and data.get("data", {}).get("data"):
    schedules = [d for d in data["data"]["data"] if d[4] == True]
    today_schedules = []
    for s in schedules:
        freq = get_field(s[5])
        if should_show_schedule(freq, weekday):
            today_schedules.append(s)
    
    if today_schedules:
        for s in today_schedules:
            tag = get_field(s[3])
            print(f"- [{tag}] {s[6]} ({s[7]})")
    else:
        print("暂无日程")
else:
    print("暂无日程")
print()

# 3. 今日任务
print("📋 今日任务")
data = run_lark_cli("tblI3CavMGlKSbml")
if data and data.get("data", {}).get("data"):
    today_tasks = [d for d in data["data"]["data"] if d[1] and d[1].startswith(TODAY) and get_field(d[6]) == "待办"]
    if today_tasks:
        for t in today_tasks:
            category = get_field(t[7]) if len(t) > 7 else ""  # 分类在索引7
            time_str = get_field(t[2]) if t[2] else ""
            time_display = f" ({time_str})" if time_str else ""
            cat_display = f"[{category}] " if category else ""
            print(f"- {cat_display}{t[5]}{time_display}")
    else:
        # 检查是否有已完成的今日任务
        completed = [d for d in data["data"]["data"] if d[1] and d[1].startswith(TODAY) and get_field(d[6]) == "已完成"]
        if completed:
            print("✅ 今日任务已全部完成")
        else:
            print("暂无今日任务")
else:
    print("暂无今日任务")
print()

# 4. 习惯打卡
print("✅ 习惯打卡")
data = run_lark_cli("tblo7lOdFkpP635C")
if data and data.get("data", {}).get("data"):
    habits = [d for d in data["data"]["data"] if d[6] == True]
    if habits:
        for h in habits:
            print(f"- [ ] {h[0]}")
    else:
        print("暂无习惯")
else:
    print("暂无习惯")

print("\n💪 加油！")
print("====================")
EOF
