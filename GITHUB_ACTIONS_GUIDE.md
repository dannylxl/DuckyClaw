# GitHub Actions 自动编译指南

## 快速开始

### 步骤 1：Fork 仓库
1. 访问 https://github.com/tuya/DuckyClaw
2. 点击右上角的 "Fork" 按钮
3. 选择您的 GitHub 账户

### 步骤 2：克隆 Fork 的仓库到本地
```bash
git clone https://github.com/YOUR_USERNAME/DuckyClaw.git
cd DuckyClaw
```

### 步骤 3：添加 XIAOZHI UI 代码
我已为您创建了所有必要的 XIAOZHI UI 文件。确保这些文件已提交：
- `ai_components/ai_ui/src/ai_ui_chat_xiaozhi.c`
- `ai_components/ai_ui/src/ai_ui_standby_face.c`
- `ai_components/ai_ui/include/ai_ui_chat_xiaozhi.h`
- `ai_components/ai_ui/include/ai_ui_standby_face.h`
- `.github/workflows/build_t5ai_xiaozhi.yml`

### 步骤 4：推送代码到您的 Fork
```bash
git add .
git commit -m "Add XIAOZHI UI with animated standby face"
git push origin master
```

### 步骤 5：查看 GitHub Actions 构建
1. 访问您的 Fork 仓库：https://github.com/YOUR_USERNAME/DuckyClaw
2. 点击 "Actions" 标签
3. 等待 "Build T5AI Firmware with Xiaozhi UI" 工作流完成（约 10-15 分钟）
4. 构建完成后，点击最新的运行记录
5. 在 "Artifacts" 部分下载 `DuckyClaw_Xiaozhi_Firmware`

### 步骤 6：烧录固件
1. 解压下载的固件包
2. 使用 Tuya Uart Tool 烧录 `DuckyClaw_Xiaozhi_UA.bin`

---

## 手动触发构建

如果需要重新构建：
1. 访问您的 Fork 仓库 Actions 页面
2. 选择 "Build T5AI Firmware with Xiaozhi UI"
3. 点击 "Run workflow" 按钮
4. 选择分支（master）并点击 "Run workflow"

---

## 故障排除

### 构建失败
- 检查 GitHub Actions 日志获取详细错误信息
- 确保所有子模块已正确初始化
- 检查 TuyaOpen 平台代码是否完整

### 固件无法启动
- 确认烧录的是 UA 文件（不是 QIO）
- 使用 Tuya Uart Tool 查看串口日志（波特率 460800）
- 检查是否有权限问题

---

## 本地构建（高级用户）

如果您有 Linux 环境：

```bash
# 安装依赖
sudo apt-get install git wget build-essential cmake ninja-build

# 进入 T5AI 平台目录
cd TuyaOpen/platform/T5AI/t5_os

# 设置环境变量
export TUYA_PROJECT_DIR=$(cd ../../.. && pwd)
export TUYA_APP_NAME="DuckyClaw"
export TUYA_TOOLCHAIN_PATH="$TUYA_PROJECT_DIR/platform/tools/gcc-arm-none-eabi-10.3-2021.10"
export PATH="$TUYA_TOOLCHAIN_PATH/bin:$PATH"

# 创建配置文件
mkdir -p include/base/include
cp "$TUYA_PROJECT_DIR/include/tuya_app_config.h" include/base/include/tuya_iot_config.h

# 构建
bash build.sh DuckyClaw 1.0.0 bk7258 "$TUYA_PROJECT_DIR" build

# 输出位置
# build/bk7258/tuya_app/package/ua_file.bin
```
