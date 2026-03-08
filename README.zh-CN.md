# Ledger App

[English](README.md) | [中文](README.zh-CN.md)
[演示](#演示)

这是一个基于 Flutter 的多端记账应用，支持本地离线记账、云端同步、报表分析、定期交易和外部账单导入。

## 功能特性

- 多账户账本管理（`income`、`expense`、`pending`）
- 基于 Drift 的离线优先本地存储
- Supabase 登录认证与云端账单同步
- 报表与深度分析（趋势、分类占比、历史汇总）
- 外部账单导入（微信支付 / 支付宝 / PNC）
- 定期交易管理
- 中英文切换、主题切换、自定义背景图和宠物悬浮 UI

## 技术栈

- `Flutter` / `Dart`
- `drift` + `sqlite`（本地数据）
- `supabase_flutter`（认证 + 云同步）
- `fl_chart`（图表）
- `shared_preferences`（配置持久化）
- `image_picker` / `file_picker`（图片与文件导入）

## 项目结构

```text
lib/
  app/                 # 应用层配置（主题、设置、应用壳）
  data/db/             # Drift 数据库与表定义
  features/
    auth/              # 登录 / 重置密码
    ledger/            # 记账主页与交易流程
    reports/           # 报表与分析
    import/            # 外部账单导入
    settings/          # 设置与偏好
  services/            # 云同步、后台服务、日志
  ui/pet/              # 宠物悬浮 UI 与控制逻辑
supabase/
  ledger_bills_schema.sql  # Supabase 表结构 + RLS 策略
docs/
  ARCHITECTURE.md      # 模块与数据流说明（中文）
```

## 快速开始

1. 安装 Flutter 3.35+，并确保 `dart --version` 为 `>= 3.11.x`。
2. 安装依赖：

```bash
flutter pub get
```

3. 运行应用：

```bash
flutter run
```

## APK 下载

- Releases 页面（长期可用）：https://github.com/RonganBai/ledger/releases
- 最新发布页：https://github.com/RonganBai/ledger/releases/latest
- 直接 APK（首次发布后可用）：
  https://github.com/RonganBai/ledger/releases/latest/download/ledger-app.apk

## 发布状态

- 当前公开发布目标：仅 Android。
- Google Play 发布正在准备中。
- iOS 暂不公开发布（当前 Apple Developer Program 成本较高）。

## Supabase 配置

1. 创建 Supabase 项目。
2. 在 SQL Editor 中执行 [`supabase/ledger_bills_schema.sql`](supabase/ledger_bills_schema.sql)。
3. 将 `lib/main.dart` 中的 `Supabase.initialize(url, anonKey)` 替换为你自己的项目配置。

对于公开仓库，避免硬编码项目密钥，建议使用环境变量或构建注入方式。

## 演示

核心流程与页面预览：

- 主流程动图：`docs/media/demo.gif`
- 首页截图：`docs/media/home.jpg`
- 添加账单步骤：`docs/media/Add Bill1.jpg`、`docs/media/Add Bill2.jpg`
- 报表页面：`docs/media/report1.jpg`、`docs/media/report2.jpg`
- 设置页面：`docs/media/settings.jpg`

![Demo](docs/media/demo.gif)

### 截图

| 首页 | 添加账单 |
| --- | --- |
| ![首页](docs/media/home.jpg) | ![添加账单步骤1](docs/media/Add%20Bill1.jpg) |

| 添加账单（步骤2） | 报表 |
| --- | --- |
| ![添加账单步骤2](docs/media/Add%20Bill2.jpg) | ![报表1](docs/media/report1.jpg) |

| 报表（更多） | 设置 |
| --- | --- |
| ![报表2](docs/media/report2.jpg) | ![设置](docs/media/settings.jpg) |

## 开发与贡献

- 贡献流程：[`CONTRIBUTING.md`](CONTRIBUTING.md)
- 架构说明：[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- PR 模板：`.github/PULL_REQUEST_TEMPLATE.md`

## 路线图（建议）

- 优化云同步冲突处理策略
- 提升单元测试与集成测试覆盖率
- 提高账单导入规则的可配置性
- 标准化发布与变更日志流程

## License

本项目基于 [MIT License](LICENSE) 开源。