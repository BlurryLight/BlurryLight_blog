
---
title: "UE | SingleLayerWater和Translucent截断的问题"
date: 2025-08-18T23:44:30+08:00
draft: false
categories: [ "UE"]
isCJKLanguage: true
slug: "d4c72dd2"
toc: true
mermaid: true
fancybox: false
blueprint: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
UEVersion: 5.5.4
---

# SLW or Not?

![SingleLayerWater和Translucent截断的问题-2025-08-18-23-49-48](https://img.blurredcode.com/img/SingleLayerWater和Translucent截断的问题-2025-08-18-23-49-48.png?x-oss-process=style/compress)


选择SLW的理由:
- 虚幻提供的一整套水体渲染解决方案，天然支持水上，水下以及真实感水体渲染
- 原生开箱即用，和water系统结合紧密
- 不用处理复杂场景下的半透排序问题(水/瀑布多个片在某些视角下半透排序可能会出问题)

选择半透水材质的理由:
- 不写深度，不会产生遮挡问题
- NPR风格有一些其他游戏可以参考



# Single Layer Water 截断半透明物体的问题

## 首先，这是否是个问题

关于SLW截断半透明是否需要处理这个取决于策划和美术的需求...
不过如果是个多端互通的游戏，最好还是考虑处理下，因为在移动端上SLW会退化成一个非常简单的半透渲染，它不会产生截断其他半透的效果。而在PC端上SLW是一个Opaque的渲染方式 + 写深度，所以会在深度测试阶段截断很多半透明的问题，这里会产生不统一的渲染效果。

![SingleLayerWater和Translucent截断的问题-2025-08-19-00-00-00](https://img.blurredcode.com/img/SingleLayerWater和Translucent截断的问题-2025-08-19-00-00-00.png?x-oss-process=style/compress)

以塞尔达为例，其磁力命中宝箱时产生的命中特效是一个圆圈，但是显然这个圆圈特效被水面渲染截断了。但是实际从游戏体验上来说，并不会造成很明显的视觉瑕疵。

## 如果要解决，如何解决

碰到了和这个朋友碰到的同样的问题，这里记录一下解决方案。

[UE渲染学习（1）- SingleLayerWater遮挡半透明 - 知乎](https://zhuanlan.zhihu.com/p/25757519407)


## 关于Before DOF / After DOF阶段的半透问题

这两个阶段的半透会开启深度测试，如下图所示，只有After Motion Blur阶段的半透虚幻会关闭深度测试。

![SingleLayerWater和Translucent截断的问题-2025-08-18-23-56-43](https://img.blurredcode.com/img/SingleLayerWater和Translucent截断的问题-2025-08-18-23-56-43.png?x-oss-process=style/compress)


由于SLW在PC端会写入深度，这样深度测试的时候就会被水面阶段。

上面知乎的那个朋友的思路是在SLW渲染结束后，将深度图替换为不带SLW的，然后过了半透以后，再替换回来。


{{<mermaid>}}

graph TD
A[RenderSLW]-->B[Replace SceneDepthZ]
B-->C[Render Translucency]
C-->D[Reapply SceneDepthZ]

{{</mermaid>}}


尝试了一下是可行的，唯一要注意的几个点:

- 替换SceneDepthZ需要在HeightFog之后，否则可能会计算到错误的HeightFog，最好的阶段是在RenderTranslucency函数里面，里面还有一些对降分辨率的SceneDepthZ的处理
- 有的半透依赖深度测试(比如半透的云，你也不想透过水看到了云吧)，这种需要在Shader了里手动通过`SceneTextures::SceneDepth`或者`DepthFade`来进行深度测试



## After Motion Blur阶段的半透问题

由于虚幻在这个阶段默认禁用深度测试，所以一般在这个阶段的半透都要在材质里手动处理深度测试，通过DepthFade等方式。

这里的改造可以有两个思路。

1. 如果做了上一步替换SceneDepthZ的改造，那么DepthFade就没有什么需要改造的。
2. 如果没有做上一步的改造，那么这里可以考虑做一个DepthFadeWithoutWater的节点，同时在TranslucentBasePass结构体里新增加一个SceneDepthWithoutWater的纹理。可以参考材质里的`SceneDepthWithoutWater`这个节点的实现，虽然这个节点只允许在SLW材质里用，但是稍微改造下源码就可以迁移给半透材质使用。