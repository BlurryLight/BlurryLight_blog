
---
title: "UE|AVolume::EncompassesPoint永远失败的问题"
date: 2026-02-08T15:07:16+08:00
draft: false
categories: [ "UE"]
isCJKLanguage: true
slug: "3adb5b11"
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


[EncompassesPoint always fails when called with a Navigation Mesh Bounds Volume due to the Body Instance not being valid - Development / Programming & Scripting - Epic Developer Community Forums](https://forums.unrealengine.com/t/encompassespoint-always-fails-when-called-with-a-navigation-mesh-bounds-volume-due-to-the-body-instance-not-being-valid/2652951)

最近碰到了和这个老哥类似的问题，任何一个继承自AVolume的子类在判断`Actor->GetActorLocation`是否被Volume覆盖的时候总是返回false，即使是明显的case。

前情提要大概是需要在Build HLOD的时候对部分区域Actor进行特殊处理，所以从AVolume继承了一个子类，然后通过摆盒子来圈定空间范围。

# Debugging

深入debug了下，发现从某个版本开始`AVolume::EncompassesPoint`换掉了基于AABB检查的方法，而是依靠物理引擎来判断是否有交集。

![edit-d65cfcd9f5db4392aeff7d56e08c7989-2024-07-09-10-56-16](https://img.blurredcode.com/img/edit-d65cfcd9f5db4392aeff7d56e08c7989-2024-07-09-10-56-16.png?x-oss-process=style/compress)

注意这里判断点是否位于`Volume`内都是用的`GetSquaredDistanceToCollision`。
里面实际上是用的物理引擎判断的，如果Volume没有碰撞，这里会返回false，坑了我一天时间。


```cpp
bool UPrimitiveComponent::GetSquaredDistanceToCollision(const FVector& Point, float& OutSquaredDistance, FVector& OutClosestPointOnCollision) const
{
	OutClosestPointOnCollision = Point;

	FBodyInstance* BodyInst = GetBodyInstance();
	if (BodyInst != nullptr)
	{
		return BodyInst->GetSquaredDistanceToBody(Point, OutSquaredDistance, OutClosestPointOnCollision);
	}

	return false;
}
```


一个Actor要在物理引擎里使用，必须要用`Physics State`（类似于`Render State`)，即这个Actor在物理世界的代理体。



## 为什么ACullDistanceVolume什么都不用做就能工作?

一个Component是否创建Physics State一个统一的入口。

判断条件有两个：
1. 设置了Collision Profile, 或者
2. Component 带有bAlwaysCreatePhysicsState标记

```cpp
bool UPrimitiveComponent::ShouldCreatePhysicsState() const
{
	if (IsBeingDestroyed())
	{
		return false;
	}

	bool bShouldCreatePhysicsState = IsRegistered() && (bAlwaysCreatePhysicsState || BodyInstance.GetCollisionEnabled() != ECollisionEnabled::NoCollision);

...
	return bShouldCreatePhysicsState;
}
```

回过头来看，为什么虚幻默认的CullVolume直接拖到场景就能生效，并不需要任何额外的操作。

```cpp
ACullDistanceVolume::ACullDistanceVolume(const FObjectInitializer& ObjectInitializer)
	: Super(ObjectInitializer)
{
	GetBrushComponent()->SetCollisionProfileName(UCollisionProfile::NoCollision_ProfileName);
	GetBrushComponent()->bAlwaysCreatePhysicsState = true;

    ....
}
```


原来是设置了**bAlwaysCreatePhysicsState**，那就不奇怪了。


# 结论

虚幻的某次把AVolume的判定改动为依靠物理引擎，但是没有给AVolume的创建PhysicsState。
所以任何继承AVolume的子类（包括引擎里一些4.X时期的AVolume的子类没有适配），要用的时候都需要留意，PhysicsState是否已经创建。

