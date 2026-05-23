
---
title: "UE | 在部分机器上 Dev 包明显出现 RHI Thread 性能劣化的问题"
date: 2026-05-23T12:48:06+08:00
draft: false
categories: ["UE"]
isCJKLanguage: true
slug: "7e7e4b87"
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

受影响版本：`5.4.3` 及之后的版本。

其实 `Epic` 的 `PR` 里已经有人发现这个问题了。

- [Added a hotfix for Vulkan draw markers and drastically improved performance on low-end Android devices in dev builds by Adlerkampf · Pull Request #12541 · EpicGames/UnrealEngine](https://github.com/EpicGames/UnrealEngine/pull/12541)
- [Update VulkanLayers.cpp : Fix Android Vulkan Performance by residentour · Pull Request #12361 · EpicGames/UnrealEngine](https://github.com/EpicGames/UnrealEngine/pull/12361/changes)

任意合并一个都可以修复这个问题，不清楚为什么 `Epic` 都拒绝合并。

# 问题的原因

从 `5.4.3` 开始，`UE` 默认在 `DEBUG/Development` 包里启用了 `Draw Marker` 功能：

```
#define VULKAN_SHOULD_ENABLE_DRAW_MARKERS (UE_BUILD_DEVELOPMENT || UE_BUILD_DEBUG)
bool bVulkanEnableDrawMarkers = VULKAN_ENABLE_DRAW_MARKERS;
```

这个功能本质上是依托 `VK_EXT_debug_utils` 扩展实现的，它会给所有的 `Vulkan` 对象添加调试信息，方便排查问题。

## 5.4.3 Hot Fix

`UE` 很快也意识到这个提交会造成巨大的性能问题，于是在 `5.4.3` 紧急发了一个 `hotfix` 试图修复它。但这个补丁只能算是半成品：虽然在没有显式传入 `-forcevulkandrawmarkers` 参数时不再打标记了，但它之前仍然会加载 `VK_EXT_debug_utils` 扩展，这依然可能引入其他性能问题。

- [VulkanRHI: Disable draw markers and vulkan debug names until crashes … · EpicGames/UnrealEngine@857f774](https://github.com/EpicGames/UnrealEngine/commit/857f7740b9845181a713b7043ae4bc7b3915a34c#diff-4d2cbecf488598c875966725c88e0cca06fb044f490d4ba39715df6546c16ff9R25)


# 部分机器上的性能劣化问题

我当前的测试工程版本是 `5.5.4`。在理论算力相近的芯片上，某台测试机的性能会明显慢于另外一个机器。

通过 `stat unit` 之类的简单测试可以发现，瓶颈不在 `GPU`，而在 `RHI Thread`。于是我又用`simpleperf`抓了一份热力图，分析后发现：绝大多数调用最终竟然都进入了 `validation layer`(紫色部分为搜索`validation`关键词的堆栈)

![UE_在部分机器上Dev包明显出现性能劣化的问题-2026-05-23-13-20-17](https://img.blurredcode.com/img/UE_在mali机器上Dev包明显出现性能劣化的问题-2026-05-23-13-20-17.png?x-oss-process=style/compress)


## 加载 `validation layer` 的原因


部分系统的图形驱动不提供 `VK_EXT_debug_utils` 扩展，但前面提到过，`UE` 会在 `Dev` 包里尝试启用它。

在Android的打包脚本里，默认的`Dev` 包里还会附带一个 `VK_LAYER_KHRONOS_validation` 的 `layer`。

接着 `UE` 会发现，第一个提供这个扩展的 `layer` 正好就是验证层，于是就把验证层悄悄启动了。

![UE_在部分机器上Dev包明显出现性能劣化的问题-2026-05-23-13-32-37](https://img.blurredcode.com/img/UE_在部分机器上Dev包明显出现性能劣化的问题-2026-05-23-13-32-37.png?x-oss-process=style/compress)

## 为什么MacOS模拟器不会有这个问题

验证后发现，`MoltenVK` 原生支持 `VK_EXT_debug_utils`，不需要回退到验证层 `layer` 上。



## 代码分析(Codex整理)
源码链路：

- `Engine/Source/Runtime/VulkanRHI/Private/Android/VulkanAndroidPlatform.h:11`
  - `#define VULKAN_SHOULD_ENABLE_DRAW_MARKERS (UE_BUILD_DEVELOPMENT || UE_BUILD_DEBUG)`
- `Engine/Source/Runtime/VulkanRHI/Private/VulkanLayers.cpp:416`
  - 会因为 `draw markers` 的设置而开启 `bForceDebugUtils`
- `Engine/Source/Runtime/VulkanRHI/Private/VulkanLayers.cpp:443`
  - 如果 `VK_EXT_debug_utils` 不是由裸驱动直接支持，而是由某个 `layer` 提供，就会把这个 `layer` 加进去
- 这台设备上的 `VK_EXT_debug_utils` 正好是由 `VK_LAYER_KHRONOS_validation` 提供的，所以它被加载了

结论：这次问题是 `Android Development` 包里的 `VULKAN_SHOULD_ENABLE_DRAW_MARKERS` 导致的，不是 `r.Vulkan.EnableValidation`，也不是命令行里的 `validation` 参数。要根治的话，要么让 `Android Development` 不再默认开启 `VULKAN_SHOULD_ENABLE_DRAW_MARKERS`，要么修改 `ActivateDebuggingExtension(VK_EXT_debug_utils)` 这段逻辑，避免为了 `debug utils` 把 `Khronos validation layer` 拉起来。
