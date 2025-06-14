
---
title: "UE | HLOD 让部分Moveable的Actor也参与HLOD Build"
date: 2025-06-14T21:08:47+08:00
draft: false
categories: [ "UE"]
isCJKLanguage: true
slug: "69bb9694"
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

这算是一个我们项目碰到的一个"伪"需求吧。有一部分Mesh在场景里可能按照Sequence K的动画的方式移动(因为涉及到物理所以不能使用材质WPO来处理)，但是这类Mesh属于一个巨型建筑的组成部分，所以如果HLOD把这些`Movable`的Actor剔除了，远处的剪影效果就不对了。

# 解决方案

UE里，一个`StaticMeshComponent`被排除出HLOD的判断逻辑是通过`IsHLODRelevant()`函数来实现的。这个函数会检查Component的`Mobility`属性，如果是`Movable`，则默认返回false。

实现上是新加了一种Volume,然后放了一个 `AHLODMovableRelevantVolume`的盒子在场景里，在这个盒子里的物体即使是Movable也会被认为是HLOD Relevant，但是在Commandlet实际Build HLOD时还是会忽略这个Actor。

具体修改方案如下:

```cpp
// UStaticMeshComponent.cpp IsHLODRelevant
...
if (Mobility == EComponentMobility::Movable)
	{
		// ++ravenzhong
		bool bFoundMovableRelevantVolume  = false;
		// a rare cornel case: WaterBodyCustomComponent::PostLoad will try to access IsHLODRelevant()
		// in that case, GetWorld() will return nullptr ( WorldPrivate was set in RegisterComponent)
		if(GetWorld())
		{
			for (TActorIterator<AHLODMovableRelevantVolume> It(GetWorld(), AHLODMovableRelevantVolume::StaticClass());
				It && !bFoundMovableRelevantVolume;
				++It)
			{
				auto Volume = It;
				const bool bIntersecting = Volume->EncompassesPoint(Bounds.Origin, Bounds.SphereRadius, nullptr);
				bFoundMovableRelevantVolume |= bIntersecting;
			}
		}
		return bFoundMovableRelevantVolume;
        //--ravenzhong
		// return false;
	}
```


## 避免重新保存所有的Actor

摆了盒子以后发现在流水线上Build HLOD时，仍然没有这些`Movable`的Actor参与HLOD编译...那只能继续往下查了

在Commandlet里Build HLOD时，会先通过SetupHLODs步骤来收集哪些Actors会参与HLOD Actor编译。

这个过程位于`Plugins/Editor/WorldPartitionHLODUtilities/Source/Private/WorldPartition/HLOD/Utilities/WorldPartitionHLODUtilities.cpp`


```cpp

TArray<AWorldPartitionHLOD*> FWorldPartitionHLODUtilities::CreateHLODActors(FHLODCreationContext& InCreationContext, const FHLODCreationParams& InCreationParams, const TArray<IStreamingGenerationContext::FActorInstance>& InActors)
{
	TMap<UHLODLayer*, TSet<FHLODSubActor>> SubActorsPerHLODLayer;

	for (const IStreamingGenerationContext::FActorInstance& ActorInstance : InActors)
	{
		const FWorldPartitionActorDescView& ActorDescView = ActorInstance.GetActorDescView();

		if (ActorDescView.GetActorIsHLODRelevant()) // 注意这一行！！
		{
			if (!ActorInstance.ActorSetInstance->bIsSpatiallyLoaded)
			{
				UE_LOG(LogHLODBuilder, Warning, TEXT("Tried to included non-spatially loaded actor %s into HLOD"), *ActorDescView.GetActorName().ToString());
				continue;
			}
```

注意这里`WorldPartition` 收集Actors时并不实际Load Actor，而是通过ActorDesc里序列化的一个值来判断是否是`HLOD Relevant`，而这个值是在大世界Actor保存时计算的。

所以bug的主要的流程如下:

1. 大世界先摆了几个Movable Actors，然后保存，此时IsHLODRelevant()为false，并被序列化保存到ActorDesc
2. 场景拖了一个 AHLODMovableRelevantVolume上去，包裹了这些Actors，期望这些Actors参与HLOD编译
3. Build HLODs，此时Commandlet仍然从ActorDesc读取序列化下来的值，而不是实际Load进来判断，所以仍然得到false
4. Build HLODs的结果里没有这些Actors。

一个简单的办法是重新触发一次Actor的保存，这样会更新在WorldParition里记录的`ActorDesc`的值。
另外一个简单的办法是在SetupHLODs这里，读取场景所有的Volume,并将Volume和ActorDesc里保存的Bounds进行求交。
这样就可以不用重新保存了!

```cpp
    if (ActorDescView.GetActorIsHLODRelevant()
    || ActorDescView.GetBounds().Intersect(Volume)) // 伪代码
{

}
```