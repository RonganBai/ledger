# Contributing Guide

感谢你对 Ledger App 的关注。为保证代码质量和协作效率，请按以下流程参与开发。

## 开发环境

- Flutter `3.35+`
- Dart `3.11+`
- 建议开启 `flutter_lints`

## 分支策略

- `main`: 稳定分支
- 功能开发：`feat/<short-name>`
- 问题修复：`fix/<short-name>`
- 文档更新：`docs/<short-name>`

## 提交流程

1. 从 `main` 拉取最新代码并创建分支。
2. 完成功能后运行检查：

```bash
flutter analyze
flutter test
```

3. 提交信息建议使用：

```text
feat: add xxx
fix: resolve xxx
docs: update xxx
refactor: optimize xxx
```

4. 提交 PR，并按模板补充变更说明、测试结果和风险点。

## 代码规范

- 保持单一职责，避免超大组件/服务文件继续膨胀。
- 业务逻辑尽量下沉至 `services/` 或 `features/*/` 内的独立模块。
- 数据库结构变更需同步更新对应文档和迁移策略。
- 避免提交本地机器敏感配置（密钥、签名文件、私有证书）。

## Issue 反馈

提 Bug 或需求时，请优先使用 `.github/ISSUE_TEMPLATE/` 下模板，尽量提供：

- 复现步骤
- 期望行为与实际行为
- 设备/系统/Flutter 版本
- 截图或日志（如有）
