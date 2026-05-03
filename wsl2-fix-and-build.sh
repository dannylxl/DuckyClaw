#!/bin/bash
# WSL2 快速修复脚本

echo "=============================================="
echo "  DuckyClaw WSL2 快速修复"
echo "=============================================="
echo ""

cd /mnt/e/TuyaOpen/DuckyClaw/TuyaOpen/platform/T5AI/t5_os

# 修复所有换行符问题
echo "[1/3] 修复换行符..."
find . -type f \( -name '*.sh' -o -name '*.py' \) -exec sed -i 's/\r$//' {} + 2>/dev/null
echo "    完成"

# 设置环境
echo "[2/3] 设置环境..."
export TUYA_PROJECT_DIR=/mnt/e/TuyaOpen/DuckyClaw
export TUYA_APP_NAME=DuckyClaw
export TUYA_TOOLCHAIN_PATH=/mnt/e/TuyaOpen/DuckyClaw/TuyaOpen/platform/tools/gcc-arm-none-eabi-10.3-2021.10
export PATH="$TUYA_TOOLCHAIN_PATH/bin:$PATH"

# 复制配置
cp -f /mnt/e/TuyaOpen/DuckyClaw/.build/cache/using.config /mnt/e/TuyaOpen/DuckyClaw/TuyaOpen/
mkdir -p include/base/include
if [ -f /mnt/e/TuyaOpen/DuckyClaw/include/tuya_app_config.h ]; then
    cp /mnt/e/TuyaOpen/DuckyClaw/include/tuya_app_config.h include/base/include/tuya_iot_config.h
fi
echo "    完成"

# 构建
echo "[3/3] 开始构建（约 10-15 分钟）..."
echo ""
make bk7258 2>&1 | tee /mnt/e/TuyaOpen/DuckyClaw/build.log

# 复制固件
if [ -f "build/bk7258/tuya_app/package/ua_file.bin" ]; then
    cp build/bk7258/tuya_app/package/ua_file.bin /mnt/e/TuyaOpen/DuckyClaw/dist/DuckyClaw_Xiaozhi_UA.bin
    cp build/bk7258/tuya_app/package/all-app.bin /mnt/e/TuyaOpen/DuckyClaw/dist/DuckyClaw_Xiaozhi_QIO.bin
    echo ""
    echo "✅ 构建成功！"
    ls -lh /mnt/e/TuyaOpen/DuckyClaw/dist/*.bin
else
    echo ""
    echo "❌ 构建失败，请查看 build.log"
fi
