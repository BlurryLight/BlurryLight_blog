
---
title: "UE 谨慎使用SetCollisionProfileName和SetCollisionEnabled"
date: 2024-02-18T22:28:57+08:00
draft: false
categories: [ "UE"]
isCJKLanguage: true
slug: "3303b9f3"
toc: false
mermaid: false
fancybox: false
blueprint: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
---


我的一个测试工程里有个测试场景是大批量的调整Component的碰撞属性，用了`SetCollisionProfileName`和`SetCollisionEnabled`来实现。
但是在测试的过程中发现了一个问题，这两个函数的调用会导致性能急剧下降。

# SetCollisionProfileName

`UPrimitiveComponent::SetCollisionProfileName`会带来约`50us-100us`的卡顿，Component数量一多很容易到毫秒级别的耗时。
主要的耗时在`FBodyInstance::UpdatePhysicsFilterData()`


# SetCollisionEnabled

这个函数更夸张，可能会导致`100us-200us`的卡顿，可能会导致`PhysicsState`重建(类似于SceneProxy的MarkRenderStateDirty)。
如果用的物理引擎是Chaos可以参考下面的文章进行hack一下，phsyx或者havok就只能自求多福了..
> 参考：[Fast Chaos Collision Toggling | voithos.io](https://voithos.io/articles/fast-chaos-collision-toggling/)

# 结论

不要在tick或者timer这种高频调用里大批量的改变Component的Collision属性。
如果想要换用不同的Profile来测试碰撞，KismetSystemLib和UWorld下有一些接口可以在不改变Component的属性的情况下直接用几何体进行测试。