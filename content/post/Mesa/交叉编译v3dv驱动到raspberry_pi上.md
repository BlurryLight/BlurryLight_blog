
---
title: "Mesa | 交叉编译v3dv驱动到raspberry pi5上"
date: 2026-01-25T18:58:24+08:00
draft: false
categories: [ "Mesa"]
isCJKLanguage: true
slug: "6ed1e1c5"
toc: true
mermaid: false
fancybox: false
blueprint: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
# UEVersion: 5.3.2 
---

**本文含有一定的AI润色** 

想要直接在Pi上编译v3dv也不是不行，target并不是很多，大约500多个c target，一会也就编完了。

直接编译的话可以参考 [Maíra Canal | Cross-Compiling CTS for the Raspberry Pi 4](https://mairacanal.github.io/cross-compiling-cts-rpi4/)

虽然Maíra Canal这篇博客的重点是交叉编译CTS(我的下一个难题...)

# Mesa的交叉编译准备

Build Machine: Ubuntu 2404 LTS (WSL2 x86_64)

![交叉编译v3dv驱动到raspberry_pi上-2026-01-25-19-08-42](https://img.blurredcode.com/img/交叉编译v3dv驱动到raspberry_pi上-2026-01-25-19-08-42.png?x-oss-process=style/compress)

Target Machine: Raspberry Pi OS (Debian 13 Trexie aarch64)

![交叉编译v3dv驱动到raspberry_pi上-2026-01-25-19-11-04](https://img.blurredcode.com/img/交叉编译v3dv驱动到raspberry_pi上-2026-01-25-19-11-04.png?x-oss-process=style/compress)





## 准备交叉编译环境
首先，在 WSL2 Ubuntu 中启用 `arm64` 架构并安装交叉编译器及依赖库。

```bash
# 启用 arm64 架构支持
sudo dpkg --add-architecture arm64
sudo apt update
```

注意 apt sourcelist的配置，ubuntu的其他架构的二进制不在默认的ubuntu源里，而是在ubuntu-ports源里，所以要在source list里指明不同架构的apt包去哪里找

![交叉编译v3dv驱动到raspberry_pi上-2026-01-25-19-13-18](https://img.blurredcode.com/img/交叉编译v3dv驱动到raspberry_pi上-2026-01-25-19-13-18.png?x-oss-process=style/compress)

```bash
# 安装交叉工具链和基础构建工具
sudo apt install crossbuild-essential-arm64 \
    python3-mako python3-yaml bison flex meson ninja-build libx11-xcb-dev libxcb-glx0-dev libxcb-randr0-dev libxcb-dri3-dev libdrm-dev libxcb-dri2-0-dev libxcb-dri3-dev libx11-dev libxext-dev libxdamage-dev libxshmfence-dev libxxf86vm-dev
 
# 安装针对 arm64 的目标依赖库
sudo apt install \
    libdrm-dev:arm64 \
    libx11-dev:arm64 \
    libwayland-dev:arm64 \
    libxshmfence-dev:arm64 \
    libexpat1-dev:arm64 \
    zlib1g-dev:arm64 \
    libxcb-dri3-dev:arm64 \
    libxcb-present-dev:arm64 \
    libxext-dev:arm64 \
    libxfixes-dev:arm64 \
    libxdamage-dev:arm64 \
	libxcb-randr0-dev:arm64 \
	libxcb-glx0-dev:arm64 \
    libx11-xcb-dev:arm64 \
	libxshmfence-dev:arm64 \
	libxcb-shm0-dev:arm64 \
	libxcb-dri3-dev:arm64 \
	libxrandr-dev:arm64 \
```


## 下载arm64版的vulkan sdk

[Releases · jakoch/vulkan-sdk-arm](https://github.com/jakoch/vulkan-sdk-arm/releases)

lunarg上只有windows arm的，linux arm的没有。v3dv编译的时候会读取一些vulkan sdk的库(具体而言，`libSPIR-*.a`的若干库文件)
找了半天github上有人预编译的有，解压出来放到`vulkan sdk`的地方

## 去除vulkan-sdk的pkg-config

linux正常安装的vulkan-sdk一般会让加载`setup-env.sh`

![交叉编译v3dv驱动到raspberry_pi上-2026-01-25-19-15-13](https://img.blurredcode.com/img/交叉编译v3dv驱动到raspberry_pi上-2026-01-25-19-15-13.png?x-oss-process=style/compress)

注意最后一行添加了`PKG_CONFIG_PATH`，这会导致交叉编译的时候pkg-config 错误搜索到x86-64的lib

运行`export PKG_CONFIG_PATH=""`把这个注释掉

## 创建 Meson 交叉编译配置文件
在 Mesa 源码根目录下创建一个名为 `cross_file_aarch64.txt` 的文件，填入以下内容：

**注意修改vulkan sdk的目录到你自己电脑的目录**。


```ini
[binaries]
c = 'aarch64-linux-gnu-gcc'
cpp = 'aarch64-linux-gnu-g++'
ar = 'aarch64-linux-gnu-gcc-ar'
strip = 'aarch64-linux-gnu-strip'
pkg-config = '/usr/bin/pkg-config'

[properties]
pkg_config_libdir = ['/home/panda/vulkansdk/1.4.328.1/aarch64/share/pkgconfig','/usr/lib/aarch64-linux-gnu/pkgconfig', '/usr/share/pkgconfig']

[host_machine]
system = 'linux'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'

```

## 配置 Meson 编译选项
执行以下命令进行配置。这里我们重点开启 `broadcom` Vulkan 驱动。

meson可能会报一堆依赖问题(ubuntu 2404的apt里带的meson太老了，这里最好用python的环境管理工具`pyenv/conda/uv`等工具重新创建一个新的纯洁python环境然后pip来把meson/mako/pyyaml等库装好)

```
pip3 install mako pyyaml
```

```bash
meson setup build-rpi5 \
  --cross-file cross_file_aarch64.txt \
  -Dprefix=~/rpi5_v3dv \
  -Dlibdir=lib/aarch64-linux-gnu \
  -Dbuildtype=release \
  -Dplatforms=x11,wayland \
  -Dvulkan-drivers=broadcom \
  -Dgallium-drivers=
```

这里我注释掉了gallium-drivers，因为我不需要gl驱动。

### 开始编译
使用 Ninja 进行编译：

```bash
ninja -C build-rpi5
ninja install # 把编译产物拷贝到~/rpi5_v3dv
```

### 提取编译产物
编译完成后，可以在以下位置找到关键文件：

- **Vulkan 驱动**: `build-rpi5/src/broadcom/vulkan/libvulkan_broadcom.so`
- **JSON 配置文件**: `build-rpi5/src/broadcom/vulkan/broadcom_icd.aarch64.json`

可以通过`rysnc`或者`sshfs`挂载等方式传输到树莓派


### 在树莓派上检验编译产物

```bash
vulkaninfo | grep "driverVersion"
	
# driverVersion     = 25.0.7 (104857607)  raspberry pi os自带的版本, debian 13

export VK_ICD_FILENAMES=/home/panda/rpi5_v3dv/share/vulkan/icd.d/broadcom_icd.aarch64.json
vulkaninfo | grep "driverVersion"
# driverVersion     = 25.3.4 (104869892) 自编译的版本

```

可以通过vkMark来跑分，

```bash
mesa 25.0.7 v3dv gpu 大概490分
mesa 25.0.7 llvmpipeline cpu 大概250分
mesa 25.3.4(自编译) v3dv  gpu 大概503分
```
