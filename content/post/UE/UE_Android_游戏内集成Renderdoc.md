
---
title: "UE | Android游戏内集成Renderdoc"
date: 2026-07-29T22:55:47+08:00
draft: false
categories: [ "UE", "Mobile"]
isCJKLanguage: true
slug: "0cf171b5"
toc: true
mermaid: false
fancybox: false
blueprint: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
UEVersion: 5.5.4 
---

# 动机

在真机上调试抓帧总的来说有两个痛点。

1. `RenderDoc` 抓帧时经常因为各种原因断掉。比如公司的测试机 Type-C 口经过不知道多少人反复插拔早就松松垮垮的了，WiFi 调试也不稳定，AP一漫游就断了，`adb` 在弱网环境下容易丢包断连。

2. 条件抓取和部分抓取不好实现。内部抓取很容易做到满足某个条件时抓一帧，或者只抓某一帧的某个部分（如 `Basepass`），但外部抓取就很难做到。

## 做法

网上搜了一下，看见钱康来的博客已经记录过他们的探索了，至少这条路是行得通的。

[高版本安卓注入 RenderDoc | Loading & Learning](https://web.archive.org/web/20260301020712/https://qiankanglai.me/2023/02/12/renderdoc-android-inject/index.html)

我对 `GLES` 不感兴趣，所以反而要好做得多——毕竟 `GLES` 抓取需要 Hook 所有 `GL` API，而 `Vulkan` 有清晰的 `Loader` 和 `Layer` 概念。只需要做到操作：

1. 把 `libVkLayer_GLES_RenderDoc.so`打到包里去 
2. 在 `Vulkan` 的 `vkCreateInstance` 处把 `Layer` 加进去。

## libVkLayer_GLES_RenderDoc.so 在哪里

![UE_Android_游戏内集成Renderdoc-2026-07-29-23-15-28](https://img.blurredcode.com/img/UE_Android_游戏内集成Renderdoc-2026-07-29-23-15-28.png?x-oss-process=style/compress)

RenderDoc 的 APK 里就带有预编译好的库。

如何把它带到包里，可以参考 `Engine\Source\Programs\UnrealBuildTool\Platform\Android\UEDeployAndroid.cs` 中的 `CopyVulkanValidationLayers` 方法，沿着相关逻辑把 RenderDoc 的 layer 一并带进去即可。

## 如何加载 RenderDoc Layer

参考 `Engine\Source\Runtime\VulkanRHI\Private\VulkanLayers.cpp`，在 `-vulkandebug` 命令行参数下是如何加载 `VK_LAYER_KHRONOS_validation` 的，仿照该代码模式把 RenderDoc 的 Layer 加进去即可。RenderDoc 的 Layer 名为 `VK_LAYER_RENDERDOC_Capture`。

~~理论上如果在 `VulkanRHI` 运行前就已经执行好了 `dlopen`，这里的 loader 可以遍历到 RenderDoc 的 Layer。~~

更正一下，`Android`的 vulkan loader 具有自动发现功能，[7.1.4.2 Vulkan](https://source.android.com/docs/compatibility/8.0/android-8.0-cdd?hl=zh-cn#7_1_4_2_vulkan)。 任何进入被打到 APK 包里的`libVkLayer*.so`都能被 Android Vulkan Loader 自动发现，所以这里不用`dlopen`手动打开，从 Layer 机制加载就可以了。

## 如何执行游戏内抓取

可以自己根据 `renderdoc_app.h`（RenderDoc 预编译包里自带）封装 RenderDoc 的初始化和抓取，也可以利用虚幻自带的 RenderDoc 插件（位于 `Engine\Plugins\Developer\RenderDocPlugin`）。如果用虚幻的插件，需要进行一定的改造，因为它默认只支持桌面平台，要移植到 Android 端需要屏蔽一些代码并做适配。

如果集成改造了RenderDoc插件，默认保存到`Saved`目录，这样就内置抓取以后就可以拖下来回放了。并且也可以让AI Agent去自动抓取，配合上RenderDoc-mcp去自动debug..(做梦中
