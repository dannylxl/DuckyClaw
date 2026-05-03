@echo off
chcp 65001 >nul
echo ==========================================
echo DuckyClaw 固件 Docker 构建脚本
echo ==========================================
echo.

REM 检查 Docker 是否运行
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] Docker 未运行！请先启动 Docker Desktop。
    echo.
    echo 按任意键打开 Docker Desktop...
    pause
    start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    exit /b 1
)

REM 确保使用最新的配置
echo [1/5] 更新构建配置...
if not exist ".build\cache" mkdir .build\cache
copy /Y app_default.config .build\cache\using.config >nul
copy /Y .build\cache\using.config TuyaOpen\ >nul
echo      配置已更新：启用显示 + Xiaozhi UI
echo.

echo [2/5] 准备 Docker 构建环境...

REM 检查镜像是否存在
docker images | findstr "ducky-builder" >nul
if %errorlevel% neq 0 (
    echo      首次运行，需要构建 Docker 镜像（约 5-10 分钟）...
    echo.
    docker build -t ducky-builder:latest -f TuyaOpen\Dockerfile.build TuyaOpen\
    if %errorlevel% neq 0 (
        echo [错误] Docker 镜像构建失败！
        pause
        exit /b 1
    )
) else (
    echo      Docker 镜像已存在
)
echo.

echo [3/5] 初始化子模块...
git submodule update --init --recursive
cd TuyaOpen
git submodule update --init --recursive
cd ..
echo      子模块初始化完成
echo.

echo [4/5] 开始构建固件（约 10-15 分钟）...
echo      这会挂载当前目录到 Docker 容器中编译
echo.

REM 运行 Docker 构建
docker run --rm -it ^
    -v "%cd%:/workspace" ^
    -w /workspace ^
    -e TUYA_PROJECT_DIR=/workspace ^
    -e TUYA_APP_NAME=DuckyClaw ^
    ducky-builder:latest ^
    -c "
        echo '============================================' && \
        echo '  DuckyClaw 固件构建开始' && \
        echo '============================================' && \
        echo '' && \
        echo '[1/4] 安装 ARM 工具链...' && \
        cd /workspace/TuyaOpen && \
        if [ ! -d 'platform/tools/gcc-arm-none-eabi-10.3-2021.10' ]; then \
            mkdir -p platform/tools && \
            wget -q https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-rm/10.3-2021.10/gcc-arm-none-eabi-10.3-2021.10-x86_64-linux.tar.bz2 && \
            tar -xjf gcc-arm-none-eabi-10.3-2021.10-x86_64-linux.tar.bz2 -C platform/tools/ && \
            rm gcc-arm-none-eabi-10.3-2021.10-x86_64-linux.tar.bz2 && \
            echo 'ARM 工具链安装完成'; \
        else \
            echo 'ARM 工具链已存在，跳过下载'; \
        fi && \
        echo '' && \
        echo '[2/4] 准备构建环境...' && \
        git config --global --add safe.directory \"/workspace/TuyaOpen/platform/T5AI\" 2>/dev/null || true && \
        export TUYA_TOOLCHAIN_PATH=/workspace/TuyaOpen/platform/tools/gcc-arm-none-eabi-10.3-2021.10 && \
        export PATH=\"\$TUYA_TOOLCHAIN_PATH/bin:\$PATH\" && \
        echo '' && \
        echo '[3/4] 复制配置文件...' && \
        cp -f /workspace/.build/cache/using.config /workspace/TuyaOpen/ && \
        mkdir -p /workspace/TuyaOpen/platform/T5AI/t5_os/include/base/include && \
        cp /workspace/include/tuya_app_config.h /workspace/TuyaOpen/platform/T5AI/t5_os/include/base/include/tuya_iot_config.h 2>/dev/null || echo '注意: tuya_app_config.h 不存在，使用默认配置' && \
        echo '' && \
        echo '[4/4] 开始编译...' && \
        cd /workspace/TuyaOpen/platform/T5AI/t5_os && \
        bash build.sh DuckyClaw 1.0.0 bk7258 /workspace build 2>&1 | tee /workspace/build.log && \
        echo '' && \
        echo '============================================' && \
        echo '  构建完成！' && \
        echo '============================================' && \
        echo '' && \
        ls -lh build/bk7258/tuya_app/package/*.bin 2>/dev/null || echo '检查 build 目录...'
    "

echo.
echo [5/5] 复制固件到输出目录...

REM 复制固件到 dist 目录
if exist "TuyaOpen\platform\T5AI\t5_os\build\bk7258\tuya_app\package\ua_file.bin" (
    if not exist "dist" mkdir dist
    copy /Y "TuyaOpen\platform\T5AI\t5_os\build\bk7258\tuya_app\package\ua_file.bin" "dist\DuckyClaw_Xiaozhi_UA.bin" >nul
    copy /Y "TuyaOpen\platform\T5AI\t5_os\build\bk7258\tuya_app\package\all-app.bin" "dist\DuckyClaw_Xiaozhi_QIO.bin" >nul
    echo      固件已复制到 dist 目录：
    echo        - DuckyClaw_Xiaozhi_UA.bin  (用于烧录)
    echo        - DuckyClaw_Xiaozhi_QIO.bin
    echo.
    echo ==========================================
    echo 构建成功！
    echo ==========================================
    echo.
    echo 烧录方法：
    echo   1. 打开 Tuya Uart Tool
    echo   2. 选择串口（波特率 921600 或 115200）
    echo   3. 加载 dist\DuckyClaw_Xiaozhi_UA.bin
    echo   4. 点击烧录
    echo.
    echo 查看日志：波特率 460800
    echo ==========================================
) else (
    echo [错误] 固件生成失败！
    echo.
    echo 请检查：
    echo   1. build.log 文件中的错误信息
    echo   2. 配置是否正确
    echo.
)

pause
