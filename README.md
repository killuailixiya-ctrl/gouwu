# 购物 (GouWu)

二次元周边购物记录管理应用，支持跨平台订单追踪、智能去重、补款提醒，让你的每一笔周边消费都清晰可查。

## 功能概览

### 首页仪表盘
- **本月消费概览** — 直观展示当月总消费金额和订单数量
- **待处理提醒** — 显示即将到期的补款提醒，按紧急程度排序，支持一键确认
- **快速操作** — 手动录入 / 截图导入 / 购买日历，一键进入对应功能
- **热门 IP** — 展示拥有商品最多的 IP 系列，点击可查看该系列下的角色和商品
- **最近订单** — 显示最近 5 笔订单的详情，包含平台、订单号、金额、商品信息和状态

### 订单管理
- **订单列表** — 按时间倒序展示所有订单，支持筛选和查看详情
- **手动录入** — 选择平台、IP、角色、商品，填写价格、数量等信息快速录入
- **截图导入** — 上传订单截图，通过 OCR 自动识别订单号、金额和商品名称，可手动修正
- **订单详情** — 查看完整订单信息，包括订单项、截图、备注等
- **订单编辑** — 支持修改已有订单的所有信息
- **购买日历** — 以日历视图展示购买记录，一目了然

### 资产管理
- **IP 系列** — 管理你关注的动漫/游戏 IP（如原神、崩坏星穹铁道等）
- **角色管理** — 每个 IP 下可添加多个角色
- **商品管理** — 每个角色下管理具体商品（手办、徽章、立牌等），支持名称、规格、参考价
- **智能去重** — 录入商品时自动检测是否已购买过相同或相似商品，避免重复下单

### 统计分析
- 月度 / 年度消费趋势
- 按平台、IP、品类的消费分布
- 消费排行榜

### 全局搜索
- 支持按订单号、商品名称、IP 名称等关键词搜索
- 快速定位历史订单和商品

## 技术栈

| 层级 | 技术 |
|------|------|
| 框架 | Flutter 3.x (Dart) |
| 数据库 (Web) | MemoryStore（内存数据库，浏览器端持久化） |
| 数据库 (原生) | SQLite (sqflite) |
| OCR | Google ML Kit Text Recognition |
| 图片处理 | image_picker / flutter_image_compress |
| 状态管理 | setState + ValueNotifier + GlobalKey |
| UI | Material Design 3 |

## 项目结构

```
lib/
├── app.dart                    # 应用入口，底部导航栏
├── main.dart                   # main() 函数，初始化
├── database/
│   ├── dao/                    # 数据访问层 (CRUD)
│   │   ├── order_dao.dart      # 订单 DAO
│   │   ├── order_item_dao.dart # 订单项 DAO
│   │   ├── platform_dao.dart   # 平台 DAO
│   │   ├── series_dao.dart     # IP 系列 DAO
│   │   ├── character_dao.dart  # 角色 DAO
│   │   ├── product_dao.dart    # 商品 DAO
│   │   ├── category_dao.dart   # 品类 DAO
│   │   └── reminder_dao.dart   # 提醒 DAO
│   ├── memory_database.dart    # 内存数据库初始化
│   ├── memory_store.dart       # 内存存储实现（Web 端使用）
│   └── database_helper.dart    # 数据库辅助工具
├── models/                     # 数据模型
│   ├── order.dart              # 订单模型
│   ├── order_item.dart         # 订单项模型
│   ├── platform.dart           # 平台模型
│   ├── series.dart             # IP 系列模型
│   ├── character.dart          # 角色模型
│   ├── product.dart            # 商品模型
│   ├── category.dart           # 品类模型
│   └── reminder.dart           # 提醒模型
├── pages/
│   ├── dashboard/              # 首页仪表盘
│   ├── order/                  # 订单相关页面
│   │   ├── order_list_page.dart          # 订单列表
│   │   ├── order_detail_page.dart        # 订单详情
│   │   ├── order_edit_page.dart          # 手动录入/编辑
│   │   ├── screenshot_import_page.dart   # 截图导入（OCR）
│   │   └── calendar_page.dart            # 购买日历
│   ├── asset/                  # 资产管理页面
│   │   ├── series_list_page.dart         # IP 系列列表
│   │   ├── character_list_page.dart      # 角色列表
│   │   └── character_products_page.dart  # 角色商品
│   ├── stats/                  # 统计分析
│   ├── search/                 # 全局搜索
│   └── settings/               # 设置（平台管理、品类管理）
├── services/                   # 业务服务
│   ├── ocr_service.dart        # OCR 识别服务
│   ├── dedup_service.dart      # 重复检测服务
│   ├── reminder_service.dart   # 提醒生成服务
│   └── search_service.dart     # 搜索服务
└── theme/                      # 主题相关
    ├── app_theme.dart          # 应用主题配置
    ├── glass_container.dart    # 毛玻璃容器组件
    └── app_animations.dart     # 动画工具
```

## 快速开始

### 环境要求

- Flutter SDK >= 3.41
- Dart SDK >= 3.1.0

### Web 端运行

```bash
# 安装依赖
flutter pub get

# 构建 Web
flutter build web

# 启动本地服务器
dart run serve.dart

# 浏览器打开 http://localhost:8788
```

### Android 端运行

```bash
# 安装依赖
flutter pub get

# 运行到设备
flutter run

# 构建 APK
flutter build apk
```

### Windows 端运行

```bash
flutter pub get
flutter run -d windows
```

## 数据模型

### 订单 (Order)
- 所属平台、订单号、总金额、订单状态
- 是否预售、定金金额、补款截止日期
- 订单时间、备注、截图路径
- 关联多个订单项 (OrderItem)

### 订单项 (OrderItem)
- 商品名称、规格、数量、单价
- 关联 IP 系列 (Series)、角色 (Character)、品类 (Category)

### 资产层级
```
Series (IP系列) → Character (角色) → Product (商品)
Platform (平台) → Category (品类)
```

## 核心功能说明

### 截图导入流程
1. 点击「截图导入」，选择订单截图
2. 系统使用 Google ML Kit 进行 OCR 文字识别
3. 自动提取订单号、金额、商品名称
4. 用户确认或手动修正识别结果
5. 选择对应的 IP、角色、品类信息
6. 保存后自动生成补款提醒（预售订单）

### 重复检测
- 录入商品时自动比对已有商品
- 支持名称相似度、规格匹配等多维度检测
- 防止同一商品重复购买

### 补款提醒
- 预售订单自动生成补款提醒
- 支持到期前 7 天、3 天、1 天、当天及到期后 1 天提醒
- 首页仪表盘优先展示高优先级提醒

## License

MIT