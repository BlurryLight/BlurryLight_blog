
---
title: "UE | Vulkan_下 UE Editor 操作界面卡顿问题"
date: 2026-04-01T02:11:31Z
draft: false
categories: [ "UE"]
isCJKLanguage: true
slug: "2f208232"
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

![Untitled-1-2026-04-01-10-12-19](https://img.blurredcode.com/img/Untitled-1-2026-04-01-10-12-19.png?x-oss-process=style/compress)


通过`-vulkan -sm5`启动
每次操作界面可以肉眼注意到slate的界面出现模糊然后卡顿2s后变清晰


经过定位发现是卡在swapchain的重建上

关闭cvar  `r.vulkan.keepswapchain`后立马好转

怀疑是驱动问题


Vulkan Spec这么说>


```
oldSwapchain is VK_NULL_HANDLE, or the existing non-retired swapchain currently associated with surface. Providing a valid oldSwapchain **may** aid in the resource reuse, and also allows the application to still present any images that are already acquired from it.
```

看起来是个没啥用的优化，主要是驱动可能会帮忙处理旧交换链的销毁和同步。
但是这里直接WaitGPUIdle应该也没啥问题