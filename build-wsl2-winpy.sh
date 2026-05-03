#!/bin/bash
# WSL2 构建脚本 - 使用 Windows Python

set -e

echo "=============================================="
echo "  DuckyClaw WSL2 构建脚本 (使用 Windows Python)"
echo "=============================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_ROOT="/e/TuyaOpen/DuckyClaw"
T5_OS_PATH="$PROJECT_ROOT/TuyaOpen/platform/T5AI/t5_os"
VENV_PYTHON="$PROJECT_ROOT/TuyaOpen/.venv/Scripts/python.exe"

cd "$PROJECT_ROOT" || { echo "无法进入项目目录: $PROJECT_ROOT"; exit 1; }

# 检查 Windows Python
echo -e "${GREEN}[1/6]${NC} 检查 Windows Python..."
if [ ! -f "$VENV_PYTHON" ]; then
    echo -e "${RED}错误: 未找到 Windows Python!${NC}"
    echo "路径: $VENV_PYTHON"
    exit 1
fi

# 验证 Python 包
echo "    验证 Python 依赖..."
WINPY_PATH=$(echo "$VENV_PYTHON" | sed 's|^/mnt/e|E:|' | sed 's|/|\\|g')
python3 -c "
import subprocess
import sys

py_path = '$WINPY_PATH'
packages = ['future', 'kconfiglib', 'click', 'click_option_group', 'Crypto']

for pkg in packages:
    try:
        subprocess.run([py_path, '-c', f'import {pkg}'], check=True, capture_output=True)
        print(f'  {pkg}: OK')
    except:
        print(f'  {pkg}: FAILED')
        sys.exit(1)
print('所有依赖 OK')
" || {
    echo -e "${RED}Python 依赖检查失败${NC}"
    exit 1
}

# 修复换行符
echo -e "${GREEN}[2/6]${NC} 修复换行符..."
cd "$T5_OS_PATH"
find . -type f \( -name '*.sh' -o -name '*.py' -o -name '*.cmake' \) -exec sed -i 's/\r$//' {} + 2>/dev/null || true
echo "    完成"

# 设置环境变量
echo -e "${GREEN}[3/6]${NC} 设置环境..."
export TUYA_PROJECT_DIR="$PROJECT_ROOT"
export TUYA_APP_NAME="DuckyClaw"
export TUYA_APP_PATH="$PROJECT_ROOT"
export TUYA_TOOLCHAIN_PATH="$PROJECT_ROOT/TuyaOpen/platform/tools/gcc-arm-none-eabi-10.3-2021.10"
export PATH="$TUYA_TOOLCHAIN_PATH/bin:$PATH"

# 设置 Windows Python 为默认 Python
export PYTHON="$VENV_PYTHON"

# 复制配置
mkdir -p .build/cache
cp -f "$PROJECT_ROOT/config/ATK_T5AI_MINI_BOARD_2.4LCD_CAMERA.config" .build/cache/using.config
cp -f .build/cache/using.config "$PROJECT_ROOT/TuyaOpen/"

mkdir -p include/base/include
if [ -f "$PROJECT_ROOT/include/tuya_app_config.h" ]; then
    cp "$PROJECT_ROOT/include/tuya_app_config.h" include/base/include/tuya_iot_config.h
fi

echo "    配置: ATK T5AI Mini Board + 2.4\" SPI LCD"
echo "    完成"

# 清理之前的构建
echo -e "${GREEN}[4/6]${NC} 清理之前的构建..."
rm -rf build/bk7258 2>/dev/null || true
echo "    完成"

# 创建使用 Windows Python 的包装脚本
echo -e "${GREEN}[5/6]${NC} 创建 Python 包装脚本..."

# 创建 /tmp/python3 包装脚本
sudo tee /tmp/python3-wrapper << 'EOF'
#!/bin/bash
# Python 包装脚本 - 使用 Windows Python
WINPYTHON="E:\\TuyaOpen\\DuckyClaw\\TuyaOpen\\.venv\\Scripts\\python.exe"

# 转换路径
convert_path() {
    local path="$1"
    # 如果是 /e 开头的路径，转换为 Windows 路径
    if [[ "$path" == /e/* ]]; then
        echo "$path" | sed 's|^/e|E:|' | sed 's|/|\\|g'
    else
        echo "$path"
    fi
}

# 转换所有参数
NEW_ARGS=()
for arg in "$@"; do
    NEW_ARGS+=("$(convert_path "$arg")")
done

# 执行 Windows Python
exec "$WINPYTHON" "${NEW_ARGS[@]}"
EOF

sudo chmod +x /tmp/python3-wrapper

# 将包装脚本添加到 PATH 最前面
export PATH="/tmp:$PATH"

echo "    完成"

# 开始构建
echo -e "${GREEN}[6/6]${NC} 开始构建固件..."
echo ""
echo "    这可能需要 10-15 分钟，请耐心等待..."
echo ""

bash build.sh DuckyClaw 1.0.0 bk7258 "$PROJECT_ROOT" build 2>&1 | tee "$PROJECT_ROOT/build_wsl2.log" | tail -200

BUILD_STATUS=${PIPESTATUS[0]}

# 复制固件
echo ""
if [ $BUILD_STATUS -eq 0 ] && [ -f "build/bk7258/tuya_app/package/ua_file.bin" ]; then
    mkdir -p "$PROJECT_ROOT/dist"
    cp build/bk7258/tuya_app/package/ua_file.bin "$PROJECT_ROOT/dist/DuckyClaw_Xiaozhi_UA.bin"
    cp build/bk7258/tuya_app/package/all-app.bin "$PROJECT_ROOT/dist/DuckyClaw_Xiaozhi_QIO.bin"

    echo ""
    echo -e "${GREEN}==============================================${NC}"
    echo -e "${GREEN}              构建成功！${NC}"
    echo -e "${GREEN}==============================================${NC}"
    echo ""
    echo "固件文件:"
    ls -lh "$PROJECT_ROOT/dist/"*.bin 2>/dev/null || true
    echo ""
    echo "固件位置:"
    echo "  UA 固件: $PROJECT_ROOT/dist/DuckyClaw_Xiaozhi_UA.bin"
    echo "  QIO 固件: $PROJECT_ROOT/dist/DuckyClaw_Xiaozhi_QIO.bin"
    echo ""
    echo "烧录方法:"
    echo "  1. 打开 Tuya Uart Tool"
    echo "  2. 选择串口 (如 COM3)"
    echo "  3. 加载 $PROJECT_ROOT/dist/DuckyClaw_Xiaozhi_UA.bin"
    echo "  4. 点击烧录"
    echo ""
    echo "查看日志: 波特率 460800"
    echo -e "${GREEN}==============================================${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}==============================================${NC}"
    echo -e "${RED}              构建失败！${NC}"
    echo -e "${RED}==============================================${NC}"
    echo ""
    echo "请查看日志: $PROJECT_ROOT/build_wsl2.log"
    echo ""
    echo "常见错误:"
    echo "  - Python 依赖问题"
    echo "  - ARM 工具链问题"
    echo "  - 配置错误"
    echo ""
    exit 1
fi
