# 飞书多维表格配置

## 表格信息

**表格名称**：我的成长计划
**Base Token**：YOUR_BASE_TOKEN
**表格地址**：YOUR_BASE_URL

---

## 表1：固定日程

**Table ID**：YOUR_SCHEDULE_TABLE_ID

### 字段配置

| 字段名 | 字段ID | 类型 | 说明 |
|--------|--------|------|------|
| 日程名称 | - | 文本 | 日程内容 |
| 开始时间 | - | 日期时间 | 日程开始时间 |
| 重复规则 | - | 单选 | 每天/每周/每月 |
| 状态 | - | 单选 | 进行中/已暂停/已结束 |
| 飞书日历事件ID | - | 文本 | 同步到飞书日历的事件ID |

### 操作命令

#### 写入日程

```bash
lark-cli base +record-upsert \
  --base-token "YOUR_BASE_TOKEN" \
  --table-id "YOUR_SCHEDULE_TABLE_ID" \
  --json '{"日程名称":"每天早上8点起床","开始时间":"2026-04-18 08:00:00","重复规则":"每天","状态":"进行中"}' \
  --as user
```

#### 查询日程

```bash
lark-cli base +record-list \
  --base-token "YOUR_BASE_TOKEN" \
  --table-id "YOUR_SCHEDULE_TABLE_ID" \
  --as user
```

---

## 表2：任务

**Table ID**：YOUR_TASK_TABLE_ID

### 字段配置

| 字段名 | 字段ID | 类型 | 说明 |
|--------|--------|------|------|
| 日期 | fld5IYqRy4 | 日期 | 任务日期 YYYY-MM-DD |
| 标题 | fldqux9alc | 文本 | 任务名称 |
| 具体时间 | fldC7iWF4B | 日期时间 | 任务具体时间 |
| 分类 | fldydzm2hy | 单选 | 学习/工作/生活 |
| 状态 | fldSzwfWct | 单选 | 未开始/进行中/已完成 |
| 复盘 | fldDBMAATd | 文本 | 任务复盘内容 |
| 飞书任务ID | fldo3z0jcO | 文本 | 同步到飞书任务的任务ID |

### 操作命令

#### 写入任务

```bash
lark-cli base +record-upsert \
  --base-token "YOUR_BASE_TOKEN" \
  --table-id "YOUR_TASK_TABLE_ID" \
  --json '{"fld5IYqRy4":"2026-04-17","fldqux9alc":"改简历","fldydzm2hy":"工作","fldSzwfWct":"未开始"}' \
  --as user
```

#### 查询今日任务

```bash
lark-cli base +record-list \
  --base-token "YOUR_BASE_TOKEN" \
  --table-id "YOUR_TASK_TABLE_ID" \
  --as user
```

---

## 表3：习惯

**Table ID**：YOUR_HABIT_TABLE_ID

### 字段配置

| 字段名 | 字段ID | 类型 | 说明 |
|--------|--------|------|------|
| 习惯名称 | - | 文本 | 习惯内容 |
| 标签 | - | 单选 | 健康/学习/工作/生活/爱好 |
| 累计天数 | - | 数字 | 累计打卡天数 |
| 连续天数 | - | 数字 | 连续打卡天数 |
| 创建日期 | - | 日期 | 创建日期 |
| 最后打卡日期 | - | 日期 | 最后打卡日期 |
| 是否启用 | - | 复选框 | 是否启用 |

### 操作命令

#### 创建习惯

```bash
lark-cli base +record-upsert \
  --base-token "YOUR_BASE_TOKEN" \
  --table-id "YOUR_HABIT_TABLE_ID" \
  --json '{"习惯名称":"阅读30分钟","标签":"学习","累计天数":0,"连续天数":0,"是否启用":true}' \
  --as user
```

#### 打卡习惯

```bash
lark-cli base +record-upsert \
  --base-token "YOUR_BASE_TOKEN" \
  --table-id "YOUR_HABIT_TABLE_ID" \
  --record-id "记录ID" \
  --json '{"累计天数":5,"连续天数":5,"最后打卡日期":"2026-04-17"}' \
  --as user
```

---

## 表4：打卡记录

**Table ID**：YOUR_CHECKIN_TABLE_ID

### 字段配置

| 字段名 | 字段ID | 类型 | 说明 |
|--------|--------|------|------|
| 日期 | - | 日期 | 打卡日期 |
| 习惯名称 | - | 文本 | 关联习惯名称 |
| 复盘 | - | 文本 | 打卡复盘内容 |
| 是否打卡 | - | 复选框 | 是否已打卡 |

### 操作命令

#### 写入打卡记录

```bash
lark-cli base +record-upsert \
  --base-token "YOUR_BASE_TOKEN" \
  --table-id "YOUR_CHECKIN_TABLE_ID" \
  --json '{"日期":"2026-04-17","习惯名称":"阅读30分钟","复盘":"今天读了一章，很有收获","是否打卡":true}' \
  --as user
```

---

## 表5：灵感

**Table ID**：YOUR_IDEA_TABLE_ID

### 字段配置

| 字段名 | 字段ID | 类型 | 说明 |
|--------|--------|------|------|
| 灵感内容 | - | 文本 | 灵感内容 |
| 标签 | - | 多选 | 健康/学习/工作/生活/爱好 |
| 创建时间 | - | 日期时间 | 创建时间 |

### 操作命令

#### 记录灵感

```bash
lark-cli base +record-upsert \
  --base-token "YOUR_BASE_TOKEN" \
  --table-id "YOUR_IDEA_TABLE_ID" \
  --json '{"灵感内容":"想学习一门新技能","标签":["学习"],"创建时间":"2026-04-17 22:00:00"}' \
  --as user
```

---

## 飞书任务清单ID

| 分类 | 清单ID |
|------|--------|
| 学习 | YOUR_STUDY_LIST_ID |
| 工作 | YOUR_WORK_LIST_ID |
| 生活 | YOUR_LIFE_LIST_ID |

### 创建飞书任务

```bash
lark-cli task +create \
  --title "任务名称" \
  --section-guid "YOUR_XXX_LIST_ID" \
  --as user
```

### 更新飞书任务

```bash
lark-cli task +update \
  --task-id "任务ID" \
  --title "新任务名称" \
  --as user
```

### 查询飞书任务

```bash
lark-cli task +get-my-tasks \
  --complete=false \
  --page-all \
  --as user
```

---

## 飞书日历操作

### 创建日历事件

```bash
lark-cli calendar +create \
  --summary "日程名称" \
  --start "2026-04-18T08:00:00" \
  --end "2026-04-18T09:00:00" \
  --as user
```

### 创建重复日历事件

需要通过飞书API或网页端创建重复事件。

---

## 注意事项

- 任务分类对应不同的飞书任务清单
- 飞书日历的重复事件需要特殊处理
- 时区使用北京时间（Asia/Shanghai）
