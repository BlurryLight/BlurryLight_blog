
---
title: "一个RenderDoc调试VK_KHR_synchronization2崩溃的问题"
date: 2024-01-14T17:13:38+08:00
draft: false
categories: [ "CG"]
isCJKLanguage: true
slug: "e7923477"
toc: false
mermaid: false
fancybox: false
blueprint: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
---

![RenderDoc_vulkan_sync2扩展崩溃-2024-01-14-17-15-18](https://img.blurredcode.com/img/RenderDoc_vulkan_sync2扩展崩溃-2024-01-14-17-15-18.png?x-oss-process=style/compress)

把有问题的RDC File放在这里
https://drive.google.com/file/d/1XCYulZg0esli__yX0cRjsvjCKrAeMpJo/view?usp=sharing

这两天在研究KHR Sync2的barrier写法，并且尝试从Core的vkCmdPipelineBarrier的写法切换到Sync2里的写法。好处是把`StageFlags`也收拢到了每个barrier的表示里。

举个例子
比如我有两个buffer需要同步

- 第一个buffer是由compute shader产生，到第二个Pass的VS使用。
- 第2个buffer是由Copy操作产生，到第二个Pass的PS使用。

那么同步的stageFlags应该是这样的
```cpp
buffer1:  srcStageMask: eComputeShader dstStageMask: eVertexShader
buffer2:  srcStageMask: eTransfer      dstStageMask: eFragmentShader
```

在vkCmdPipelineBarrier里这个只能拆成两次调用，而在sync2里可以一次调用就完成，写法更简洁。

# 崩溃的原因

问题在调试过程中发现一旦我使用Sync2的写法，RenderDoc就会崩溃。一度让我怀疑是不是RenderDoc不支持Sync2..但是这是一个已经进了Core的扩展(1.3)，而且从nvidia的nvrhi用截帧抓了一下也是能正常的。更奇怪的是ValidationLayer也不报错。


最后仔细翻了一下，问题的源头在于我的`Device`创建的时候没有启用`synchronization2`特性..

重新翻了一下Spec，才发现一个扩展进了Core不代表这个扩展所有硬件都支持..也不代表进了Core就是默认启用的..

比如我们以同样进了core的 `buffer_device_address`来举例，Spec只说如果这个扩展不支持的话，那么这个**特性**是否支持是可选的..

绕个圈子来说，如果这个扩展支持，那么这个特性也是支持的，但是需要通过`VkPhysicalDeviceVulkan12Features`来启用。

![edit-2358f8b8dff54793857ae3c27b4d77f7-2024-01-13-20-38-32](https://img.blurredcode.com/img/edit-2358f8b8dff54793857ae3c27b4d77f7-2024-01-13-20-38-32.png?x-oss-process=style/compress)


因此修改方法也比较简单:

如果我们使用的版本低于1.3 
- 需要先查询 KHR_synchronization2 扩展
- 再查询 VkPhysicalDeviceSynchronization2Features 特性是否启用
- 如果启用了，那么在填充 VkDeviceCreateInfo的时候需要把 VkPhysicalDeviceSynchronization2Features 作为pNext传入

如果大于1.3:
- 查询 VkPhysicalDeviceVulkan13Features里是否有synchronization2
- 创建DeviceCreateInfo里传入的 VkPhysicalDeviceVulkan13Features 一定要确保 sync2的标记为true