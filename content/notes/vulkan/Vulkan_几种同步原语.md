
---
title: "Vulkan的几种同步原语"
date: 2026-08-29T22:25:45+08:00
draft: false
categories: [ "Mesa"]
isCJKLanguage: true
slug: "8ba7b114"
toc: true
mermaid: false
fancybox: false
blueprint: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
---


{{% spoiler "笔记栏文章声明"%}} 
    {{% notice warning %}}
    笔记栏所记录文章往往未经校对，或包含错误认识或偏颇观点，亦或采用只有自身能够理解的记录。
    {{% /notice %}}
{{% /spoiler %}}


VkTutorial给了一些介绍
> 参考：[Rendering and presentation - Vulkan Tutorial](https://vulkan-tutorial.com/Drawing_a_triangle/Drawing/Rendering_and_presentation#page_Synchronization)

Vulkan需要做显示同步，驱动不会帮忙做同步。
比如:
- 从SwapChain取得一张纹理
- (同步)
- Issue Drawcall
- (同步)
- Present

# WaitDeviceIdle

有点类似glFinish..等待一个Device的任务完成，通常用在退出上
VkResult vkDeviceWaitIdle( VkDevice device);

![edit-ab01af6764d249c5a3ab2d87d5cbdd73-2024-01-25-00-51-44](https://img.blurredcode.com/img/edit-ab01af6764d249c5a3ab2d87d5cbdd73-2024-01-25-00-51-44.png?x-oss-process=style/compress)

https://www.khronos.org/assets/uploads/developers/library/2016-vulkan-devday-uk/7-Keeping-your-GPU-fed.pdf

# Fence
主要用在GPU -> CPU 同步。
比如GPU做了某个事，CPU在等待，这个时候用Fence。

激发总是在Device，等待端总是在Host

```
VkResult vkWaitForFences(
    VkDevice                                    device,
    uint32_t                                    fenceCount,
    const VkFence*                              pFences,
    VkBool32                                    waitAll,
    uint64_t                                    timeout);
```

关于fence的一个典型用例,假如我们只用一个cmdbuf,每一帧绘制都要等待上一帧完成，那么会写出如下的主循环

```
void drawFrame() {
    vkWaitForFences(device, 1, &inFlightFence, VK_TRUE, UINT64_MAX); // 等待上一帧的Fence
	vkResetFences(mDevice, 1, &mInFlightFence); // 重置到unsignal
	....
	// 在QueueSubmit的时候可以指定一个fence，在这个提交的cmdbuf执行完后会signal这个fence
	VK_CHECK_RESULT(vkQueueSubmit(mGraphicsQueue, 1, &submitInfo, mInFlightFence));

	vkQueuePresentKHR(mPresentQueue, &presentInfo);
}
```

# Event

原始的几个原语之一，现在基本可以被timeline semaphore取代了。
Event可以用来做一些比较复杂的同步，可以做CPU / GPU，也可以做GPU / GPU同步。

一个Event只有signal / unsignal两种状态，然后可以在 cmdlist 或者在host signal或者激发。

Event感觉最适合用来做CPU -> GPU同步，作为GPU/GPU同步的话功能和PipelineBarrier有点重复。

所以各种同步都可以做：

- commandlist/ commandlist 同步： 前一个cmdlist vkCmdSetEvent， 后一个cmdlist vkCmdWaitEvents, 不允许跨Queue同步
- Queue / Host同步： cmdlist signal， host vkGetEventStatus + while
- Host / Host同步： vkSetEvent， host vkGetEventStatus（vkFence做不到这个，vkFence只能做 Queue->Host同步，但是用法也很糟心，只能在cmdlist submit的阶段触发，把 fence 作为参数传给vkQueueSubmit，然后  Host 端忙等待)
- Host / Queue同步： vkSetEvent， cmdlist vkCmdWaitEvents （意义不明，用处太少）

以上的场景总结下来，都不好用，所以没看到有太多的用处。。
在 CPU/GPU 同步场景，vkGetEventStatus 是非阻塞的，CPU 只有忙等待。而 Timeline Semaphore 可以阻塞在这里，GPU 可以 yield 去干其他事情。


# Semaphore
Semaphore用在GPU Queue之间同步，比如两个有先后依赖的queue submission进行同步。

有一些API可以带Semaphore，比如QueueSubmit，可以指定要等待哪些Semaphore和要signal 哪些semasphore

```cpp
	VkPipelineStageFlags waitStages[] = {VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT};//在 dst 提交管线的哪个阶段等待
    submitInfo.waitSemaphoreCount = 1;
    submitInfo.pWaitSemaphores = waitSemaphores;
    submitInfo.commandBufferCount = 1;
    submitInfo.pCommandBuffers = &mCommandBuffer;
    submitInfo.signalSemaphoreCount = 1;
    submitInfo.pSignalSemaphores = &mRenderFinishedSemaphore;
    submitInfo.pWaitDstStageMask = waitStages;
    VK_CHECK_RESULT(vkQueueSubmit(mGraphicsQueue, 1, &submitInfo, mInFlightFence));
	// 在Rendering和Present之间同步，注意看Semaphore
    presentInfo.waitSemaphoreCount = 1;
    presentInfo.pWaitSemaphores = &mRenderFinishedSemaphore;
	...
    vkQueuePresentKHR(mPresentQueue, &presentInfo);

```

> 参考：[VkPipelineStageFlagBits(3)](https://registry.khronos.org/vulkan/specs/1.3-extensions/man/html/VkPipelineStageFlagBits.html)

Vulkan的Semaphore支持很细粒度的同步，支持在管线的各个阶段同步。
这里的实例代码演示的一个在PS的Output阶段进行同步的例子。

- waitSemaphores是来自SwapChain,当从Swapchain的纹理准备好了，这个Semaphore会被signal
- 这里的Drawcall要求在`VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT`阶段等待`waitSemaphores`。也就是在第一次读，或者写color attachment(PS阶段)的时候，需要同步。

粗粒度的同步可以用 `VK_PIPELINE_STAGE_ALL_GRAPHICS_BIT,VK_PIPELINE_STAGE_ALL_COMMANDS_BIT`，表示在这个Queue的任意指令执行前要完成同步。

![Vulkan_几种同步原语-2026-08-29-22-55-33](https://img.blurredcode.com/img/Vulkan_几种同步原语-2026-08-29-22-55-33.png?x-oss-process=style/compress)


PresentInfo不需要指定Mask

## Timeline Semaphore

由扩展引入的同步原语，基本一次性统一了Fence/Semaphore/Event的功能。

https://www.khronos.org/assets/uploads/developers/library/2019-siggraph/Vulkan-04-Timeline-Semaphore-SIGGRAPH-Jul19.pdf

> 参考：[
Khronos Blog
 - The Khronos Group Inc](https://www.khronos.org/blog/vulkan-timeline-semaphores)

初略的看了一眼，
- 原始的Semaphore只有signal/unsignal两种状态，没法做出DX12那种，可以领先CPU好几帧的效果
- 可以统一Fence/Semaphore
- 可以不用每次用完要Reset(因为内部保存了计数器)
![Vulkan_几种同步原语-2026-08-29-22-55-52](https://img.blurredcode.com/img/Vulkan_几种同步原语-2026-08-29-22-55-52.png?x-oss-process=style/compress)
https://registry.khronos.org/vulkan/specs/1.3-extensions/man/html/vkSignalSemaphore.html
可以在主机端通过
- `vkSignalSemaphore`
- `vkWaitSemaphoresKHR`
- `vkGetSemaphoreCounterValueKHR`

来控制semaphore了，允许一定程度的CPU/GPU同步。

从设计上比较接近DX12的Fence了

```cpp
void PD::D3DApp::FlushCommandQueue() {
    mCurrentFence++;
    HR(mCommandQueue->Signal(mFence.Get(), mCurrentFence)); // 在队列里插入一个FenceSignal + 目标值
    if (mFence->GetCompletedValue() < mCurrentFence) {
        HANDLE eventHandle = CreateEventEx(nullptr, nullptr, 0, EVENT_ALL_ACCESS);
        HR(mFence->SetEventOnCompletion(mCurrentFence, eventHandle)); // 当Fence达到这个目标值的时候，广播Event
        WaitForSingleObject(eventHandle, INFINITE); // GameThread阻塞等待Event到达
        CloseHandle(eventHandle);
    }
}
```


![edit-ab01af6764d249c5a3ab2d87d5cbdd73-2023-08-12-01-09-43](https://img.blurredcode.com/img/edit-ab01af6764d249c5a3ab2d87d5cbdd73-2023-08-12-01-09-43.png?x-oss-process=style/compress)

从概念上还是直接的:
- Wait Semaphore的时候需要指定等待某个值
- Signal Semaphore的时候也需要指定修改Semaphore的值为什么值
- 当修改后的值大于等于Wait的值，同步就算完成的

所以这样能达到 One Semaphore for ALl的效果


# Barrier


> 参考：[从gles，vulkan到metal（二）-- 同步和内存_vulkan kgsl-CSDN博客](https://blog.csdn.net/leonwei/article/details/132764327)

## VkPipelineStageFlagBits 同步点的区别 (Execute Order)

- AllCommands 当前queue支持的任意操作前，有点类似于立刻同步吧
- TopOfPipe / BottomOfPipe也是纯粹的执行屏障，在这个点之前需要把某些操作执行完

可以精确控制Barrier发生的时机。
比如上一个Pass的RT输出作为下一个Pass的PS输入，那么同步点就是在下一个Pass的PS之前完成同步。

或者换一句话来说，stall the dstStageMask until the srcStageMask is finished.
那么这个Barrier的设置可以为
```
srvStageMask: eColorAttachmentOutput
dstStageMask: eFragmentShader
```


## Memory Access Flags的区别 (Memory Read/Write order)

主要是建立读写屏障。
还是举上一个例子，上一个Pass写，下一个Pass读，这里必须要建立读写屏障让写的副作用可见
```
srcAccessFlags: :eColorAttachmentRead | eColorAttachmentWrite  // RT要支持Blend
dstAccessFlags: eShaderRead
```


## ImageLayout (纹理独有)

Buffer不存在这个东西。主要是纹理比较复杂，涉及到OnTile,主存，驱动的问题。 
比如我们要开始读一张`system memory`的RT，那么必须要确保它已经从tile上全部写出到sysmem了。
并且根据我们是按UAV还是按Texture去读，驱动可以更优化的选择在system memory上纹理的存放形式。

所以还是举上一个例子
```
srvImageLayout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
dstImageLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
```

几个比较特殊的ImageLayout:
- VK_IMAGE_LAYOUT_UNDEFINED: 纹理刚创建出来会是这样，对这个layout的格式进行load操作会得到无意义的结果
- VK_IMAGE_LAYOUT_GENERAL: 支持任意情况访问，主要是给UAV用



# Synchronization2KHR

![edit-ab01af6764d249c5a3ab2d87d5cbdd73-2024-01-13-13-00-54](https://img.blurredcode.com/img/edit-ab01af6764d249c5a3ab2d87d5cbdd73-2024-01-13-13-00-54.png?x-oss-process=style/compress)

> 参考：[Vulkan® VK_KHR_synchronization2 extension support - AMD GPUOpen](https://gpuopen.com/vulkan-sync2-support/)

一个扩展，对于原始的core的很精细的同步做了一定的简化。

合并了一些flag，比如`VK_IMAGE_LAYOUT_READ_ONLY_OPTIMAL_KHR ` 等于 `VK_IMAGE_LAYOUT_DEPTH_READ_ONLY_OPTIMAL_KHR + VK_IMAGE_LAYOUT_STENCIL_READ_ONLY_OPTIMAL_KHR + SHADER_READ_ONLY + ...` 基本一切 read only 相关的控制

更新：9年19月2023日23:05:17
> 参考：[游戏引擎随笔 0x19：又论 Vulkan 中的同步 - 知乎](https://zhuanlan.zhihu.com/p/360806435)
>
TODO: 这是个大改动，需要仔细阅读。

## 重新考虑Barrier的结构体表示

之前是零零散散的分布在`MemoryBarrier`,`ImageMemoryBarrier`,`BufferMemoryBarrier`，`src/dstStageMask`

可以看下面的接口
```cpp

void vkCmdPipelineBarrier(
    VkCommandBuffer                             commandBuffer,
    VkPipelineStageFlags                        srcStageMask,
    VkPipelineStageFlags                        dstStageMask,
    VkDependencyFlags                           dependencyFlags,
    uint32_t                                    memoryBarrierCount,
    const VkMemoryBarrier*                      pMemoryBarriers,
    uint32_t                                    bufferMemoryBarrierCount,
    const VkBufferMemoryBarrier*                pBufferMemoryBarriers,
    uint32_t                                    imageMemoryBarrierCount,
    const VkImageMemoryBarrier*                 pImageMemoryBarriers);
```

新版的接口全部收拢到一个结构体里

```cpp
typedef struct VkDependencyInfo {
    VkStructureType                  sType;
    const void*                      pNext;
    VkDependencyFlags                dependencyFlags;
    uint32_t                         memoryBarrierCount;
    const VkMemoryBarrier2*          pMemoryBarriers;
    uint32_t                         bufferMemoryBarrierCount;
    const VkBufferMemoryBarrier2*    pBufferMemoryBarriers;
    uint32_t                         imageMemoryBarrierCount;
    const VkImageMemoryBarrier2*     pImageMemoryBarriers;
} VkDependencyInfo;
// Provided by VK_KHR_synchronization2
void vkCmdPipelineBarrier2KHR(
    VkCommandBuffer                             commandBuffer,
    const VkDependencyInfo*                     pDependencyInfo);
```

另外一个比较大的改动是，之前的 `srcStageMask`和`dstStageMask`是做到函数参数里的，不是跟着`barrier`结构体的。
比如我有两个buffer需要同步

- 第一个buffer是由compute shader产生，到第二个Pass的VS使用。
- 第2个buffer是由Copy操作产生，到第二个Pass的PS使用。

那么精细的同步应该是这样的
```cpp
buffer1:  srcPipelineStageMask: eComputeShader dstStageMask: eVertexShader
buffer2:  srcAccessFlags: eTransfer dstStageMask: eFragmentShader
```

在vkCmdPipelineBarrier里这个只能拆成两次调用。


## Access Flags改动

https://docs.vulkan.org/guide/latest/extensions/VK_KHR_synchronization2.html

Core的Flags是32bit，已经用尽了，所以这里改成了64bit。

许多StageFlags被拆的更细或者合并了。

![edit-ab01af6764d249c5a3ab2d87d5cbdd73-2024-01-13-13-21-46](https://img.blurredcode.com/img/edit-ab01af6764d249c5a3ab2d87d5cbdd73-2024-01-13-13-21-46.png?x-oss-process=style/compress)



## 引入了新的ImageLayout
- VK_IMAGE_LAYOUT_ATTACHMENT_OPTIMAL_KHR
- VK_IMAGE_LAYOUT_READ_ONLY_OPTIMAL_KHR

简化了做为RT要区分 `COLOR_ATTACHMENT` 和 `DEPTH_STENCIL_ATTACHMENT`的情况。
也简化了作为SRV要区分`SHADER_READ_ONLY` 和 `DEPTH_STENCIL_READ_ONLY` `DEPTH_READ_ONLY`的情况。


## 引入了新的vkQueueSubmit2KHR

1. 更好的支持Timeline Semaphore
   
之前要提交TimelineSemaphore需要额外嵌入一个pNext到VkTimelineSemaphoreSubmitInfo 

新版的vkQueueSubmit2KHR可以直接指定要signal的value。

2. vkQueueSubmit只有对`pWaitDstStageMask`的pipeline stage mask的控制，同时他还能signal semaphore，但是无法指定signal的时机。
只有在vkQueueSubmit执行完了以后才能signal。

新版的Submit可以指定Signal的时机。

```cpp
// Note this is allowing a stage to set the signal operation
VkSemaphoreSubmitInfoKHR signalSemaphoreSubmitInfo = {
    .semaphore = signalSemaphore,
    .value = 2, // replaces VkTimelineSemaphoreSubmitInfo
    .stageMask = VK_PIPELINE_STAGE_2_VERTEX_SHADER_BIT_KHR, // when to signal semaphore
    .deviceIndex = 0, // replaces VkDeviceGroupSubmitInfo
};
```