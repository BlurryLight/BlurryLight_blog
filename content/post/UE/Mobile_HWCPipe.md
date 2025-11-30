
---
title: "Mobile | 集成HWCPipe(libGPUCounter)来监测性能"
date: 2025-11-30T06:58:39Z
draft: false
categories: [ "UE"]
isCJKLanguage: true
slug: "9f36f844"
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


最近在抓移动端的数据的时候还是经常感觉到一些痛点，尤其是虚幻在移动端分析性能的工具比较欠缺，主要还是要依靠厂商提供的工具和SDK。
项目组有钱的话可以考虑接入UWA或者Perfdog，节约很多事情，没钱就得自立更生了..

不过UWA和Perfdog也有一些问题就是数据必须得传到他们自己的网站看，没法在游戏内实时看。有的时候在游戏内想调cvar来看性能指标的变化就不太方便了，只能录下来再对比。

Arm Streamline(对应mali芯片)倒是提供了比较方便的实时分析工具，只要用Arm Streamline启动应用，会绘制实时数据的采集图片(带宽需要结束trace以后才能分析数据)，Snapdragon Profiler 有个realtime模式也可以做到这个。


# 游戏内集成内录工具

如果想要做一些性能统计或者脚本化抓取的功能，最好还是有一个游戏内录工具比较好。
比如战斗开始前录制，战斗结束后停止录制，用厂商的工具就比较难做到了，只能先录制一整段，后期再手动截取一段数据。

## Mali: libGPUCounter
考察了一下现有的工具发现Arm的GPUCounters数据是开源的，再饭
[ARM-software/libGPUCounters: A utility library for application developers to sample Arm Immortalis GPU or Arm Mali GPU performance counters.](https://github.com/ARM-software/libGPUCounters)

Vulkan的官方示例Vulkan-Samples里有样板代码展现了怎么接这个库，直接Copy就行。 注意虚幻**曾经**接过HWCPipe这个库，但是很古老已经没人维护了(2019年左右接的)，试了下最新的芯片直接不认识了。只能自己在项目插件里再另起一套了。

另外Copy Vulkan示例代码的时候顺便发现他们带宽统计的代码是错的，顺手提了个bug..

[HWCPipeStatsProvider provides misleading performance data · Issue #1427 · KhronosGroup/Vulkan-Samples](https://github.com/KhronosGroup/Vulkan-Samples/issues/1427)


注意每次采集都是采集瞬间的GPU数据，所以为了得到准确的数据，想了下最好是后台拉一个FRunnableThread定时采集一下GPUCounters的数据，这样就没有帧的概念了，可以定时采集每帧不同pass平均后的数据。


## 高通: Freedreno

高通的GPUCounters是不开源的，只能用它家自己的工具采集。但是有人去逆向他们的驱动形成了Mesa Freedreno驱动，在freedreno支持的GPU里基本从源码里翻到每个寄存器的定义。

下面这里有大神给了一个示例代码如何采集Adreno的Counters，有兴趣的朋友可以翻一下这个人的博客，还有一些额外的信息。
[Adreno Perf Counter Queries](https://gist.github.com/antiagainst/fa15bad3d024f6520786863aa4ec05ab)
