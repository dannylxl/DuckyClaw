#!/bin/bash
set -e

echo "=============================================="
echo "  DuckyClaw Docker 构建脚本 (Linux/Mac/WSL)"
echo "=============================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: Docker 未安装!${NC}"
    echo "请先安装 Docker:"
    echo "  - Ubuntu/Debian: sudo apt-get install docker.io"
    echo "  - Mac: https://docs.docker.com/desktop/install/mac-install/"
    echo "  - Windows: https://docs.docker.com/desktop/install/windows-install/"
    exit 1
fi

# 检查 Docker 是否运行
if ! docker info &> /dev/null; then
    echo -e "${RED}错误: Docker 未运行!${NC}"
    echo "请启动 Docker Desktop 或服务"
    exit 1
fi

echo -e "${GREEN}[1/6]${NC} Docker 检查通过"
echo ""

# 获取项目根目录
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_ROOT"

# 更新配置
echo -e "${GREEN}[2/6]${NC} 更新构建配置..."
mkdir -p .build/cache
cp -f app_default.config .build/cache/using.config
cp -f .build/cache/using.config TuyaOpen/
echo "    配置已更新：启用显示 + Xiaozhi UI"
echo ""

# 检查或构建镜像
echo -e "${GREEN}[3/6]${NC} 检查 Docker 镜像..."
if ! docker images | grep -q "ducky-builder"; then
    echo "    首次运行，构建 Docker 镜像（约 5-10 分钟）..."
    docker build -t ducky-builder:latest -f Dockerfile.build .
    if [ $? -ne 0 ]; then
        echo -e "${RED}镜像构建失败!${NC}"
        exit 1
    fi
else
    echo "    Docker 镜像已存在"
fi
echo ""

# 初始化子模块
echo -e "${GREEN}[4/6]${NC} 初始化子模块..."
git submodule update --init --recursive --depth 1
( cd TuyaOpen && git submodule update --init --recursive --depth 1 )
echo "    子模块初始化完成"
echo ""

# 开始构建
echo -e "${GREEN}[5/6]${NC} 开始构建固件（约 10-15 分钟）..."
echo ""

docker run --rm -it \
    -v "${PROJECT_ROOT}:/workspace" \
    -w /workspace \
    -e TUYA_PROJECT_DIR=/workspace \
    -e TUYA_APP_NAME=DuckyClaw \
    ducky-builder:latest \
    -c "
        set -e
        echo '============================================'
        echo '  DuckyClaw 固件构建开始'
        echo '============================================'
        echo ''

        # 安装 ARM 工具链
        echo '[1/5] 安装 ARM 工具链...'
        cd /workspace/TuyaOpen
        if [ ! -d 'platform/tools/gcc-arm-none-eabi-10.3-2021.10' ]; then
            mkdir -p platform/tools
            echo '    下载 ARM 工具链（约 100MB）...'
            wget -q --show-progress https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-rm/10.3-2021.10/gcc-arm-none-eabi-10.3-2021.10-x86_64-linux.tar.bz2
            echo '    解压中...'
            tar -xjf gcc-arm-none-eabi-10.3-2021.10-x86_64-linux.tar.bz2 -C platform/tools/
            rm gcc-arm-none-eabi-10.3-2021.10-x86_64-linux.tar.bz2
            echo '    ARM 工具链安装完成'
        else
            echo '    ARM 工具链已存在，跳过'
        fi

        # 准备环境
        echo ''
        echo '[2/5] 准备构建环境...'
        git config --global --add safe.directory '/workspace/TuyaOpen/platform/T5AI' 2>/dev/null || true
        export TUYA_TOOLCHAIN_PATH=/workspace/TuyaOpen/platform/tools/gcc-arm-none-eabi-10.3-2021.10
        export PATH=\"\$TUYA_TOOLCHAIN_PATH/bin:\$PATH\"

        # 复制配置
        echo ''
        echo '[3/5] 复制配置文件...'
        cp -f /workspace/.build/cache/using.config /workspace/TuyaOpen/
        mkdir -p /workspace/TuyaOpen/platform/T5AI/t5_os/include/base/include
        if [ -f /workspace/include/tuya_app_config.h ]; then
            cp /workspace/include/tuya_app_config.h /workspace/TuyaOpen/platform/T5AI/t5_os/include/base/include/tuya_iot_config.h
        fi

        # 编译
        echo ''
        echo '[4/5] 开始编译（约 5-10 分钟）...'
        echo ''
        cd /workspace/TuyaOpen/platform/T5AI/t5_os
        bash build.sh DuckyClaw 1.0.0 bk7258 /workspace build 2>&1 | tee /workspace/build.log || {
            echo ''
            echo '============================================'
            echo '  编译失败！查看 /workspace/build.log'
            echo '============================================'
            exit 1
        }

        echo ''
        echo '[5/5] 复制固件...'
        if [ -f build/bk7258/tuya_app/package/ua_file.bin ]; then
            cp build/bk7258/tuya_app/package/ua_file.bin /workspace/dist/DuckyClaw_Xiaozhi_UA.bin
            cp build/bk7258/tuya_app/package/all-app.bin /workspace/dist/DuckyClaw_Xiaozhi_QIO.bin
            echo '    固件已生成'
        fi

        echo ''
        echo '============================================'
        echo '  构建成功！'
        echo '============================================'
    "

BUILD_STATUS=$?

echo ""
echo -e "${GREEN}[6/6]${NC} 处理构建结果..."

if [ $BUILD_STATUS -eq 0 ] && [ -f "dist/DuckyClaw_Xiaozhi_UA.bin" ]; then
    echo ""
    echo -e "${GREEN}==============================================${NC}"
    echo -e "${GREEN}              构建成功！${NC}"
    echo -e "${GREEN}==============================================${NC}"
    echo ""
    echo "固件位置:"
    ls -lh dist/*.bin 2>/dev/null || true
    echo ""
    echo "烧录方法:"
    echo "  1. 打开 Tuya Uart Tool"
    echo "  2. 选择串口 (如 COM3)"
    echo "  3. 加载 dist/DuckyClaw_Xiaozhi_UA.bin"
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
    echo "请检查 build.log 文件中的错误信息"
    echo ""
    echo "常见问题:"
    echo "  1. 配置错误 - 检查 app_default.config"
    echo "  2. 内存不足 - 关闭其他程序"
    echo "  3. 网络问题 - 工具链下载失败"
    echo ""
    exit 1
fi
