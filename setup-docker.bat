@echo off
chcp 65001 >nul
echo ==========================================
echo DuckyClaw Docker 构建脚本 - Windows
echo ==========================================
echo.

REM 检查管理员权限
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo 请以管理员身份运行此脚本！
    pause
    exit /b 1
)

REM 检查 Docker 是否安装
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [1/4] Docker 未安装，开始下载安装...
    echo.
    echo 正在下载 Docker Desktop...
    powershell -Command "& {Invoke-WebRequest -Uri 'https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe' -OutFile '%TEMP%\DockerDesktopInstaller.exe'}"

    echo 安装 Docker Desktop...
    start /wait %TEMP%\DockerDesktopInstaller.exe install --quiet

    echo.
    echo ==========================================
    echo Docker Desktop 已安装！
    echo 请重启电脑后再次运行此脚本。
    echo ==========================================
    pause
    exit /b 0
) else (
    echo [1/4] Docker 已安装，继续...
)

REM 检查 Docker 是否运行
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [2/4] 正在启动 Docker Desktop...
    start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    echo 等待 Docker 启动...
    timeout /t 30 /nobreak >nul
)

echo [2/4] Docker 正在运行，准备构建镜像...

REM 创建 Dockerfile
echo [3/4] 创建构建环境...

if not exist "TuyaOpen\Dockerfile.build" (
    echo 正在创建 Dockerfile.build...
    (
        echo FROM ubuntu:22.04
        echo.
        echo ENV DEBIAN_FRONTEND=noninteractive
        echo ENV TZ=Asia/Shanghai
        echo.
        echo RUN apt-get update ^&^& apt-get install -y --no-install-recommends ^\
        echo     wget git build-essential python3 python3-pip python3-venv ^\
        echo     cmake ninja-build ca-certificates ^\
        echo     ^&^& rm -rf /var/lib/apt/lists/*
        echo.
        echo RUN python3 -m pip install pyyaml kconfiglib
        echo.
        echo WORKDIR /workspace
        echo.
        echo ENTRYPOINT ["/bin/bash"]
    ) > TuyaOpen\Dockerfile.build
)

echo [4/4] 构建 Docker 镜像...
docker build -t ducky-builder:latest -f TuyaOpen\Dockerfile.build TuyaOpen\

if %errorlevel% neq 0 (
    echo 构建镜像失败！
    pause
    exit /b 1
)

echo.
echo ==========================================
echo Docker 环境准备完成！
echo ==========================================
echo.
echo 现在可以运行构建了：
echo.
echo   docker-build.bat
echo.
pause
