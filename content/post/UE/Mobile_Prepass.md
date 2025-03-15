
---
title: "UE | Mobile: Prepass Or Not?"
date: 2025-03-15T14:04:22+08:00
draft: false
categories: [ "UE"]
isCJKLanguage: true
slug: "239ae6a3"
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


首先可以看看一篇其他人写的好博客。
> 参考：[To z-prepass or not to z-prepass – Interplay of Light](https://interplayoflight.wordpress.com/2020/12/21/to-z-prepass-or-not-to-z-prepass/)
> 
> 
# 为什么对Mask材质开PrePass有性能优势

- Overdraw的产生:
由于mask材质里会有clip指令出现，所以管线里没法做early-z，只能跑完整的PS，这样会导致大量的Pixel Shader Overdraw.

- 为什么Opaque物体不会产生?
也会产生Overdraw。但是由于引擎里Opaque物体基本都做了从前往后排序，所以在绘制过程中由于Opaque物体可以经过early-Z优化，有大概率被earlyz pixel killing.

- 为什么开启Prepass对mask材质会有好处

`Engine\Shaders\Private\DepthOnlyPixelShader.usf`

虚幻渲染PrePass的时候用的，会根据材质生成一个 `DepthOnlyPixelShader.usf`,主要是给阴影和PrePass用的。
这个材质只计算Pixel Location 和 `Clip`相关的信息，不进行复杂的颜色计算，相当于一个轻量级的PS。

这样在PrePass的时候，就可以只跑这个轻量级的PS，可以获得完整的深度图。
然后在正式渲染的时候，就可以根据这个深度图进行early-z优化(开启Z Test Mode =  Equal).



# 常见Bug: Mask材质开启PrePass可能导致IOS上闪烁的问题

如果Prepass的shader编译选项和Basepass的VS的编译选项不一致可能会导致Basepass有一些pixel无法正确通过early-z的测试，导致闪烁的问题。

[IOS Mask材质开启prepass导致闪烁 - 知乎](https://zhuanlan.zhihu.com/p/86816529)https://blog.csdn.net/weixin_39864682/article/details/111803055

[Metal 2.1中的新关键字invariant - 知乎](https://zhuanlan.zhihu.com/p/58076970#comment-754568622?notificationId=1165228901306998784)



# Full Prez / Masked Prez


缺点:
- Drawcall / Vertices / binning pass 翻倍

纯Vulkan-API对dc不是很敏感，可以视性能评估的结果来决定。从鸣潮和原神的抓帧的结果来分析，Mobile上似乎是没有开prepass的。可能还是主要考虑到低端机的性能问题。


优点:

- 允许在Basepass绘制的时候使用 Depth-Equal Compare(尤其是对于Foliage)，这样即使shader里有clip指令仍然能够享受到early-z的优化。(UE在有Prepass的情况下，basepass里clip相关的计算都是直接跳过的，因为之前已经算过了)
节约大量的pixel 计算。

- 有Full Depth的情况下(在Basspass前)，可以允许很多效果在当帧完成。比如SSAO，可以在basePass前完成，在着色的时候直接采，避免延后一帧，导致旋转的时候拖影
- Occlusion Culling， hardware occlusiong query可以在当帧的DepthBuffer上完成，而不用用上一帧的（但是结果仍然要延后一帧读取）。这样可以从延后两帧(n帧用n-1帧的depthbuffer做occlusion query, n+1帧读取结果)变成延后一帧(n帧用n帧的depthbuffer做occlusion query, n+1帧读取结果)，显著降低occlusion query的延迟(比如镜头已经转过来，但是由于延迟之前被剔除的物体可能还没出现)
- deferred decal
- 需要在屏幕空间在DepthBuffer上做tracing的所有效果都可以考虑提前到FullPrePass之后，BasePass之前完成，否则都会延迟一帧。如果移动端锁30帧的情况下，慢一帧可能会导致在旋转屏幕的时候注意到明显的拖影。



# 允许虚幻动态切换Prepass和不Prepass

虚幻在Mobile控制EarlyPass主要是如下的cvar控制:

该cvar是静态的，会作为宏定义在shader里，并且影响若干个pass的采样深度的代码。
主要是如果定义了FullPreZ，
- 那么许多效果可以通过SceneDepthZ来获取深度
- 如果没有定义FullPreZ，那么有一些在OnePass里的深度只能通过 subpass Fetch来获取片上深度(不允许跨像素采样)

```cpp
static TAutoConsoleVariable<int32> CVarMobileEarlyZPass(
	TEXT("r.Mobile.EarlyZPass"),
	0,
	TEXT("Whether to use a depth only pass to initialize Z culling for the mobile base pass. Changing this setting requires restarting the editor.\n")
	TEXT("  0: off\n")
	TEXT("  1: all opaque \n")
	TEXT("  2: masked primitives only \n"),
	ECVF_ReadOnly
);
```


那么如果我们想让手机可以在Prepass和Not Prepass之间切换，应该怎么做呢？


仔细观察shader里采取深度的地方，我们注意到，只要我们强行定义`FORCE_DEPTH_TEXTURE_READS`这个宏，我们就能让所有Shader的采样深度从FullPrepassZ里读取。




```cpp
/** Returns DeviceZ which is the z value stored in the depth buffer. */
float LookupDeviceZ( float2 ScreenUV )
{
#if	SCENE_TEXTURES_DISABLED
	return FarDepthValue;
#elif FORCE_DEPTH_TEXTURE_READS || PLATFORM_NEEDS_DEPTH_TEXTURE_READS
	// native Depth buffer lookup
	return Texture2DSampleLevel(MobileSceneTextures.SceneDepthTexture, MobileSceneTextures.SceneDepthTextureSampler, ScreenUV, 0).r;
#elif MOBILE_DEPTHFECTH && COMPILER_GLSL_ES3_1
	return DepthbufferFetchES2();
#elif MOBILE_DEPTHFECTH && VULKAN_PROFILE
	return VulkanSubpassDepthFetch();
#elif MOBILE_DEPTHFECTH && (METAL_PROFILE && !MAC)
	return DepthbufferFetchES2();
#elif (USE_SCENE_DEPTH_AUX && !MOBILE_DEFERRED_SHADING)
	// SceneDepth texture is discarded after BasePass (with forward shading) 
	// instead fetch DeviceZ from SceneDepthAuxTexture
	return Texture2DSampleLevel(MobileSceneTextures.SceneDepthAuxTexture, MobileSceneTextures.SceneDepthAuxTextureSampler, ScreenUV, 0).r;
#else
	// native Depth buffer lookup
	return Texture2DSampleLevel(MobileSceneTextures.SceneDepthTexture, MobileSceneTextures.SceneDepthTextureSampler, ScreenUV, 0).r;
#endif
}
```

所以改动思路还是很简单:

- 很多个pass要额外定义一个`FORCE_DEPTH_TEXTURE_READS`的变体，当Prepass开启的时候，使用这个变体
- 把prepass的开关做成动态的，不能是readonly的
- 有的pass里定义了`IS_MOBILE_DEPTHREAD_SUBPASS`，根据这个宏来决定是否使用subpass的深度采样。我们要强行设置`IS_MOBILE_DEPTHREAD_SUBPASS`为1，统一走我们新加的变体来管理


`IS_MOBILE_DEPTHREAD_SUBPASS`实际上是作为一个宏`MOBILE_DEPTHFECTH`的条件。为什么要强行设置成1 ？
因为如果不设置成1，cook后的结果不会包含带有subpass的变体，没法动态切换过来。


最后我们的逻辑变成了
- 如果`r.Mobile.EarlyZPass == 0`，走原来的逻辑，该走subpass走subpass
- 如果`r.Mobile.EarlyZPass == 1/2`，所有的变体选择`FORCE_DEPTH_TEXTURE_READS`的变体


![edit-061decb12d604c73a6678d90c94bf4ee-2025-03-11-14-56-35](https://img.blurredcode.com/img/edit-061decb12d604c73a6678d90c94bf4ee-2025-03-11-14-56-35.png?x-oss-process=style/compress)


View上额外补充一个uniform来标记一个变量
![edit-061decb12d604c73a6678d90c94bf4ee-2025-03-11-14-57-39](https://img.blurredcode.com/img/edit-061decb12d604c73a6678d90c94bf4ee-2025-03-11-14-57-39.png?x-oss-process=style/compress)

