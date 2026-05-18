#!/bin/bash
# 从飞书日历/任务双向同步数据到多维表格
# 用法: ./sync_from_feishu.sh
# 同步范围：前后一周
# 同步逻辑：以飞书为准，多维表格跟随飞书

set -e

# 加载环境变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../.env" ]; then
    export $(grep -v '^#' "$SCRIPT_DIR/../.env" | xargs)
fi

# 从环境变量读取配置
if [ -z "$BASE_TOKEN" ]; then
    echo "❌ 请先在.env文件中配置BASE_TOKEN"
    exit 1
fi
SCHEDULE_TABLE="${SCHEDULE_TABLE:-tblAO5xVkCvkVW07}"
TASK_TABLE="${TASK_TABLE:-tblI3CavMGlKSbml}"

echo "🔄 双向同步飞书数据到多维表格..."

python3 << 'EOF'
import subprocess
import json
from datetime import datetime, timedelta

BASE_TOKEN = "T0ZQb1e25acfizsowUycm1Jan0c"
SCHEDULE_TABLE = "tblAO5xVkCvkVW07"
TASK_TABLE = "tblI3CavMGlKSbml"

# 时间范围：前后一周
today = datetime.now()
start_date = (today - timedelta(days=7)).strftime("%Y-%m-%d")
end_date = (today + timedelta(days=7)).strftime("%Y-%m-%d")

def run_cmd(cmd):
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.stdout, result.returncode

def run_json(cmd):
    stdout, code = run_cmd(cmd)
    if code == 0:
        try:
            return json.loads(stdout)
        except:
            return None
    return None

def get_field(value):
    """处理多维表格的字段，可能是数组或单值"""
    if isinstance(value, list):
        return value[0] if value else ""
    return value

print(f"📅 同步时间范围: {start_date} ~ {end_date}")

# ========== 1. 日程同步 ==========
print("\n📅 日程同步...")

# 获取飞书日历事件
calendar_cmd = f'LARK_CLI_NO_PROXY=1 lark-cli calendar +agenda --start "{start_date}" --end "{end_date}" 2>/dev/null'
calendar_data = run_json(calendar_cmd)

# 获取多维表格日程
schedule_cmd = f'lark-cli base +record-list --base-token "{BASE_TOKEN}" --table-id "{SCHEDULE_TABLE}" --as user 2>/dev/null'
schedule_data = run_json(schedule_cmd)

# 构建多维表格日程映射
schedule_map = {}  # 日程名称 -> 记录信息
schedule_records = []
schedule_record_ids = []
if schedule_data and schedule_data.get("data", {}).get("data"):
    schedule_records = schedule_data["data"]["data"]
    schedule_record_ids = schedule_data["data"]["record_id_list"]
    for i, r in enumerate(schedule_records):
        name = r[6]  # 标题
        schedule_map[name] = {
            "record_id": schedule_record_ids[i],
            "time": r[7],
            "repeat": r[5],
            "enabled": r[4],
            "tag": get_field(r[3]),
            "feishu_id": r[2]
        }

# 提取飞书日历中的唯一日程（去重，因为重复日程会展开为多个实例）
# 黑名单：不同步的生活事件
BLACKLIST = ["生日", "纪念日", "结婚", "节日", "农历", "假期"]
feishu_schedules = {}  # 标题 -> {时间, 事件信息}
if calendar_data and calendar_data.get("data"):
    events = calendar_data["data"]
    for event in events:
        title = event.get("summary", "")
        
        # 检查黑名单
        is_blacklisted = False
        for keyword in BLACKLIST:
            if keyword in title:
                is_blacklisted = True
                print(f"  跳过(黑名单): {title}")
                break
        
        if is_blacklisted:
            continue
        
        start_time_obj = event.get("start_time", {})
        
        if isinstance(start_time_obj, dict):
            datetime_str = start_time_obj.get("datetime", "")
            if "T" in datetime_str:
                feishu_time = datetime_str.split("T")[1][:5]
            else:
                continue
        else:
            continue
        
        # 只记录第一次出现的（避免重复日程多次记录）
        if title not in feishu_schedules:
            feishu_schedules[title] = {
                "time": feishu_time,
                "event_id": event.get("event_id", ""),
                "recurring_id": event.get("recurring_event_id", "")
            }

# 同步逻辑
updated_count = 0
added_count = 0
deleted_count = 0

# 1. 更新/新增：飞书有 → 多维表格
for title, feishu_info in feishu_schedules.items():
    if title in schedule_map:
        # 跳过已停用的日程，不同步
        if not schedule_map[title]["enabled"]:
            print(f"  跳过(已停用): {title}")
            continue
        # 已存在，检查时间是否一致
        db_time = schedule_map[title]["time"]
        if feishu_info["time"] != db_time:
            print(f"  更新 [{title}]: {db_time} → {feishu_info['time']}")
            update_json = json.dumps({"时间": feishu_info["time"]}, ensure_ascii=False)
            record_id = schedule_map[title]["record_id"]
            update_cmd = f'lark-cli base +record-upsert --base-token "{BASE_TOKEN}" --table-id "{SCHEDULE_TABLE}" --record-id "{record_id}" --json \'{update_json}\' --as user 2>/dev/null'
            run_cmd(update_cmd)
            updated_count += 1
        else:
            print(f"  一致: {title} ({feishu_info['time']})")
    else:
        # 不存在，新增
        print(f"  新增 [{title}]: {feishu_info['time']}")
        # 默认属性
        record = {
            "标题": title,
            "时间": feishu_info["time"],
            "频率": "每天",  # 默认
            "分类": "生活",  # 默认
            "是否启用": True,
            "飞书日历事件ID": feishu_info["event_id"]
        }
        json_str = json.dumps(record, ensure_ascii=False)
        add_cmd = f'lark-cli base +record-upsert --base-token "{BASE_TOKEN}" --table-id "{SCHEDULE_TABLE}" --json \'{json_str}\' --as user 2>/dev/null'
        run_cmd(add_cmd)
        added_count += 1

# 2. 删除：飞书没有 → 多维表格有（或黑名单内的日程）
# 注意：已停用的日程不删除，保留记录
for title in list(schedule_map.keys()):
    # 跳过已停用的日程
    if not schedule_map[title]["enabled"]:
        print(f"  跳过(已停用): {title}")
        continue

    # 检查是否在黑名单
    is_blacklisted = False
    for keyword in BLACKLIST:
        if keyword in title:
            is_blacklisted = True
            break
    
    if title not in feishu_schedules or is_blacklisted:
        print(f"  删除 [{title}]: {'黑名单' if is_blacklisted else '飞书无此日程'}")
        record_id = schedule_map[title]["record_id"]
        del_cmd = f'lark-cli base +record-delete --base-token "{BASE_TOKEN}" --table-id "{SCHEDULE_TABLE}" --record-id "{record_id}" --yes --as user 2>/dev/null'
        run_cmd(del_cmd)
        deleted_count += 1

print(f"\n  日程同步完成: 更新{updated_count}个, 新增{added_count}个, 删除{deleted_count}个")

# ========== 2. 任务同步 ==========
print("\n📋 任务同步...")

# 获取飞书清单列表，建立清单ID到分类名称的映射
tasklists_cmd = 'LARK_CLI_NO_PROXY=1 lark-cli task tasklists list --as user 2>/dev/null'
tasklists_data = run_json(tasklists_cmd)

# 清单ID -> 分类名称
tasklist_category = {}
if tasklists_data and tasklists_data.get("data", {}).get("items"):
    for tl in tasklists_data["data"]["items"]:
        tasklist_category[tl["guid"]] = tl["name"]
print(f"  发现清单: {list(tasklist_category.values())}")

# 从每个清单获取任务（用字典去重，以飞书任务ID为唯一标识）
feishu_tasks = {}  # guid -> 任务信息

def add_tasks_from_tasklist(data, category):
    """从清单任务列表添加任务"""
    if not data or not data.get("data", {}).get("items"):
        return
    items = data["data"]["items"]
    for t in items:
        guid = t.get("guid", "")
        if not guid or guid in feishu_tasks:
            continue
        
        title = t.get("summary", "")
        
        # 处理截止日期
        due_obj = t.get("due", {})
        if due_obj and due_obj.get("timestamp"):
            # 时间戳转换
            import time
            ts = int(due_obj["timestamp"]) / 1000
            due = time.strftime("%Y-%m-%d", time.localtime(ts))
        else:
            due = ""
        
        # 判断状态
        completed_at = t.get("completed_at", "0")
        if completed_at and completed_at != "0":
            task_status = "已完成"
        else:
            task_status = "待办"
        
        feishu_tasks[guid] = {
            "title": title,
            "due": due,
            "status": task_status,
            "category": category  # 清单分类
        }

def add_tasks_from_my_tasks(data, status="待办", default_category="生活"):
    """从我的任务列表添加任务（补充不在清单里的任务）"""
    if not data or not data.get("data", {}).get("items"):
        return
    items = data["data"]["items"]
    for t in items:
        guid = t.get("guid", "")
        if not guid or guid in feishu_tasks:
            continue
        
        title = t.get("summary", "")
        due = t.get("due_at", "")[:10] if t.get("due_at") else ""
        
        # 不在清单里的任务，默认分类为"生活"
        feishu_tasks[guid] = {
            "title": title,
            "due": due,
            "status": status,  # 直接使用传入的状态
            "category": default_category
        }

# 遍历每个清单获取任务
for tl_guid, category in tasklist_category.items():
    print(f"  获取【{category}】清单任务...")
    # 获取未完成任务
    pending_cmd = f'LARK_CLI_NO_PROXY=1 lark-cli task tasklists tasks --params \'{{"tasklist_guid":"{tl_guid}","completed":false}}\' --page-all --as user 2>/dev/null'
    pending_data = run_json(pending_cmd)
    add_tasks_from_tasklist(pending_data, category)
    
    # 获取已完成任务
    done_cmd = f'LARK_CLI_NO_PROXY=1 lark-cli task tasklists tasks --params \'{{"tasklist_guid":"{tl_guid}","completed":true}}\' --page-all --as user 2>/dev/null'
    done_data = run_json(done_cmd)
    add_tasks_from_tasklist(done_data, category)

# 补充：获取不在清单里的任务（通过 get-my-tasks）
print("  获取其他任务（不在清单里）...")
my_tasks_pending = run_json('LARK_CLI_NO_PROXY=1 lark-cli task +get-my-tasks --complete=false --page-all --as user 2>/dev/null')
add_tasks_from_my_tasks(my_tasks_pending, status="待办")
my_tasks_done = run_json('LARK_CLI_NO_PROXY=1 lark-cli task +get-my-tasks --complete=true --page-all --as user 2>/dev/null')
add_tasks_from_my_tasks(my_tasks_done, status="已完成")

# 获取多维表格任务
db_task_cmd = f'lark-cli base +record-list --base-token "{BASE_TOKEN}" --table-id "{TASK_TABLE}" --as user 2>/dev/null'
db_task_data = run_json(db_task_cmd)

# 构建多维表格任务映射（以飞书任务ID为唯一标识）
task_map = {}  # feishu_id -> 记录信息
task_records = []
task_record_ids = []
if db_task_data and db_task_data.get("data", {}).get("data"):
    task_records = db_task_data["data"]["data"]
    task_record_ids = db_task_data["data"]["record_id_list"]
    for i, r in enumerate(task_records):
        feishu_id = r[4] if len(r) > 4 else ""  # 飞书任务ID
        if feishu_id:  # 有飞书ID的用ID索引
            task_map[feishu_id] = {
                "record_id": task_record_ids[i],
                "title": r[5] if len(r) > 5 else "",
                "status": get_field(r[6]) if len(r) > 6 else "",
                "deadline": str(r[1])[:10] if r[1] and len(r) > 1 else "",
                "category": get_field(r[7]) if len(r) > 7 else ""  # 分类在索引7
            }

# 同步逻辑
task_updated = 0
task_added = 0
task_deleted = 0

# 1. 更新/新增：飞书有 → 多维表格
for guid, feishu_info in feishu_tasks.items():
    if guid in task_map:
        # 已存在，检查状态和截止日期
        db_info = task_map[guid]
        need_update = False
        update_fields = {}
        
        if feishu_info["status"] != db_info["status"]:
            update_fields["状态"] = feishu_info["status"]
            need_update = True
        
        if feishu_info["due"] and feishu_info["due"] != db_info["deadline"]:
            update_fields["日期"] = feishu_info["due"]
            need_update = True
        
        # 如果分类为空，补充分类（从清单类型）
        if not db_info["category"] and feishu_info.get("category"):
            update_fields["分类"] = feishu_info["category"]
            need_update = True
        
        if need_update:
            print(f"  更新 [{feishu_info['title']}]: {update_fields}")
            update_json = json.dumps(update_fields, ensure_ascii=False)
            record_id = db_info["record_id"]
            update_cmd = f'lark-cli base +record-upsert --base-token "{BASE_TOKEN}" --table-id "{TASK_TABLE}" --record-id "{record_id}" --json \'{update_json}\' --as user 2>/dev/null'
            run_cmd(update_cmd)
            task_updated += 1
        else:
            print(f"  一致: {feishu_info['title']} ({feishu_info['status']})")
    else:
        # 不存在，新增（写入分类）
        print(f"  新增 [{feishu_info['title']}]: {feishu_info['status']} [{feishu_info.get('category', '未分类')}]")
        record = {
            "标题": feishu_info["title"],
            "日期": feishu_info["due"] if feishu_info["due"] else today.strftime("%Y-%m-%d"),
            "状态": feishu_info["status"],
            "分类": feishu_info.get("category", "生活"),  # 从清单类型写入分类
            "飞书任务ID": guid
        }
        json_str = json.dumps(record, ensure_ascii=False)
        add_cmd = f'lark-cli base +record-upsert --base-token "{BASE_TOKEN}" --table-id "{TASK_TABLE}" --json \'{json_str}\' --as user 2>/dev/null'
        run_cmd(add_cmd)
        task_added += 1

# 2. 删除：飞书没有 → 多维表格有
for guid in list(task_map.keys()):
    if guid not in feishu_tasks:
        print(f"  删除 [{task_map[guid]['title']}]: 飞书无此任务")
        record_id = task_map[guid]["record_id"]
        del_cmd = f'lark-cli base +record-delete --base-token "{BASE_TOKEN}" --table-id "{TASK_TABLE}" --record-id "{record_id}" --yes --as user 2>/dev/null'
        run_cmd(del_cmd)
        task_deleted += 1

print(f"\n  任务同步完成: 更新{task_updated}个, 新增{task_added}个, 删除{task_deleted}个")

print("\n✅ 双向同步完成")
EOF
