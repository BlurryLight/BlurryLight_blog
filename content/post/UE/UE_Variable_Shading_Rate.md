
---
title: "UE | Variable Shading Rate的定制和应用"
date: 2025-06-29T14:34:27+08:00
draft: false
categories: [ "UE"]
isCJKLanguage: true
slug: "491d0591"
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


虚幻从5.4以后提供了完整的VRS Tier2支持，并且在Nanite的场景下额外提供了对Nanite特定优化的Software Variable Shading Rate的支持。
具体可以见这篇博客的介绍
[Nanite-enabled Variable Rate Shading in Unreal Engine 5.4](https://blog.rime.red/variable-rate-shading-in-unreal-5/)

在Nanite场景下，Software的模式会更适合Nanite的渲染模式。

# Variable Rate Shading Tier1 / Tier2?

[Variable-rate shading (VRS) - Win32 apps | Microsoft Learn](https://learn.microsoft.com/en-us/windows/win32/direct3d12/vrs)

微软的文章可能是对VRS的来龙去脉，支持特性讲的最清楚的，由于这个特性是由硬件支持的，所以DX12的API也可以无缝迁移到其他API上。

另外一个可以参考的资料是`VK_KHR_fragment_shading_rate`的提案

[Vulkan-Docs/proposals/VK\_KHR\_fragment\_shading\_rate.adoc at main · KhronosGroup/Vulkan-Docs](https://github.com/KhronosGroup/Vulkan-Docs/blob/main/proposals/VK_KHR_fragment_shading_rate.adoc)

Tier1 / Tier2的主要区别:

![](https://learn.microsoft.com/en-us/windows/win32/direct3d12/images/tiers.png)


Tier1: 兼容性好，只支持Per-Draw设置
Tier2：更灵活，支持在屏幕空间设置和通过VertexShader / Geometry Shader输出一个值来控制Shading Rate，兼容性一般


# 硬件兼容性问题

| 硬件Vendor | Tier1                             | Tier2           |
| ---------- | --------------------------------- | --------------- |
| AMD        | 只支持到2x2                       | OK              |
| Nvidia     | 支持到4x4                         | OK              |
| Intel      | ?                                 | ?(没硬件来测试) |
| Mali[^1]   | From Mali G715(约2022年), max 4x4 | from Mali G715  |
| Adreno[^2] | From Adreno 660(约2021年)         | maybe 8Gen1?    |
| Apple      | A13(2019)                         | A13(2019)       |


PC / Console都没啥问题，Intel虽然没测试但是应该也是支持的很好的。
只需要注意AMD不支持2x2以上的VRS，Nvidia可以支持到4x4。


Mobile上Apple是跟进的最早的，很早就实现了Tier1 / Tier2的VRS支持。
高通最早是在888支持Tier1的VRS，从硬件上来看好像实现VRS Tier2也没啥阻碍。
只是一开始驱动没就位，很多888的手机都不支持VRS Tier2（vulkan报告VK_KHR_fragment_shading_rate这个扩展不存在)。
我找了一个8Gen1的手机测试就支持Tier2了。

mali支持VRS功能更晚一些，基本要到2022年的旗舰芯片才开始支持VRS，不过好在第一批支持的时候就已经Tier1 / Tier2就位了。

从2025年来看，现在新发的芯片，无论是移动端/Console对VRS的支持都没啥问题了。

# UE VRS的配置方案

PC当然毫不犹豫的使用 Tier1 + Tier2结合的方式即可。 如果不想做过多的改造，那么直接打开虚幻的VRS Tier2功能就可，虚幻提供了一个`FContrastAdaptiveImageGenerator`的算法来处理`Tier2 Shading Rate Image`的生成。


Mobile这里要斟酌一下了。因为基于上一帧的数据来计算Shading Rate Image，相当于要过一次Compute Shader的全屏后处理，这个开销不便宜。会极大的抵消VRS带来的性能提升。
Mobile这里还是要把Tier1的VRS用好，尽量依靠LOD系统来选择不同的Shading Rate。

借用一张高通的博客的图来看一下，远处的山脉都切换成了很低的Shading Rate

![UE_Variable_Shading_Rate-2025-06-29-15-30-23](https://img.blurredcode.com/img/UE_Variable_Shading_Rate-2025-06-29-15-30-23.png?x-oss-process=style/compress)


## 引擎改造: Per Material Instance Shading Rate

虚幻对VRS Tier1感觉没啥兴趣，连最基本的在MaterialInstance上覆盖Shading Rate的功能都没有提供。

这里可以参考Intel的文档提供的Unreal改造方案，
[Variable Rate Shading Tier 1 Usage Guide](https://www.intel.com/content/www/us/en/developer/articles/guide/variable-rate-shading-tier-1-usage-guide.html)

在材质面板上支持覆盖这个MI的Instance的Shading Rate。
![UE_Variable_Shading_Rate-2025-06-29-15-33-02](https://img.blurredcode.com/img/UE_Variable_Shading_Rate-2025-06-29-15-33-02.png?x-oss-process=style/compress)

然后根据Mesh的不同LOD选择不同的Material Instance，以支持不同LOD使用不同Shading Rate的功能。


## 引擎改造： Tier1 VRS Debug View

同理，虚幻也缺少一个Tier1 VRS的Debug View来查看当前的场景内的Shading Rate的功能。
虚幻的VRS DebugView功能只提供了Tier2的`Shading Rate Image`的可视化功能，Tier1的啥也看不到。
有人给虚幻提过PR，但是被无情拒绝了，可能epic的大哥们觉得VRS Tier1老掉牙了没啥好看的吧。

Mobile没人权也不是一天两天了。

[[UE5 Feature] DX12 shading rates viewmode by mamoniem · Pull Request #8113 · EpicGames/UnrealEngine](https://github.com/EpicGames/UnrealEngine/pull/8113)

可以参考这个PR合并一下。

# VRS的特殊情景下的处理

## PixelShader Modify Depth:
NV的文档里提了这种情况, 注意最后一行

[Advanced API Performance: Variable Rate Shading | NVIDIA Technical Blog](https://developer.nvidia.com/blog/advanced-api-performance-variable-rate-shading/)

Do not modify the output depth value from the pixel shader. If the pixel shader modifies depth, VRS is automatically disabled.

## Pixel Shader With Clip
这个虚幻的注释里留了一点线索。
如果VRS着色的像素clip了，会直接丢弃一个block的像素，造成肉眼可见的闪烁

```cpp
bool FMaterialResource::IsVariableRateShadingAllowed() const {
    return Material->bAllowVariableRateShading
        && !IsMasked()								// When using pixel discard, coarse shading causes the whole block to get discarded resulting in noticeable artifacts
        && !Material->HasCustomPrimitiveData()		// When using custom primitive data, Nanite can't determine which primitive ID to use for shading clusters
        && !Substrate::IsSubstrateEnabled();		// For now disable VRS when Substrate is enabled due to incorrect data replication between neighbor pixels
}
```

虚幻默认检查到一个材质是Masked的时候，会直接无视VRS的设置。


## Pixel Shader Writes UAV

这个是项目里有个特性用到了这个功能，试验了一下，和VRS不太兼容。被复制的周围的像素不会写UAV。
会造成后续Shader读UAV的数据的时候读到没被初始化的值造成逻辑上的问题
没啥好的解决方案，只能禁用了


# Reference 

[^1]: [Mali GPU sheet](https://developer.arm.com/documentation/102540/0808/Mali-GPU-datasheet)
[^2]: [Variable Rate Shading Has Arrived on Mobile with Impressive Results](https://www.qualcomm.com/developer/blog/2021/07/variable-rate-shading-has-arrived-mobile-impressive-results)