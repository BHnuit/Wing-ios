
### 设置页功能目录（规划）

#### 入口与路由结构
- **底部导航入口**
  - 设置 Tab → `#/settings`
- **设置相关路由**
  - **设置首页**：`#/settings`
  - **模型配置**：`#/settings/ai`
  - **显示选项**：`#/settings/language`
  - **存储管理**：`#/settings/storage`
  - **记忆管理**：`#/settings/memory`（仅在启用长期记忆后，从设置首页显示入口）
  - **更新日志**：`#/changelog`（从设置首页底部 Logo 进入）

---

### `#/settings`（设置首页）
- **数据统计**
  - **记录热力图（日历）**：最近最多 365 天，按容器宽度自适应列数；显示每一天是否有记录（fragment/entry）
  - **今日挥动翅膀次数**：今日消息/片段数量统计
  - **累计羽毛数**：全量片段/羽毛统计
- **功能入口（菜单）**
  - **模型配置** → `#/settings/ai`
  - **显示选项** → `#/settings/language`
  - **存储管理** → `#/settings/storage`
  - **长期记忆管理** → `#/settings/memory`（条件：`enableLongTermMemory = true` 才显示入口）
- **其它**
  - **查看更新日志**：点击底部 Logo → `#/changelog`
  - **版本展示**：底部显示 `v0.2.1`

---

### `#/settings/ai`（模型配置）
- **AI 选项**
  - **AI 服务商选择**：Gemini / OpenAI / DeepSeek / Custom
  - **API Key（按服务商分别保存）**
    - 输入框：支持粘贴
    - **明文/隐藏切换**（Eye / EyeOff）
  - **Custom Base URL**（仅 Custom 时显示）
  - **模型名（按服务商分别保存）**
    - 非 Custom：下拉预设 + “自定义”输入
    - Custom：直接输入模型名
  - **测试连接**：调用 `AiService.testConnection`，展示 testing/success/error 状态提示
- **文风选项**
  - **写作风格**：letter / prose / report / custom
  - **风格提示词**
    - 非 custom：展示预设（只读）
    - custom：可编辑 `writingStylePrompt`
- **洞察选项**
  - **洞察提示词**：可编辑 `insightPrompt`
- **长期记忆**
  - **启用长期记忆**：开关 `enableLongTermMemory`
    - 开启后：设置首页出现“记忆管理”入口

---

### `#/settings/language`（显示选项）
- **主题（Theme）**
  - system / light / dark
- **页面字体（Page Font）**
  - system / 思源黑体（source-han-sans）/ 思源宋体（source-han-serif）/ 霞鹜文楷（xlwk）
- **字号（Font Size）**
  - large / medium / small（通过根字号缩放影响全站 rem）
- **页面显示语言（UI Language）**
  - 中文 / English
- **模型返回语言（Model Response Language）**
  - same（跟随页面语言）/ 中文 / English（含对应提示文案）

---

### `#/settings/storage`（存储管理）
- **存储策略开关**
  - **保留编辑历史**：`keepEditHistory`
  - **备份 API Keys**：`backupApiKeys`
- **本地数据（导入/导出/替换/清空）**
  - **导出数据**：`downloadData()`（提示导出格式为 `.json/.zip`）
  - **导入数据**（弹窗选择导入方式）
    - **从文件导入**：选择 `.json/.zip` → `importData(file)` → 成功后刷新页面
    - **从文件夹导入**：选择目录（`webkitdirectory`）→ `importDataFromFolder(files)` → 成功后刷新页面
  - **替换数据**（弹窗选择替换方式 + 二次确认）
    - **从文件替换**：选择 `.json/.zip` → `replaceData(file)` → 成功后刷新页面
    - **从文件夹替换**：选择目录 → `replaceDataFromFolder(files)` → 成功后刷新页面
  - **清空数据**
    - 弹窗确认 → `MockDataService.clearData()`（清空本地数据并刷新页面）
- **反馈机制**
  - 所有导入/导出/替换操作均使用 Toast 提示 success/error

---

### `#/settings/memory`（记忆管理，仅启用长期记忆后可见入口）
- **自动提取/检索开关**
  - **自动提取记忆**：`memoryExtractionAuto`（默认开启：`!== false`）
  - **生成时检索记忆**：`memoryRetrievalEnabled`
    - 启用门槛：本地记忆数量需 **≥ 100**（不足则 Toast 警告）
- **手动操作**
  - **从指定日记提取记忆**
    - 选择日记条目（下拉）→ “提取”按钮 → `extractMemoriesFromEntry(entry, settings)`（AI 调用）
  - **合并相似记忆**：`mergeSimilarMemories()`
  - **删除全部记忆**：两段式确认弹窗 → 逐条删除
- **记忆列表**
  - **类型筛选**：semantic / episodic / procedural（含类型说明与数量统计）
  - **分页**：每页 20 条，上一页/下一页 + 页码按钮
  - **单条记忆操作**
    - **双击进入编辑**
    - **编辑字段（按类型）**
      - semantic：`key` / `value`（并展示 `confidence` 百分比）
      - episodic：`event` / `emotion`
      - procedural：`pattern` / `preference`（并展示 `frequency`）
    - **保存 / 取消 / 删除**（删除含 confirm）
- **反馈机制**
  - 操作成功/失败均使用 Toast 提示（含 AI 调用错误提示）