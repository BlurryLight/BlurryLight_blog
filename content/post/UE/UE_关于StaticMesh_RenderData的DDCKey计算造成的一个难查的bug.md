
---
title: "UE | 关于StaticMesh RenderData的DDCKey计算造成的一个难查的bug"
date: 2026-09-13T19:20:09+08:00
draft: false
categories: [ "UE"]
isCJKLanguage: true
slug: "e39123ba"
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

最近碰到个bug给我查背过气了..

先上一个极端简化后的代码，当`StaticMesh`在Cook或者在Editor里进行物理检查时候，可以根据做碰撞的LOD(虚幻可以指定某一级的LOD模型作为碰撞)上的每个Section的材质来判断物理材质。

这里Bug的表现是： `Section.MaterialIndex` 指向一个不存在的Index。出现问题的Mesh是曾经添加一个材质，后面又删除了，但是`RenderData.LODREsources[LODIndex].Section.MaterialIndex`里记录的仍然是已经被删除的材质，导致了一系列物理判断的问题。

** 另外吐槽一下虚幻的又一个垃圾设计，为什么物理的表现会依赖Section上记录的材质呢，强行把渲染和物理两个不相干的模块耦合在一起了。**

```cpp
bool UStaticMesh::GetPhysicsTriMeshDataCheckComplex(struct FTriMeshCollisionData* CollisionData, bool bInUseAllTriData, bool bInCheckComplexCollisionMesh)
{

    ....
	// Get the LOD level to use for collision
	// Always use 0 if asking for 'all tri data'
	const int32 UseLODIndex = bInUseAllTriData ? 0 : FMath::Clamp(LODForCollision, 0, GetRenderData()->LODResources.Num()-1);
	FStaticMeshLODResources& LOD = GetRenderData()->LODResources[UseLODIndex];

	for(int32 SectionIndex = 0; SectionIndex < LOD.Sections.Num(); ++SectionIndex)
	{
		const FStaticMeshSection& Section = LOD.Sections[SectionIndex];
        for (uint32 TriIdx = Section.FirstIndex; TriIdx < OnePastLastIndex; TriIdx += 3)
        {
            ...
            CollisionData->MaterialIndices.Add(Section.MaterialIndex);  // BUG: Section.MaterialIndex里出现了超过StaticMesh里的Materials.Num()的索引
        }
	}
```

# 难查和好查的点

首先我锁定了一个必现此bug的Mesh，无论是Editor还是Cooked的客户端，物理材质始终获取不正确，出来是引擎默认的物理材质。能必现的Bug都是能解决的。

这里有个越界Index，那么我首先让AI搓了一个小工具，遍历目标Mesh上的`RenderData`下的所有LOD的所有Section，挨个检查`MaterialIndex`是否是stale的值并自动修复。
然而，事情并不是那么简单，自己搓的工具根本扫描不出来目标Mesh上的异常数据，显示一切正常。

## `RenderData`会自修复

```cpp
void UStaticMesh::FinishPostLoadInternal(FStaticMeshPostLoadContext& Context)
{
	{
#if WITH_EDITOR
		if (GetRenderData())
		{
			GetRenderData()->ResolveSectionInfo(this);
		}
#endif
	}
}
void FStaticMeshRenderData::ResolveSectionInfo(UStaticMesh* Owner)
{
	int32 LODIndex = 0;
	int32 MaxLODs = LODResources.Num();
	for (; LODIndex < MaxLODs; ++LODIndex)
	{
		FStaticMeshLODResources& LOD = LODResources[LODIndex];
		for (int32 SectionIndex = 0; SectionIndex < LOD.Sections.Num(); ++SectionIndex)
		{
			FMeshSectionInfo Info = Owner->GetSectionInfoMap().Get(LODIndex,SectionIndex);
			FStaticMeshSection& Section = LOD.Sections[SectionIndex];
			Section.MaterialIndex = Info.MaterialIndex;
			Section.bEnableCollision = Info.bEnableCollision;
			Section.bCastShadow = Info.bCastShadow;
			Section.bVisibleInRayTracing = Info.bVisibleInRayTracing;
			Section.bAffectDistanceFieldLighting = Info.bAffectDistanceFieldLighting;
			Section.bForceOpaque = Info.bForceOpaque;
		}


```


原来在每个`StaticMesh`执行完PostLoad后，会在PostLoad阶段重新计算`RenderData`里的数据，如果发现和`StaticMesh`上U类记录的数据不一样，这里会重新修复RenderData内部的数据。


## UStaticMesh::GetPhysicsTriMeshDataCheckComplex的执行时机


![UE_关于StaticMesh_RenderData的DDCKey计算造成的一个难查的bug-2026-09-13-19-35-24](https://img.blurredcode.com/img/UE_关于StaticMesh_RenderData的DDCKey计算造成的一个难查的bug-2026-09-13-19-35-24.png?x-oss-process=style/compress)
![UE_关于StaticMesh_RenderData的DDCKey计算造成的一个难查的bug-2026-09-13-19-36-34](https://img.blurredcode.com/img/UE_关于StaticMesh_RenderData的DDCKey计算造成的一个难查的bug-2026-09-13-19-36-34.png?x-oss-process=style/compress)

下了个断点在`UStaticMesh::GetPhysicsTriMeshDataCheckComplex`，发现执行时机在`GetRenderData`的时候发现RenderData尚未完全准备好，主线程此时正在同步等待，而`GetPhysicsTriMeshDataCheckComplex`的调用点来自异步线程，看起来这个时候似乎`Mesh`在Load阶段读取到的`RenderData`是个错误的值，然后随即在`StaticMesh::PostLoad`阶段被修复会正确的值。


# DDC Key的错误计算

`StaticMesh`的RenderData是一个带缓存的值，它平时是存放在DDC里的。他的调用点在

```cpp
const FString KeySuffix = BuildStaticMeshDerivedDataKeySuffix(TargetPlatform, Owner, LODGroup);
DerivedDataKey = BuildStaticMeshDerivedDataKey(KeySuffix);
```


```cpp
static FString BuildStaticMeshDerivedDataKeySuffix(const ITargetPlatform* TargetPlatform, UStaticMesh* Mesh, const FStaticMeshLODGroup& LODGroup)
{
    // 有问题的代码
	// Append the section material slot mappings for LOD0, as they are baked into the Nanite build.	
	const FMeshSectionInfoMap& SectionInfoMap = Mesh->GetSectionInfoMap();
	int32 NumLOD0Sections = SectionInfoMap.GetSectionNumber(0);
	KeySuffix += TEXT("_");
	for (int32 SectionIndex = 0; SectionIndex < NumLOD0Sections; SectionIndex++)
	{
		KeySuffix += LexToString(SectionInfoMap.Get(0, SectionIndex).MaterialIndex);
	}
	return KeySuffix;
}
```

跟到下面发现，`RenderData`的记录的`MaterialIndex`只包含了`LOD0`的所有Section0的`MaterialIndex`。

这显然是一个错误的假设。假如我有一个`StaticMesh`想要LOD0和LOD1使用不同的材质，LOD1的Section完全可以修改成LOD0完全不同的`MaterialIndex`，然而这样的变化却不会触发`RenderData`的cache key发生变化，导致DDC仍然缓存的是旧的RenderData。

这里应该包含所有LOD的Index，修改后问题消失。