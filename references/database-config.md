# 飞书多维表格配置

## 表格信息

**表格名称**：Faye的成长计划
**Base Token**：your_base_token_here
**表格地址**：https://lcn6itdxogbg.feishu.cn/base/your_base_token_here

---

## 表1：固定日程

**Table ID**：tblAO5xVkCvkVW07

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
  --base-token "your_base_token_here" \
  --table-id "tblAO5xVkCvkVW07" \
  --json '{"日程名称":"每天早上8点起床","开始时间":"2026-04-18 08:00:00","重复规则":"每天","状态":"进行中"}' \
  --as user
```

#### 查询日程

```bash
lark-cli base +record-list \
  --base-token "your_base_token_here" \
  --table-id "tblAO5xVkCvkVW07" \
  --as user
```

---

## 表2：任务

**Table ID**：tblI3CavMGlKSbml

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
  --base-token "your_base_token_here" \
  --table-id "tblI3CavMGlKSbml" \
  --json '{"fld5IYqRy4":"2026-04-17","fldqux9alc":"改简历","fldydzm2hy":"工作","fldSzwfWct":"未开始"}' \
  --as user
```

#### 查询今日任务

```bash
lark-cli base +record-list \
  --base-token "your_base_token_here" \
  --table-id "tblI3CavMGlKSbml" \
  --as user
```

---

## 飞书任务清单ID

| 分类 | 清单ID |
|------|--------|
| 学习 | 424aad40-5fea-47c1-b846-48416b53f685 |
| 工作 | 55eb10db-31ed-4aee-bbf9-9dd97235e7d9 |
| 生活 | 3dda1822-a9a8-4ab9-b6ea-a278283b8224 |

### 创建飞书任务

```bash
lark-cli task +create \
  --title "任务名称" \
  --section-guid "清单ID" \
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

- 情绪标签是**单选**，只能填一个选项
- 任务分类对应不同的飞书任务清单
- 飞书日历的重复事件需要特殊处理
- 时区使用北京时间（Asia/Shanghai）
