
---
title: "UE: 下一款Android开发机不一定是Android"
date: 2025-10-09T22:32:58+08:00
draft: false
categories: [ "UE"]
isCJKLanguage: true
slug: "3e667544"
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

最近看了下Epic在Unreal Fest2024和Unreal Fest2025的两篇关于移动端的workflow的介绍，又尝试了一些新的东西。
移动端真机调试一直是一个我工作的一个痛点..无论是Android还是iOS..

# 关于虚幻在模拟器上运行的可行性

UE5.X后对模拟器支持的比较好了，无论是Android Studio还是iOS Simulator都可以比较好的模拟了。

## Android 模拟器支持


![edit-309e75825ef44e1ea99093c4f67c5efc-2025-07-10-17-29-33](https://img.blurredcode.com/img/edit-309e75825ef44e1ea99093c4f67c5efc-2025-07-10-17-29-33.png?x-oss-process=style/compress)


## Mac模拟器支持

- Mac我们用的是下面那种，打包成IPA以后直接安装并调试(只能适用于M芯片的mac)

最后一条不支持GPU Debugger是**可以改**的，项目里已经验证过了，把XCode Capture Plugin给改改就可以做到抓帧直接写入到文件，然后读取抓帧后的文件。

![edit-309e75825ef44e1ea99093c4f67c5efc-2025-07-10-14-21-01](https://img.blurredcode.com/img/edit-309e75825ef44e1ea99093c4f67c5efc-2025-07-10-14-21-01.png?x-oss-process=style/compress)

第一种模拟方式意义不大，主要是GPU特性支持不全。


这里重点讲下怎么用模拟器跑Android，iOS其实用 Xcode的`designed for iPad`的模式就可以比较无缝的跑了。

# 关于使用模拟器跑Android游戏

## 关于x86模拟器和arm模拟器

### x86模拟器

x86上跑测没问题，gpu直通，cpu靠libhoudini转译。

优点: 
1. 性能好，不卡， GPU直通桌面端显卡。

缺点:

1. 由于cpu指令是转译的，调试器无法直接调试。
2. gpu由于直通桌面端的原因，可能没法准确模拟half。
3. 只有vulkan支持(subpass), gl的话不行(部分扩展不支持)。扩展支持有限，不支持Bindless和Raytracing。

### Mac arm模拟器

优点:
1. mac上可以完美模拟，指令集无需转译，**AGDE调试很方便**！

缺点:
1. 实测无法renderdoc抓帧，很遗憾，可能因为模拟器 + VK转译Metal套太多层了
2. 由于底层基于MoltenVK，不支持RayTracing管线


**x86可用的镜像:** （务必选择带有Google APIs的镜像，Google Play可能也行). AOSP不行，不带libhoudini无法模拟arm64的apk

![下一个Android开发机不一定是Android-2025-10-09-22-44-38](https://img.blurredcode.com/img/下一个Android开发机不一定是Android-2025-10-09-22-44-38.png?x-oss-process=style/compress)

**mac可用的镜像**:  选default即可

![edit-309e75825ef44e1ea99093c4f67c5efc-2025-10-09-14-21-00](https://img.blurredcode.com/img/edit-309e75825ef44e1ea99093c4f67c5efc-2025-10-09-14-21-00.png?x-oss-process=style/compress)


如何验证:
装一个vulkaninfo的apk即可。

Windows直通的结果

![edit-309e75825ef44e1ea99093c4f67c5efc-2025-10-09-14-54-27](https://img.blurredcode.com/img/edit-309e75825ef44e1ea99093c4f67c5efc-2025-10-09-14-54-27.png?x-oss-process=style/compress)

Mac直通的结果

![edit-309e75825ef44e1ea99093c4f67c5efc-2025-10-09-14-57-10](https://img.blurredcode.com/img/edit-309e75825ef44e1ea99093c4f67c5efc-2025-10-09-14-57-10.png?x-oss-process=style/compress)


** 模拟器跑虚幻 Mobile Deferred Renderer **

![edit-309e75825ef44e1ea99093c4f67c5efc-2025-10-09-15-01-04](https://img.blurredcode.com/img/edit-309e75825ef44e1ea99093c4f67c5efc-2025-10-09-15-01-04.png?x-oss-process=style/compress)



# Reference 

- [Mobile Game Development with Unreal Engine | Unreal Fest 2024 - YouTube](https://www.youtube.com/watch?v=rSswLKbKREk)
- [Mobile Game Development with Unreal Engine | Unreal Fest Orlando 2025 - YouTube](https://www.youtube.com/watch?v=tN8wgJXF_kc&t=1716s)