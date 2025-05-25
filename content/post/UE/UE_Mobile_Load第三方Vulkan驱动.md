
---
title: "UE | Mobile Load 开源freedreno Vulkan驱动"
date: 2025-05-25T12:04:21+08:00
draft: false
categories: [ "UE"]
isCJKLanguage: true
slug: "af26cfac"
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

之前看到Android上的switch模拟器有这个挺有意思的功能，就研究了一下，是否可以不使用系统的驱动，Load第三方的Vulkan驱动来绕过一些系统驱动。

结论是： 可以，虚幻跑起来没什么问题。但是从商业角度来看，由于绕开了Android一些安全措施，有Google Play的上架风险。

# UE Vulkan Loader


![UE_Mobile_Load第三方Vulkan驱动-2025-05-25-12-17-46](https://img.blurredcode.com/img/UE_Mobile_Load第三方Vulkan驱动-2025-05-25-12-17-46.png?x-oss-process=style/compress)


从虚幻的代码来看，vulkan的lib加载也不是很复杂的点，Android平台只有1-2个`dlopen`，加载了libvulkan.so的地方。这几个点需要修改一下，加载第三方驱动。


第三方驱动可以从这里下到，这个repo里存储了一些开源驱动(libfreedreno.so)，还有一些是从手机厂商的驱动中提取出来的libvulkan.so，比如Meta Quest 2的libvulkan.so。

[Releases · K11MCH1/AdrenoToolsDrivers](https://github.com/K11MCH1/AdrenoToolsDrivers)


# 绕开dlopen的白名单机制

从Android 7 以后，谷歌不允许apk随意再dlopen so文件了。参考https://developer.android.com/about/versions/nougat/android-7.0-changes?hl=zh-cn#ndk

谷歌只允许通过链接的方式加载so，使用dlopen加载的so需要在一个白名单内才行。所以如果只是粗暴的替换so的名字，dlopen会在真机上直接失败。

这里主要参考了以下两个repo的实现

[darksylinc/AdrenoToolsTest](https://github.com/darksylinc/AdrenoToolsTest)

[bylaws/libadrenotools: A library for applying rootless Adreno GPU driver modifications/replacements](https://github.com/bylaws/libadrenotools)

需要hook一些系统的API来绕开Android Linker的白名单限制，实现外部so的加载。


# 结果

在我的小米8的神机上测试了一下毫无问题。这个855的神机，高通的官方vulkan驱动是不支持bindless之类的高级特性的。但是从下图可以看到，替换成Mesa逆向的freedreno驱动后，扩展列表里出现了`EXT_Descriptor_indexing`这个bindless需要的扩展。

![UE_Mobile_Load第三方Vulkan驱动-2025-05-25-12-28-08](https://img.blurredcode.com/img/UE_Mobile_Load第三方Vulkan驱动-2025-05-25-12-28-08.jpg?x-oss-process=style/compress)

![UE_Mobile_Load第三方Vulkan驱动-2025-05-25-12-28-45](https://img.blurredcode.com/img/UE_Mobile_Load第三方Vulkan驱动-2025-05-25-12-28-45.jpg?x-oss-process=style/compress)