
---
title: "UE | 关于Vulkan下Occlusion Query存在竞态条件导致崩溃的问题"
date: 2026-10-07T14:24:05+08:00
draft: false
categories: [ "UE"]
isCJKLanguage: true
slug: "e0262aa1"
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


UDN里也有类似的报告，如果启用了Vulkan Occlusion Query在UE5很容易触发崩溃，崩溃堆栈不固定。

[[Android] GPU hang or crash in FVulkanOcclusionQueryPool - Development / Rendering - Epic Developer Community Forums](https://forums.unrealengine.com/t/android-gpu-hang-or-crash-in-fvulkanocclusionquerypool/2689495)

# Occlusion Feedback or Occlusion Query?

堡垒之夜已经基本全部迁移到UE自研的Occlusion Feedback了，原理是`Pixel Shader write UAV`，只要有一个Pixel写过UAV就可以判定这个Object没有被遮挡，比较巧妙的办法。所以Occlusion Query的代码可能维护的比较少了。

最近也是想研究下Adreno的OC的fast mode(这个后面写个笔记吧，需要从UE5.6 port一部分代码)，所以启用了Occlusion Query以后就一直崩溃...

使用Occlusion Feedback不会碰见这个问题。

# Race Condition

由于崩溃堆栈不固定 + 崩溃的时候看到的数据是乱的，自然往race condition的方向去想。

经过研究，发现Vulkan Query和Query Pool相关的函数都是裸奔，实际上是这里有一系列的成员变量都可能在RHI线程和Render线程读取和修改的。

比如 Pool下面有记录一些`（AllocatedQueries / AcquiredIndices / NumUsedQueries）`这些关键的变量，和`Query`结构体也有一些关键的`State/Pool/IndexInPool`等变量。

当渲染线程在获取Query结果时`RHIGetRenderQueryResult()`, 却可能修改Pool和Query自身的状态

```cpp

bool FVulkanDynamicRHI::RHIGetRenderQueryResult(FRHIRenderQuery* QueryRHI, uint64& OutNumPixels, bool bWait, uint32 GPUIndex)
{
// ...
		if (Query->Pool->TryGetResults(bWait)) // 在渲染线程却修改了Query和 Pool的结构
		{
			Query->Result = Query->Pool->GetResultValue(Query->IndexInPool);
			Query->ReleaseFromPool(); // 注意这里会修改Query内部数据以及Query Pool的内部数据
			Query->State = FVulkanOcclusionQuery::EState::RT_GotResults;
			OutNumPixels = Query->Result;
			return true;
		}
```

而RHI线程内，`FlushAllocatedQueries`等API也会去读取和修改`Query`以及`Query Pool`内部的数据结构，这是典型的一个竞态条件，读到什么值都有可能。

# 修复方案

由于RHI线程和RenderThread并不是竞争很激烈的线程，一个可行的方案是给`Query Pool`和`Query`两个结构都添加成员变量的锁。
注意要防止死锁的话，有部分代码需要调整，有些代码可能会同时修改`Query`以及`Query`所在的Pool的数据结构，所以可以始终按照`Query->QueryPool`两级加锁的结构来，不然很容易加锁顺序不固定导致死锁。