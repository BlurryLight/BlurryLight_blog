
---
title: "Debug你的光线追踪渲染器"
date: 2020-07-01T18:39:12+08:00
draft: false
# tags: [ "" ]
categories: [ "CG"]
# keywords: [ ""]
lastmod: 2020-07-01T18:39:12+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "Debug你的光线追踪渲染器"
toc: false
# latex support
# katex: true
# markup: mmark
---

![Debugger](/image/debugger.gif)

光线追踪渲染debug很困难，当然实时渲染debug也很难。有的时候材质实现的不太对，可能很长一段时间都看不出来。渲染环境下Debugger基本是不可用的，多线程+十万/百万条光线加上递归的求解算法，断点打上也看不出毛病在哪里。条件断点等偶尔有所帮助，不过总体帮助不大，渲染中常见的debugger方法还是刻意构造一些简单场景(全是镜子的房间、两个相切的球)，或者输出法向量图等来debug。

我们可以实现一些小工具来帮助debug。比如这里的例子。我实现了一个可视化工具，渲染器在debug模式下会使用`spdlog`记录每一束光线的`origin`(原点)，`isect.coords`(击中的物体表面), `isect.normal`(物体表面的法向量)，输出到log文件中。然后Debugger去parse这个log文件，用OpenGL的`Geometry Shader`画出每根光线。

Debugger的实现依赖`OpenGL`，简单采用一个`BlinnPhong`就能得到还不错的效果，没有阴影。可以用ImGUI做一些简单的GUI，因为全部的光线显示出来就太多了，我们可能只是为了观察某个物体的表面的反射、折射情况，所以要能够控制显示指定区域的光线。

还有很多功能还没完善，比如物体的表面的Normal用线段画出来, 表面的`brdf`项也可以记录下来，映射成不同的光线颜色来辅助判断。

实现位于 debugger目录:
https://github.com/BlurryLight/DiRender​

一个小的离线渲染器，结构参考了pbrt-v3。大框架已经搭好了，目前实现了path-tracing和matte,mirror和dielectric三种材质，复杂的积分算法，采样算法和材质会慢慢加进去。目前只支持CPU并行，可能以后会接入GPU的backend。