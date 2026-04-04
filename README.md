# FTNN `.deb` 去发行版限制补丁脚本

[English README](./README.en.md)

## 背景

`FTNN_desktop_16.9.15408_amd64.deb` 的安装前脚本 `preinst` 内置了 Ubuntu 版本判断。

本文档里还补充记录了一个后续版本样例：

- 官方下载地址：`https://softwaredownload.futustatic.com/FTNN_desktop_16.10.15508_amd64.deb`
- 包版本：`16.10.15508`
- 本地下载文件：`FTNN_desktop_16.10.15508_amd64.deb`

官方说明写的是：

`deb (适用于 Ubuntu 18.04+ GNOME / KDE 环境)`

它会读取 `/etc/lsb-release` 或 `/etc/os-release` 中的 `VERSION_ID`，然后直接拿这个版本号和 `1804` 比较，并在版本低于 `18.04` 时拒绝安装，报错大意为：

`This package requires Ubuntu version 18.04 or later.`

这段逻辑的问题是：

1. 它默认把当前系统当作 Ubuntu 处理。
2. 它没有先判断发行版是否真的是 Ubuntu。
3. 在 Debian 13 这类非 Ubuntu 系统上，`VERSION_ID=13`，会被错误判定为低于 `18.04`，从而无法安装。

下面是本机 `cat /etc/os-release` 的实际内容，可直接看出这是 Debian 13，而不是 Ubuntu：

```sh
PRETTY_NAME="Debian GNU/Linux 13 (trixie)"
NAME="Debian GNU/Linux"
VERSION_ID="13"
VERSION="13 (trixie)"
VERSION_CODENAME=trixie
DEBIAN_VERSION_FULL=13.3
ID=debian
HOME_URL="https://www.debian.org/"
SUPPORT_URL="https://www.debian.org/support"
BUG_REPORT_URL="https://bugs.debian.org/"
```

也正因为 `VERSION_ID="13"`，原脚本会把它拿去和 `1804` 做数值比较，最终导致误判。

## 解决思路

这两个脚本会自动：

1. 解包 `.deb` 的控制信息和数据内容。
2. 修改 `preinst` 中的系统版本检查逻辑。
3. 让脚本仅在 `ID=ubuntu` 时继续执行 `>= 18.04` 的判断。
4. 在 Debian 等非 Ubuntu 系统上跳过这条 Ubuntu 专属限制。
5. 重新打包生成一个新的补丁版 `.deb`。

## 适用范围

- 适用于同类 FTNN 桌面版 `.deb` 包。
- 主要处理“错误地要求 Ubuntu 18.04+”这一安装阶段限制。
- 官方声明的目标环境仍然是 `Ubuntu 18.04+ GNOME / KDE`，本项目只是移除安装阶段对非 Ubuntu 发行版的硬拦截。
- 不保证解决运行阶段的动态库、显卡、沙箱、桌面环境兼容性问题。

## 依赖

### Bash 脚本

- `bash`
- `dpkg-deb`
- `realpath`

### Python 脚本

- `python3`
- `dpkg-deb`

## 文件说明

- `patch_ftnn_deb.sh`: Bash 版本
- `patch_ftnn_deb.py`: Python 版本

## 已知样例包

`FTNN_desktop_16.10.15508_amd64.deb` 的官方下载：

```bash
curl -fL --progress-bar -o ./FTNN_desktop.deb \
  https://softwaredownload.futustatic.com/FTNN_desktop_16.10.15508_amd64.deb
```

如果后续继续验证新版本，建议把下载地址和包版本按同样格式追加到这里。

## 用法

### Bash

```bash
cd /path/to/your/workdir
chmod +x ./patch_ftnn_deb.sh
./patch_ftnn_deb.sh FTNN_desktop.deb
```

指定输出文件名：

```bash
./patch_ftnn_deb.sh FTNN_desktop.deb FTNN_desktop_patched.deb
```

### Python

```bash
cd /path/to/your/workdir
chmod +x ./patch_ftnn_deb.py
./patch_ftnn_deb.py FTNN_desktop.deb
```

指定输出文件名：

```bash
./patch_ftnn_deb.py FTNN_desktop.deb FTNN_desktop_patched.deb
```

## 输出规则

如果不手动指定输出路径，默认会在原始 `.deb` 同目录下生成：

```text
原文件名_patched.deb
```

例如：

```text
FTNN_desktop_16.9.15408_amd64.deb
-> FTNN_desktop_16.9.15408_amd64_patched.deb
```

## 安装示例

生成补丁包后，可直接安装：

```bash
sudo apt install ./FTNN_desktop_16.9.15408_amd64_patched.deb
```

## 限制说明

1. 这不是“移植到 Debian”的完整兼容层，只是去掉错误的 Ubuntu 发行版拦截。
2. 如果后续版本的 `preinst` 结构变化很大，脚本中的文本替换规则可能需要调整。
3. 厂商官方支持范围仍是 `Ubuntu 18.04+ GNOME / KDE`，因此在 Debian 13 上即使能安装，也仍可能遇到未覆盖的兼容性问题。

## 验证建议

补丁完成后，可以先查看控制脚本是否已包含如下日志逻辑：

```text
Non-Ubuntu system detected (...)
```

这说明安装前脚本已经改为：

- Ubuntu: 继续要求 `18.04+`
- Debian 等非 Ubuntu: 跳过这条限制
