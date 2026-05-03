# XIAOZHI UI 构建指南

## ✅ 推送成功！

代码已推送到您的 Fork：
- **分支**: `xiaozhi-feature`
- **仓库**: https://github.com/dannylxl/DuckyClaw

---

## 下一步：触发 GitHub Actions 构建

### 方法 1：在 GitHub 网页上操作（推荐）

1. **访问 Actions 页面**
   - 打开：https://github.com/dannylxl/DuckyClaw/actions

2. **手动触发工作流**
   - 点击左侧的 "Build T5AI Firmware with Xiaozhi UI"
   - 点击右上角的 "Run workflow" 按钮
   - 选择分支：`xiaozhi-feature`
   - 点击绿色的 "Run workflow" 按钮

3. **等待构建完成**
   - 构建时间：约 10-15 分钟
   - 您可以在 Actions 页面查看进度

4. **下载固件**
   - 构建完成后，点击运行记录
   - 在 "Artifacts" 部分找到 `DuckyClaw_Xiaozhi_Firmware`
   - 点击下载 ZIP 文件

### 方法 2：创建 Pull Request（可选）

如果您想将代码合并到主分支：

1. 访问：https://github.com/dannylxl/DuckyClaw/pull/new/xiaozhi-feature
2. 创建 Pull Request 从 `xiaozhi-feature` 到 `master`
3. 合并后 Actions 会自动运行

---

## 烧录固件

1. **解压下载的文件**
   ```
   DuckyClaw_Xiaozhi_UA.bin  ← 使用这个文件
   DuckyClaw_Xiaozhi_QIO.bin
   ```

2. **使用 Tuya Uart Tool**
   - 选择串口（COM3）
   - 选择 `DuckyClaw_Xiaozhi_UA.bin`
   - 点击 "烧录"

3. **查看串口日志**
   - 波特率：460800
   - 检查是否正常启动

---

## 故障排除

### 构建失败
1. 查看 Actions 日志获取详细错误
2. 确保 TuyaOpen 子模块已正确初始化
3. 重试运行 workflow

### 屏幕黑屏
1. 首先检查串口日志（460800 波特率）
2. 确认固件大小正常（约 4-5MB）
3. 尝试完整擦除后再烧录

---

## 文件说明

已添加的文件：
- `ai_ui_chat_xiaozhi.c/h` - 小智风格聊天界面
- `ai_ui_standby_face.c/h` - 待机表情动画组件
- `.github/workflows/build_t5ai_xiaozhi.yml` - GitHub Actions 配置
- `GITHUB_ACTIONS_GUIDE.md` - 详细构建指南

---

**构建成功后，固件将包含：**
- ✅ 动画待机表情（眨眼、多表情切换）
- ✅ 聊天界面切换
- ✅ 语音对话 UI
- ✅ 网络状态显示
