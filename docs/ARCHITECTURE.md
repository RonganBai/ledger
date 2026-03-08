# Architecture Overview

## 1. 总体结构

项目采用 Flutter 单仓库多端结构（Android/iOS/Web/Desktop），核心业务集中在 `lib/`：

- `app/`: 应用壳、主题与全局配置
- `data/db/`: Drift 数据库、表定义与数据访问
- `features/`: 按业务域拆分功能模块
- `services/`: 跨模块服务（云同步、后台、日志）
- `ui/pet/`: 桌宠与覆盖层 UI

## 2. 模块边界

### Auth（`features/auth`）

- 负责登录、会话状态、重置密码等流程。
- 通过 Supabase Auth 获取用户身份。

### Ledger（`features/ledger`）

- 负责主记账页面、交易列表、增删改查、分类/账户操作。
- 直接依赖本地数据库表（`transactions`, `accounts`, `categories`）。

### Reports（`features/reports`）

- 负责统计分析、趋势图、月度汇总、历史视图。
- 从本地数据库读取数据并生成聚合结果。

### Import（`features/import`）

- 解析 CSV/XLSX 等外部账单文件。
- 去重后写入本地交易表，支持多来源格式。

### Settings（`features/settings`）

- 负责主题、语言、提醒、导入导出等偏好配置。

## 3. 数据层设计

### 本地存储

- 使用 Drift 管理本地 SQLite 数据。
- 关键表：`accounts`, `transactions`, `categories`, `recurring_transactions`, `sync_state`。

### 云同步

- 使用 Supabase Postgres 表：`ledger_accounts`, `ledger_bills`。
- 通过 RLS（Row Level Security）保证用户仅访问自己的数据。
- 同步服务位于 `services/cloud_bill_sync_service.dart`。

## 4. 关键数据流

1. 用户在 UI 侧触发记账/编辑。
2. 交易写入本地 Drift。
3. 登录状态下由云同步服务上传或下行合并。
4. 报表页面从本地库读取聚合，不直接依赖云端响应。

## 5. 当前工程观察

- 仓库内存在部分历史备份文件（如 `lib.zip`、`assets.zip`），建议确认是否保留在主分支。
- `lib/main.dart` 中使用了硬编码 Supabase 初始化参数，若仓库公开建议迁移为环境注入方式。
- `lib/data/db/` 下存在重复目录 `db/tables` 与 `tables`，建议后续做一次目录清理。
