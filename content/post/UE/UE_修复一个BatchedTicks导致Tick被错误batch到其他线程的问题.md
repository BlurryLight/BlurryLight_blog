
---
title: "UE | 修复一个BatchedTicks导致Tick被错误batch到其他线程的问题"
date: 2026-10-17T14:47:33+08:00
draft: false
categories: [ "UE"]
isCJKLanguage: true
slug: "de11d8a5"
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

影响范围大概是 5.5.0 到 5.7，主干 5.7 上已经修复了，提交见[这里](https://github.com/EpicGames/UnrealEngine/commit/1b86bab43fe0e536e932e9d4853fe8a0ec5d2501)。

# 问题

[Add tick.AllowBatchedTicks cvar (disabled by default) for automatical… · BlurryLight/UE@6946b2c](https://github.com/EpicGames/UnrealEngine/commit/6946b2c9cb9dafa0d74387800913df419a8ecb6c)

虚幻 5.5 的时候出了一个优化功能。大概背景是，虚幻的 `tick function` 其实建立在 `TaskGraph` 上，每个 `tick function` 对应一个 `TaskGraph` 的 `task`。

每帧一开始发起 `tick` 的时候，引擎都需要把所有 `FTickFunction` 转成 `TaskGraph` 的 `task`，还要算出所有 `tick function` 的前驱和后驱任务，才能把 `DAG` 构建出来。

但实际上绝大多数 `tick function` 之间并没有复杂的依赖，它们完全可以打包进一个 `task` 里，在合适的时机被一个 `for` 循环依次调用完。

# 合并 `Batch` 的依据

5.5 的代码是按下面这些条件进行分桶的，满足同一个桶条件的 `tick function` 会被放进一个 `batch` 里：
```cpp
struct FTickGroupCondition
{
	union
	{
		uint32 IntVersion;
		struct {
			TEnumAsByte<ETickingGroup> StartGroup;
			TEnumAsByte<ETickingGroup> EndGroup;
			bool bHighPriority;
			bool bIsBatch;
		};
	};
};
	
```

## Bug

可以注意到，`FTickGroupCondition` 里忽略了一个 `FTickFunction` 的重要属性 `bRunOnAnyThread`。

```cpp
	/** If false, this tick will run on the game thread, otherwise it will run on any thread in parallel with the game thread and in parallel with other "async ticks" **/
	uint8 bRunOnAnyThread:1;
```

虚幻的 `FTickFunction` 实际上由于依托在 `TaskGraph` 上，是可以在任意线程执行的。这个开关没有暴露到蓝图，但在 C++ 这边是完全可以注册一个任意线程的 `tick function` 的。

我们项目有一些不太重要的氛围相关的计算，实际上就是在异步线程跑的。bug 的表现是有一些其他的 `tick function` 也跑到了异步线程，并且触发了线程安全的 `check`。

阅读代码以后 bug 很快就找到了：`tick function` 分组的时候没有考虑 `bRunOnAnyThread`，所以它和其他 `tick function` 一起进了一个 `batch`。

而每个 `batch` 在哪个线程执行，是依靠这个 `batch` 第一个 `tick function` 的属性决定的。

![UE_修复一个BatchedTicks导致Tick被错误batch到其他线程的问题-2026-10-17-15-03-18](https://img.blurredcode.com/img/UE_修复一个BatchedTicks导致Tick被错误batch到其他线程的问题-2026-10-17-15-03-18.png?x-oss-process=style/compress)


当第一个 `tick function` 恰好是异步线程执行的 `tick function` 的时候，就可能把一整个 `batch` 的 `tick function` 都带到异步线程去，而其他 `tick function` 可能并不是线程安全的。

# 修复

可以考虑pick官方的改动，官方那个改动一大坨不知道下面在修什么东西的代码，只用pick `bRunAnyThread`这个问题就可以了.