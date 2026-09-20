
---
title: "UE | Occlusion Query导致切镜头时物体闪烁的问题"
date: 2026-09-20T14:05:32+08:00
draft: false
categories: [ "UE"]
isCJKLanguage: true
slug: "59a3f7fc"
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

# 闪烁问题

最近QA报了一个bug：Sequence进行镜头切换的时候，部分物体会闪烁。
拉了个视频逐帧分析，发现闪烁发生在第二帧。
时序大概如下：

- Sequence镜头切换，此时第一帧，物体还在
- 第二帧，物体消失
- 第三帧，物体再次出现

本来如果是第一帧物体消失，还可以往遮挡剔除方向怀疑：镜头快速切换以后，Occlusion Query回读的是上一帧的结果，并且GPUScene上也是用上一帧的HZB进行剔除，所以第一帧闪烁完全有可能出现。这个在虚幻里以及其他游戏里也很常见，比如相机穿墙而出的话，很可能能看到外面一片空白，就是这个原因。


但是第二帧闪烁就不太常见了。研究了一下源码，发现虚幻在这里是有处理的：出现`CameraCut`的时候会重置Occlusion Query的历史。
不过很快我就注意到这里有一个bug：Occlusion Query可以缓存多少帧是一个可调的参数（`r.NumBufferedOcclusionQueries`），并不一定只有一帧。移动端GPU性能弱，默认会缓冲两帧。
这意味着CameraCut发生的时候，正在In Flight的OcclusionQuery可能横跨不止一帧，但是这里虚幻的代码只重置一次，第二帧仍会读到切镜头前的历史的OcclusionQuery——于是第一帧是对的，第二帧消失，第三帧重新出现。

正确的修复应该从CameraCut出现那一帧开始，连续`NumBufferedFrames`帧忽略已有的查询结果，或者干脆直接清空所有Occlusion Query的历史。

# 修复补丁

```cpp
			// detect conditions where we should reset occlusion queries
			if (bFirstFrameOrTimeWasReset || 
				ViewState->LastRenderTime + GEngine->PrimitiveProbablyVisibleTime < View.Family->Time.GetRealTimeSeconds() ||
				View.bCameraCut ||
				View.bForceCameraVisibilityReset ||
				IsLargeCameraMovement(
					View, 
					FMatrix(ViewState->PrevViewMatrixForOcclusionQuery), 
					ViewState->PrevViewOriginForOcclusionQuery, 
					GEngine->CameraRotationThreshold, GEngine->CameraTranslationThreshold))
			{
				View.bIgnoreExistingQueries = true;
				View.bDisableDistanceBasedFadeTransitions = true;
				//++ravenzhong
				const int32 NumBufferedFrames = FOcclusionQueryHelpers::GetNumBufferedFrames(Scene->GetFeatureLevel()) 
					* ((ViewState->IsRoundRobinEnabled() && IStereoRendering::IsStereoEyeView(View)) ? 2 : 1);
				ViewState->IgnoreOcclusionQueriesUntilFrameCounter = FMath::Max(
					ViewState->IgnoreOcclusionQueriesUntilFrameCounter,
					ViewState->OcclusionFrameCounter + (uint32)NumBufferedFrames);
				//--ravenzhong
			}

			//++ravenzhong
			if (ViewState->OcclusionFrameCounter < ViewState->IgnoreOcclusionQueriesUntilFrameCounter)
			{
				View.bIgnoreExistingQueries = true;
			}
			//--ravenzhong
```

在虚幻使用View.bIgnoreExistingQueries的地方打补丁，从只重置一次，修改成要连续丢弃多次。