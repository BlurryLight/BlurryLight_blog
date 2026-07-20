
---
title: "UE_Vulkan_TimeStampQuery计时和一个竞态条件的bug"
date: 2026-07-20T22:25:45+08:00
draft: false
categories: [ "UE"]
isCJKLanguage: true
slug: "8bb7b105"
toc: true
mermaid: false
fancybox: false
blueprint: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
---


{{% spoiler "笔记栏文章声明"%}} 
    {{% notice warning %}}
    笔记栏所记录文章往往未经校对，或包含错误认识或偏颇观点，亦或采用只有自身能够理解的记录。
    {{% /notice %}}
{{% /spoiler %}}

{{% notice info %}}
    Engine Version: 4.26.2
{{% /notice %}}


# FRealtimeGPUProfiler / FVulkanGPUTiming / FVulkanGPUProfiler

虚幻引擎有三套计时代码，职责混在一起，梳理如下：

- FVulkanGPUTiming：底层的 Primitive，一些引擎功能依赖它计时
- FVulkanGPUProfiler：只用来响应 `ProfileGPU` 命令的 GPU Profiler
- FRealtimeGPUProfiler：最新的一套，拥有 stat / insights 数据写入等功能，但 query 的管理是依靠自己调用 RHI 底层接口来管理，是 RHI 层上面的东西，与 Vulkan 平台无关



# FVulkan GPU Timing

E:\ue\Engine\Source\Runtime\VulkanRHI\Private\VulkanGPUProfiler.h
```
class FVulkanGPUTiming : public FGPUTiming
{
public
```

`FVulkanGPUTiming` 的初始化点有好几个，它不是一个单例，任何需要的地方都可以 new 一个来测量时间，只要给它一个 cmdlist 和 pool size。
引擎默认会在 Immediate Context 里 new 一个。


```cpp
FVulkanCommandListContext::FVulkanCommandListContext(FVulkanDynamicRHI* InRHI, FVulkanDevice* InDevice, FVulkanQueue* InQueue, FVulkanCommandListContext* InImmediate)
	: RHI(InRHI)
	, Immediate(InImmediate)
	, Device(InDevice)
	, Queue(InQueue)
	, bSubmitAtNextSafePoint(false)
	, CommandBufferManager(nullptr)
	, PendingGfxState(nullptr)
	, PendingComputeState(nullptr)
	, FrameCounter(0)
#if (RHI_NEW_GPU_PROFILER == 0)
	, GpuProfiler(this, InDevice)
#endif
{
#if (RHI_NEW_GPU_PROFILER == 0)
	FrameTiming = new FVulkanGPUTiming(this, InDevice);
#endif

#if (RHI_NEW_GPU_PROFILER == 0)
	FrameTiming->Initialize();
#endif
```

Immediate Context 的这个 GPU Timing 基本只在 `FVulkanCommandListContext::RHIEndDrawingViewport` 的时候调用

```
FVulkanGPUTiming::StartTiming(FVulkanCmdBuffer *) VulkanUtil.cpp:111
[内联] FVulkanCommandListContext::WriteBeginTimestamp(FVulkanCmdBuffer *) VulkanQuery.cpp:654
FVulkanCommandListContext::RHIEndDrawingViewport(FRHIViewport *, bool, bool) VulkanRHI.cpp:1255
FRHICommand::ExecuteAndDestruct(FRHICommandListBase &) RHICommandList.h:1471
FRHICommandListBase::Execute() RHICommandList.cpp:429
FRHICommandListExecutor::FTranslateState::Translate(FRHICommandListBase *) RHICommandList.cpp:902
FRHICommandListExecutor::FSubmitState::Dispatch'::`19'::<lambda_1>::operator()() RHICommandList.cpp:871
```


记录这一帧的总耗时
![edit-9dbc97d7ce9247d3a4412efb1257d09d-2026-04-21-11-34-16](https://img.blurredcode.com/img/edit-9dbc97d7ce9247d3a4412efb1257d09d-2026-04-21-11-34-16.png?x-oss-process=style/compress)


最后数据被写入 `GGPUFrameTime` 作为 GPU 耗时，统计的是上一次 `EndDrawViewport` 和这一次 `EndDrawViewport` 之间的耗时。
```c
void FVulkanCommandListContext::ReadAndCalculateGPUFrameTime()
{
	check(IsImmediate());

	if (GSupportsTimestampRenderQueries && FrameTiming)
	{
		uint64 Delta = 0;
		
		// If we support profile command buffers then use this timing for GPU
		if (GVulkanUseCmdBufferTimingForGPUTime)
		{
			Delta = CommandBufferManager->CalculateGPUTime();
		}
		else
		{
			Delta = FrameTiming->GetTiming(false);
		}
	
		const double SecondsPerCycle = FPlatformTime::GetSecondsPerCycle();
		const double Frequency = double(FVulkanGPUTiming::GetTimingFrequency());
		GGPUFrameTime = FMath::TruncToInt(double(Delta) / Frequency / SecondsPerCycle);
	}
	else if(!FVulkanPlatform::HasCustomFrameTiming())
	{
		GGPUFrameTime = 0;
	}
}
```


## FVulkanGPUTiming被用到的地方

### 1. 用来计算GPU Time
```
① FVulkanCommandListContext::FrameTiming — 全局帧计时
VulkanContext.h:289 / VulkanRHI.cpp:447
每个 FVulkanCommandListContext（ImmediateContext）有一个 FrameTiming，在构造时创建、析构时销毁：
FVulkanRHI.cpp:447  → new FVulkanGPUTiming(this, InDevice)
               :455  → FrameTiming->Initialize()           // PoolSize = 8 (默认)
VulkanQuery.cpp:654  → FrameTiming->StartTiming(CmdBuffer) // WriteBeginTimestamp
               :661  → FrameTiming->EndTiming(CmdBuffer)   // WriteEndTimestamp(写入时间戳)
               :405  → FrameTiming->GetTiming(false)       // ReadAndCalculateGPUFrameTime
用途：计算 GGPUFrameTime（每帧的 GPU 总耗时）。（引擎用来计算SM5 Vulkan的GPUTime的时间）
```

### 2. 并行的 CommandList 内部独立计时

```
② FVulkanCmdBuffer::Timing — 每个 Command Buffer 的独立计时
VulkanCommandBuffer.h:247 / VulkanCommandBuffer.cpp:277
按 cmd buffer 类型决定 PoolSize：
CmdBuffer 类型	    PoolSize	触发条件
普通	            32	    GVulkanProfileCmdBuffers 或 GVulkanUseCmdBufferTimingForGPUTime
Upload Only	    256	    同上
Timing = new FVulkanGPUTiming(InContext, Device);
Timing->Initialize(PoolSize);  // 32 或 256
```
用途：
- CalculateGPUTime() 遍历所有 cmd buffer，累加 Timing->GetTiming() → 用于 r.Vulkan.UseCmdBufferTimingForGPUTime 模式下的 GGPUFrameTime
- 每个 cmd buffer 的 StartTiming/EndTiming 在其生命周期中被调用

满足特定条件的 CVar 开启时，会给每个 command list 计时，用所有 CommandList 累计的时间作为 GPU Time。
```cpp
	if (GVulkanProfileCmdBuffers || GVulkanUseCmdBufferTimingForGPUTime)
	{
		InitializeTimings(CommandBufferPool->GetMgr().GetCommandListContext());
#if (RHI_NEW_GPU_PROFILER == 0)
		if (Timing)
		{
			Timing->StartTiming(this);
		}
#endif
	}
```

### 3. FVulkanGPUProfiler 的处理

FVulkanGPUProfiler：只用来响应 `ProfileGPU` 命令的 GPU Profiler，输入 `ProfileGPU` 的时候会调用这个。

这是个 breadcrumb 式的计时，每个 node 节点会初始化一个 FVulkanGPUTiming，这里只是把它当做一个 RAII 的 Query 类来用，用来计算每个节点的时间。

## FVulkan GPU Timing 关于 TimeStampQuery的循环管理

`One FVulkanGPUTiming Per Pool`
每个FVulkanGPUTiming会初始化一个Pool，初始化的时候需要指定Pool的大小。

![UE_Vulkan_TimeStampQuery计时和一个竞态条件的bug-2026-07-20-22-28-57](https://img.blurredcode.com/img/UE_Vulkan_TimeStampQuery计时和一个竞态条件的bug-2026-07-20-22-28-57.png?x-oss-process=style/compress)

```
	for (PendingQuery& Query : PendingTimestampQueries)
	{
		const uint64 Index = Query.Index;
		const VkBuffer BufferHandle = Query.BufferHandle;
		const VkQueryPool PoolHandle = Query.PoolHandle;
		const VkQueryResultFlags BlockingFlags = Query.bBlocking ?  VK_QUERY_RESULT_WAIT_BIT : VK_QUERY_RESULT_WITH_AVAILABILITY_BIT;
		const uint32 Width = (Query.bBlocking ? 1 : 2);
		const uint32 Stride = sizeof(uint64) * Width;

		VulkanRHI::vkCmdCopyQueryPoolResults(GetHandle(), PoolHandle, Index, Query.Count, BufferHandle, Stride * Index, Stride, VK_QUERY_RESULT_64_BIT | BlockingFlags);
```


虚幻在拷贝数据的时候会带有 `VK_QUERY_RESULT_64_BIT | VK_QUERY_RESULT_WITH_AVAILABILITY_BIT`, 通过mapping我们可以在不发起Query查询的情况下，直接通过mapping出来的数据来判断Query是否可用。


# FRealtimeGPUProfiler 这个的用途

这个和`stat gpu`以及`unreal insights`的trace channel直接相关。

```
游戏线程 / RDG
  └─ SCOPED_GPU_STAT(RHICmdList, StatName)          ← 宏入口
       └─ FScopedGPUStatEvent                        ← RAII 包装
            └─ FRealtimeGPUProfiler::PushStat/PopStat
                 └─ FRealtimeGPUProfilerFrame::PushEvent/PopEvent
                      └─ FRealtimeGPUProfilerEvent::Begin/End
                           └─ RHIEndRenderQuery(Query)   ← 写入 GPU timestamp
```

注意到`SCOPED_GPU_STAT`实际就是注册了一个FRealtimeGPUProfilerEvent

它内部和 FVulkanGPUTiming 无关，每个 `FRealtimeGPUProfilerEvent` 封装了两个 Query

这里概念有重复的地方，就是虚幻有一个Query池子，然后Vulkan Query下面也有一个vk的Query池子


```cpp
FRenderQueryPoolRHIRef RenderQueryPool;  // 虚幻的Query池子，FRealtimeGPUProfilerEvent的构造函数这里申请，析构函数归还
Vulkan TimeStampQuery需要一个 vkQueryPool, One Query Per Pool
```

当RDG提交的时候会自动执行Query的提交。

![UE_Vulkan_TimeStampQuery计时和一个竞态条件的bug-2026-07-20-22-28-45](https://img.blurredcode.com/img/UE_Vulkan_TimeStampQuery计时和一个竞态条件的bug-2026-07-20-22-28-45.png?x-oss-process=style/compress)

# 一个潜在的竞态条件
```
 5ec7aab FVulkanDynamicRHI::RHIGetRenderQueryResult [VulkanQuery.cpp:798]

 60a092c FRealtimeGPUProfilerEvent::GatherQueryResults [RealtimeGPUProfiler.cpp:115]

 60e0133 FRealtimeGPUProfilerFrame::UpdateStats [RealtimeGPUProfiler.cpp:443]

 609622d FRealtimeGPUProfiler::EndFrame [RealtimeGPUProfiler.cpp:939]

 95365b5 EndFrameRenderThread [LaunchEngineLoop.cpp:5604]

 9536bf2 TGraphTask<TEnqueueUniqueRenderCommandType<TRenderCommandTag<`FEngineLoop::Tick'::`67'::TSTR_EndFrame6208>,`FEngineLoop::Tick'::`67'::<lambda_10>>>::ExecuteTask [TaskGraphInterfaces.h:635]

 14cbe53 UE::Tasks::Private::FTaskBase::TryExecuteTask [TaskPrivate.h:502]

 14c1f26 FNamedTaskThread::ProcessTasksNamedThread [TaskGraph.cpp:781]

 14c237e FNamedTaskThread::ProcessTasksUntilQuit [TaskGraph.cpp:668]

 61b2ea8 RenderingThreadMain [RenderingThread.cpp:316]

 61b6449 FRenderingThread::Run [RenderingThread.cpp:441]

 1a79068 FRunnableThreadWin::Run [WindowsRunnableThread.cpp:156]

 1a6aa73 FRunnableThreadWin::GuardedRun [WindowsRunnableThread.cpp:79]

```

某一次崩溃的堆栈，经过研究，发现崩溃出现在

![UE_Vulkan_TimeStampQuery计时和一个竞态条件的bug-2026-07-20-22-26-25](https://img.blurredcode.com/img/UE_Vulkan_TimeStampQuery计时和一个竞态条件的bug-2026-07-20-22-26-25.png?x-oss-process=style/compress)

注意这里是在RenderThread

而Query的创建和初始化是在RHIThread 

![UE_Vulkan_TimeStampQuery计时和一个竞态条件的bug-2026-07-20-22-26-38](https://img.blurredcode.com/img/UE_Vulkan_TimeStampQuery计时和一个竞态条件的bug-2026-07-20-22-26-38.png?x-oss-process=style/compress)

这个竞态条件不太明显，画个图可以看出来

![UE_Vulkan_TimeStampQuery计时和一个竞态条件的bug-2026-07-20-22-26-48](https://img.blurredcode.com/img/UE_Vulkan_TimeStampQuery计时和一个竞态条件的bug-2026-07-20-22-26-48.png?x-oss-process=style/compress)

核心原因是 `RHIGetRenderQueryResult` 只要读取到 `Query->Pool` 就认为 Query 已经初始化完了，后面不加保护地访问 `Query->Pool->TimestampListHandle->CmdBuffer`。
实际上 `RHIEndRenderQuery` 在创建了 `Query->Pool` 之后仍然在初始化其他的东西，所以这里可能读取到未初始化完毕的 Query。


## 修复方案

方案1： `RHIEndRenderQuery` 里先不要填充 `Query->Pool` 指针，等变量全部初始化好以后再赋值，这样 RenderThread 不会读取到初始化到一半的 Query。

方案2： `RHIGetRenderQueryResult` 对 `Query->Pool->TimestampListHandle->CmdBuffer` 进行判空。