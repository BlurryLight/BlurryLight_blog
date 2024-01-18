
---
title: "Nvrhi | Push Constant的处理"
date: 2024-01-18T22:41:41+08:00
draft: false
categories: [ "nvrhi"]
isCJKLanguage: true
slug: "b152921e"
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


# Push Constant

Push Constant是Vulkan的术语，用来指代一个小的buffer，可以被设置在管线上而无需绑定，Shader可以直接访问。
比较适合用来存一些易变而又不太大的数据。

在rhi的处理里，要封装一个Push Constant，最麻烦的是Dx11 / OpenGL，主要是上一代图形API没有暴露这个概念。只能用`Constant Buffer`去模拟。

在实现上:

| API  | Native Concept                 | Limit                        |
| ---- | ------------------------------ | ---------------------------- |
| Vk   | Push Constant                  | Spec要求最少128Bytes         |
| Dx12 | Root Signature(Root Constants) | 256Bytes                     |
| Dx11 | Constant Buffer                | 比较大，但是需要占据一个Slot |

# Push Constant在硬件上的映射

其实软件封装不是重要的，重要的是Push Constant在硬件上是怎么映射的，如此小的尺寸限制往往暗示着它在硬件上可能有专门的高速Cache。
翻了一下Reddit上也有人讨论:
> 参考：[How do Push Constants Map to Common Desktop Hardware : r/vulkan](https://www.reddit.com/r/vulkan/comments/udjhxb/how_do_push_constants_map_to_common_desktop/)


然后去翻了一下AMD的资料，

在GDC2016的[VULKAN FAST PATHS](https://gpuopen.com/wp-content/uploads/2016/03/VulkanFastPaths.pdf)中，PPT提到，在GCN架构上，Push Constants会被映射到 标量寄存器里,`SGPRs`，每当一个Wave被调度的时候，架构允许一次性载入16个标量(64B),

![nvrhi_push_constant-2024-01-18-22-51-53](https://img.blurredcode.com/img/nvrhi_push_constant-2024-01-18-22-51-53.png?x-oss-process=style/compress)
![nvrhi_push_constant-2024-01-18-22-52-49](https://img.blurredcode.com/img/nvrhi_push_constant-2024-01-18-22-52-49.png?x-oss-process=style/compress)

从PPT中可以看出:
- 每个Wave在Launch的时候可以高速加载16个4B的标量
- 有一些是给驱动用的，有一些是给Push Constant / Descriptor(指针)用，分配机制由驱动决定
- 当寄存器不够用的时候，会溢出到Buffer，这个Buffer我估计大概率也在L1 Cache上


这里的PPT没有提每个Wave可以用多少个寄存器，翻了一下[`AMD GCN1`的架构白皮书](https://www.techpowerup.com/gpu-specs/docs/amd-gcn1-architecture.pdf)。其中第五页的`SCALAR EXECUTION AND CONTROL FLOW`提到，

> Each compute unit has an **8KB** scalar register file that is divided into 512 entries for each SIMD. The scalar registers are shared by all 10 wavefronts on the SIMD; **a wavefront can allocate 112 user registers** and several registers are reserved for architectural state. The registers are 32-bits wide, and consecutive entries can be used to hold a 64-bit value. This is essential for wavefront control flow; for example, comparisons will generate a result for each of the 64 work-items in a wavefront.


- 1个CU最多执行10个Wave
- 1个CU共享8KB SGPR,也就是 2048个4字节数据
- 每个wave实际可以分配112个4字节数据, 448字节

找了个GCN显卡Rx580看了眼，Push Constant只有128Bytes。只能说GCN架构寄存器还是比较紧张的。
![nvrhi_push_constant-2024-01-18-23-04-25](https://img.blurredcode.com/img/nvrhi_push_constant-2024-01-18-23-04-25.png?x-oss-process=style/compress)

