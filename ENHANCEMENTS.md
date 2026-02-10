# DataLabChat 多格式文件加载增强 - Feb 9, 2026

## 实现的功能

### 1. ✅ 多格式文件支持
**新增 `read_any()` 函数**，支持：
- **CSV** - via `readr::read_csv()`
- **TSV/TXT** - via `readr::read_tsv()`
- **XLSX/XLS** - via `readxl::read_excel()`
- **Parquet** - via `arrow::read_parquet()` (可选)
- **RDS** - via `readRDS()`

错误处理：
- 文件格式不支持时给出清晰错误提示
- 读取失败时返回错误对象，由 UI 展示

### 2. ✅ 改进的 UI 文件加载区域
**Data Loader 部分增强：**

```
📤 Upload Data
   ├─ fileInput: 支持 CSV/TSV/XLSX/Parquet/RDS
   ├─ 📌 "Load Sample Data (mtcars)" 按钮
   └─ 📊 状态显示区: "✓ Loaded xxx: 32 rows × 11 cols [METADATA]"
```

新增组件：
- `actionButton("load_sample_data")` - 一键加载 mtcars 示例数据
- 实时状态反馈 - 显示加载成功/失败状态

### 3. ✅ 动态 Reactive 数据管理
**新增 `data_load_msg` reactiveVal**：
- 追踪最后一次数据加载的状态
- 条件化显示状态消息（仅在有消息时显示）

**文件上传流程：**
```
用户上传 → read_any() 读取 → 自动推断类型 → 添加到数据源池
→ 更新 active_dataset → 显示状态消息 → 更新 schema/预览
```

**示例数据流程：**
```
点击按钮 → 加载 mtcars → 推断类型 → 同上流程
```

### 4. ✅ 修复已知问题

**问题 1: navset_tab 报错**
```diff
# 错误写法 (style 作为命名参数)
- nav_panel("Code", verbatimTextOutput(...), style = "height: 500px;")

# 正确写法 (style 在 div 中)
+ nav_panel("Code", div(style = "height: 500px;", verbatimTextOutput(...)))
```
✅ 已修复所有 4 个 nav_panel 的 style 参数

**问题 2: small() 函数不存在**
✅ 已在前次修复中处理（使用 `tags$small()`)

## 代码改动细节

### 库导入 (Lines 1-15)
```r
library(readr)      # CSV/TSV support
library(readxl)     # Excel support
# arrow 包是可选的 - 通过条件加载处理
```

### 新增函数
- `read_any(file_path)` - 统一的多格式读取函数

### UI 改进 (Sidebar)
```r
fileInput(..., accept = c(".csv", ".tsv", ".xlsx", ".parquet", ".rds"))
actionButton("load_sample_data", "Load Sample Data (mtcars)")
uiOutput("data_status_ui")  # 条件显示状态
```

### Server 端改进
- **新 observeEvent**: `input$file_input` - 改进的文件上传处理
- **新 observeEvent**: `input$load_sample_data` - 示例数据加载
- **新 reactiveVal**: `data_load_msg` - 状态消息管理
- **新 output**: `data_status_ui`, `data_load_status` - 状态显示

## 使用流程

### 上传自定义数据
```
1. 在"Data Loader"点击"Upload Data"
2. 选择 CSV/XLSX/Parquet/RDS 文件
3. 自动推断数据类型 (nodes/edges/metadata)
4. 显示: "✓ Loaded xxx.csv: 1500 rows × 8 cols [NODES]"
5. Schema 和预览表格自动更新
6. 开始分析
```

### 快速演示 (示例数据)
```
1. 点击"Load Sample Data (mtcars)"按钮
2. 自动加载 R 内置 mtcars 数据集
3. 显示: "✓ Loaded mtcars (sample): 32 rows × 11 cols [METADATA]"
4. 立即可用，无需文件选择
```

## 文件格式兼容性

| 格式 | 库 | 状态 | 说明 |
|------|-----|------|------|
| CSV | readr | ✅ | 完全支持 |
| TSV/TXT | readr | ✅ | 完全支持 |
| XLSX/XLS | readxl | ✅ | 完全支持 |
| Parquet | arrow | ⚠️ | 可选（缺失时有友好提示） |
| RDS | base | ✅ | 完全支持 |

## 测试验证步骤

```bash
# 1. 启动应用
cd /Users/yanghu/Documents/AI_Workspace/prototypes/DataLabChat
Rscript -e "shiny::runApp('app.R')"

# 2. 打开浏览器
# http://127.0.0.1:XXXX

# 3. 测试步骤：
# a) 点击 "Load Sample Data (mtcars)" → 验证状态消息显示
# b) 上传本地 CSV 文件 → 验证自动类型推断
# c) 检查 Schema Summary 是否更新
# d) 检查预览表格是否显示数据
# e) 发送查询 "summary" → 验证代码生成工作
# f) 检查 History 标签是否记录源类型
```

## 向后兼容性

✅ 所有改动向后兼容：
- 现有的多源数据管理系统保持不变
- 现有的代码生成逻辑保持不变
- 新增功能是纯附加的，不破坏现有功能

## 后续可能的增强

1. 数据预览窗口 - 上传后在模态框显示前 N 行
2. 列类型自定义 - 允许用户调整推断的列类型
3. 数据清洗工具 - 缺失值处理、类型转换
4. 批量上传 - 支持同时上传多个文件
5. 数据来源管理 UI - 在侧边栏显示所有已加载源并支持删除

---

**最后修改**: 2026-02-09
**相关文件**: app.R (978 行)
**依赖包**: shiny, bslib, DT, ggplot2, dplyr, httr2, readr, readxl, (可选: arrow)
