# 开发备忘

## 当前状态 (2026-06-08)

### 环境
- Flutter + Dart 3.x, 跨平台 (Android/iOS/Web/Windows)
- Web 端使用 MemoryStore 内存数据库（浏览器 localStorage 持久化）
- 原生端使用 SQLite (sqflite)
- Web 服务器：`dart run serve.dart`，监听 8788 端口

### 最近完成的修复
1. **UI 回滚** — 将 GlassContainer 毛玻璃效果恢复为传统 Card 组件，移除 AppAnimations 动画，恢复传统界面风格。UI 修改方案保留在 `ui_changes_backup/` 目录。
2. **编译错误修复** — 修复 screenshot_import_page.dart 方法命名不一致、order_edit_page.dart 中 getBySeriesId 改为 getBySeries、dashboard_page.dart 括号缺失等问题。
3. **main.dart.js 缺失** — 编译器生成的 js 文件未复制到 build/web/，需手动从 `.dart_tool/flutter_build/` 复制到 `build/web/`。

### Web 端运行步骤
```bash
cd gouwu
flutter pub get
flutter build web
dart run serve.dart
# 浏览器打开 http://localhost:8788
```

### 项目结构要点
```
lib/
├── database/
│   ├── dao/           # 数据访问层 (CRUD)
│   ├── memory_store.dart  # Web 端数据库实现
│   └── database_helper.dart
├── models/            # 数据模型
├── pages/
│   ├── dashboard/     # 首页仪表盘
│   ├── order/         # 订单（列表、详情、编辑、截图导入、日历）
│   ├── asset/         # 资产（IP系列、角色、商品）
│   ├── stats/         # 统计
│   ├── search/        # 搜索
│   └── settings/      # 设置
├── services/          # OCR、去重、提醒、搜索
└── theme/             # 主题配置
```

### 数据层级
```
Series (IP系列) → Character (角色) → Product (商品)
Platform (平台) → Category (品类)
Order (订单) → OrderItem (订单项)
```

### GitHub
- 仓库：https://github.com/killuailixiya-ctrl/gouwu.git
- 当前分支：main

### 已知待优化项
- 添加订单后资产/订单/统计界面数据刷新有时不生效，已通过 ValueNotifier + GlobalKey 机制修复，但需持续关注
- 截图导入 OCR 识别准确率可进一步优化
- 首页最近订单目前显示金额和平台，商品信息展示已加入