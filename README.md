# Ledger App

[中文](README.md) | [English](README.en.md)

## English Introduction

A multi-platform ledger app built with Flutter, supporting offline local bookkeeping, cloud sync, reporting, recurring transactions, and external bill import.

### Highlights

- Multi-account ledger management (`income`, `expense`, `pending`)
- Offline-first local storage with Drift
- Supabase authentication and cloud synchronization
- Reports and deep analysis (trends, category ratio, history summary)
- External bill import (WeChat Pay / Alipay / PNC)
- Recurring transaction management

### Tech Stack

- `Flutter` / `Dart`
- `drift` + `sqlite`
- `supabase_flutter`
- `fl_chart`
- `shared_preferences`
- `image_picker` / `file_picker`

完整英文文档见 [README.en.md](README.en.md)。

## 中文简介

一个基于 Flutter 的多端记账应用，支持本地离线账本、云同步、报表分析、定期交易和外部账单导入。

### 功能概览

- 多账户账本管理（收入、支出、待确认）
- Drift 本地数据库存储（离线可用）
- Supabase 账号登录与云端账单同步
- 统计与深度分析（趋势、分类占比、历史汇总）
- 微信/支付宝/PNC 等账单文件导入
- 定期交易管理
- 中英文切换、主题切换、背景图与桌宠展示

### 技术栈

- `Flutter` / `Dart`
- `drift` + `sqlite`（本地数据）
- `supabase_flutter`（鉴权与云同步）
- `fl_chart`（图表）
- `shared_preferences`（配置持久化）
- `image_picker` / `file_picker`（图片与文件导入）

## 目录结构

```text
lib/
  app/                 # 应用层配置（主题、设置、入口壳）
  data/db/             # Drift 数据库与表定义
  features/
    auth/              # 登录/重置密码
    ledger/            # 记账主页与交易管理
    reports/           # 报表与分析
    import/            # 外部账单导入
    settings/          # 设置与偏好
  services/            # 云同步、后台服务、日志
  ui/pet/              # 桌宠相关 UI/控制逻辑
supabase/
  ledger_bills_schema.sql  # Supabase 表结构与 RLS 策略
docs/
  ARCHITECTURE.md      # 模块与数据流说明
```

## 快速开始

1. 安装 Flutter 3.35+，并确保 `dart --version` >= `3.11.x`。
2. 获取依赖：

```bash
flutter pub get
```

3. 运行应用：

```bash
flutter run
```

## 云同步初始化（Supabase）

1. 在 Supabase 创建项目。
2. 执行 [`supabase/ledger_bills_schema.sql`](supabase/ledger_bills_schema.sql)。
3. 将 `lib/main.dart` 中的 `Supabase.initialize(url, anonKey)` 替换为你自己的项目配置。

建议在公开仓库中避免硬编码项目密钥，可改造为环境变量或构建参数注入。

## 演示素材占位

你可以手动补充以下资源（推荐）：

- `docs/media/demo.gif`（主流程演示）
- `docs/media/home.png`（主页截图）
- `docs/media/report.png`（报表截图）

然后在 README 中按需插入：

```md
![Demo](docs/media/demo.gif)
```

## 开发与贡献

- 贡献流程见 [`CONTRIBUTING.md`](CONTRIBUTING.md)
- 架构说明见 [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- Pull Request 模板：`.github/PULL_REQUEST_TEMPLATE.md`

## License

本项目使用 [MIT License](LICENSE)。
