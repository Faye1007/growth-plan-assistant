#!/bin/bash
# 创建任务脚本
# 用法: ./scripts/create_task.sh "任务名称" "截止日期" "分类" ["备注"] ["时间"]
# 必要字段：任务名称、截止日期、分类
# 时间参数可选，格式如 "14:00"。如果明确指定了时间，才设置提醒；否则不提醒
# 流程：先创建飞书任务 → 成功后写入多维表格 → 避免同步时误删

set -e

NAME="$1"
DEADLINE="$2"
CATEGORY="$3"
NOTE="$4"
TIME="$5"  # 可选：具体时间，如 "14:00"

BASE_TOKEN="T0ZQb1e25acfizsowUycm1Jan0c"
TASK_TABLE="tblI3CavMGlKSbml"

# 飞书任务清单ID
TASK_LISTS='{"学习":"424aad40-5fea-47c1-b846-48416b53f685","工作":"55eb10db-31ed-4aee-bbf9-9dd97235e7d9","生活":"3dda1822-a9a8-4ab9-b6ea-a278283b8224"}'

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

echo "📝 正在创建任务：$NAME..."

# ===== 第一步：创建飞书任务 =====
echo "📋 正在创建飞书任务..."

FEISHU_TASK_ID=$(python3 << PYEOF
import subprocess
import json
from datetime import datetime
import pytz

name = "$NAME"
deadline = "$DEADLINE"
category = "$CATEGORY"
note = """$NOTE"""
time_val = "$TIME" if "$TIME" else None

task_lists = {"学习": "424aad40-5fea-47c1-b846-48416b53f685", "工作": "55eb10db-31ed-4aee-bbf9-9dd97235e7d9", "生活": "3dda1822-a9a8-4ab9-b6ea-a278283b8224"}
list_id = task_lists.get(category, task_lists["学习"])

data_obj = {"summary": name}

if note:
    data_obj["description"] = note

if time_val:
    data_obj["reminders"] = [{"relative_fire_minute": 10}]

# 计算截止时间戳
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
    if task_id:
        # 指派给用户（+create 的 assignee 字段不生效，必须单独调用 +assign）
        assign_cmd = f'LARK_CLI_NO_PROXY=1 lark-cli task +assign --task-id "{task_id}" --add "ou_0fd19537150f90c6b2b86464285b0c65" --as user 2>/dev/null'
        subprocess.run(assign_cmd, shell=True, capture_output=True, text=True)
        print(task_id)
    else:
        print("ERROR:飞书返回数据中无任务ID")
except Exception as e:
    print(f"ERROR:{e}")
PYEOF
)

if [[ "$FEISHU_TASK_ID" == ERROR:* ]]; then
    echo "❌ 创建飞书任务失败：${FEISHU_TASK_ID#ERROR:}"
    exit 1
fi

if [ -z "$FEISHU_TASK_ID" ]; then
    echo "❌ 创建飞书任务失败：未获取到任务ID"
    exit 1
fi

echo "✅ 飞书任务创建成功"
if [ -n "$TIME" ]; then
    echo "⏰ 已设置提醒：$TIME 前10分钟"
else
    echo "🔕 未设置提醒（未指定具体时间）"
fi

# ===== 第二步：写入多维表格 =====
echo "📋 正在写入多维表格..."

RECORD_ID=$(python3 << PYEOF
import subprocess
import json

base_token = "$BASE_TOKEN"
table_id = "$TASK_TABLE"
name = "$NAME"
deadline = "$DEADLINE"
category = "$CATEGORY"
note = """$NOTE"""
time_val = "$TIME" if "$TIME" else None
feishu_id = "$FEISHU_TASK_ID"

record = {
    "标题": name,
    "日期": deadline,
    "分类": category,
    "状态": "待办",
    "飞书任务ID": feishu_id
}

if note:
    record["复盘"] = note

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
PYEOF
)

if [ -z "$RECORD_ID" ]; then
    echo "⚠️ 写入多维表格失败，但飞书任务已创建"
    echo "💡 请手动在多维表格中补充此任务"
else
    echo "✅ 已写入多维表格"
fi

echo ""
echo "✅ 任务已录入：$NAME"
echo "   截止：$DEADLINE${TIME:+ $TIME}"
echo "   分类：$CATEGORY"
echo "   飞书任务ID：$FEISHU_TASK_ID"
