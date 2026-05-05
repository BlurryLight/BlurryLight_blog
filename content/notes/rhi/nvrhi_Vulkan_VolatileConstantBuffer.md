
---
title: "Nvrhi|Vulkan的VolatileConstantBuffer设计"
date: 2026-05-05T19:44:48+08:00
draft: false
categories: [ "nvrhi"]
isCJKLanguage: true
slug: "d5158078"
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


# RenderPass


nvrhi的RenderPass从`SetGraphicsState`开启，在`CmdList->Close`时结束，
因此一个渲染Pass的典型示例如下：

```
CmdList->Open();
CmdList->WriteBuffer(...)
CmdList->ClearTexture(...)

CmdList->SetGraphicsState(...)// 打开RenderPass，执行大量的bind set绑定
CmdList->Draw(...);
CmdList->Close();

m_Device->ExecuteCmdList(..);
```

有很多API都只能在`RenderPass`外执行，最典型的是各种IO操作，比如读写Texture/Buffer/Query等，Vulkan API都要求在RenderPass外执行。

因此`SetGraphicsState`这个API的调用时机是有讲究的，最好在所有事情都做完之后再调用它来打开RenderPass。

RenderPass内允许的操作：

换绑BindSet（更换材质和纹理）和设置PushConstant是允许的：

```c
CmdBindDescriptorSet()
CmdPushConstant()
...
```


![edit-bc3ed7ea4ad642e4965daaebc17980c1-2026-04-12-22-26-08](https://img.blurredcode.com/img/edit-bc3ed7ea4ad642e4965daaebc17980c1-2026-04-12-22-26-08.png?x-oss-process=style/compress)




# WriteBuffer会中断Render Pass


一个典型的错误案例是在Draw时修改ConstantBuffer：
```cpp
CmdList->SetGraphicsState(xxx);
for Object in Objects:
    CmdList->WriteBuffer(...)  // Write Constant Buffer, such as MVP Matrix
    CmdList->Draw(...)
```

这样会导致每绘制一个物体都开关一次RenderPass。
![edit-bc3ed7ea4ad642e4965daaebc17980c1-2026-04-12-22-33-58](https://img.blurredcode.com/img/edit-bc3ed7ea4ad642e4965daaebc17980c1-2026-04-12-22-33-58.png?x-oss-process=style/compress)

正确的做法是把Model矩阵放到PushConstant或Volatile Constant Buffer里，这样就不需要每次都开关RenderPass了。

下面这段代码就是正确的做法：

```cpp
    dirhi::GraphicsState state;
    state.pipeline = m_BindlessPSO;
    state.framebuffer = TempFrameBuffer;
    state.bindings = {m_BindingSet, m_DescriptorTableManager->GetDescriptorTable()};
    state.viewport = m_View.GetViewportState();
    m_CommandList->SetGraphicsState(state);

    for (const auto &instance : m_Scene->GetSceneGraph()->GetMeshesInstances()) {
      const auto &mesh = instance->GetMeshInfo();

      for (size_t i = 0; i < mesh->geometries.size(); i++) {
        glm::i32vec2 constants{instance->GetInstanceIndex(), int(i)};
        // TODO: Write buffer will abort renderpass so it should not be here
        // m_CommandList->WriteBuffer(m_BindlessInstanceConstantsUBO, &constants, sizeof(constants), 0);
        // TODO: Write buffer will abort renderpass so it should not be here
        m_CommandList->SetPushConstants(&constants, sizeof(constants));
        dirhi::DrawArguments args;
        args.instanceCount = 1;
        args.vertexCount = mesh->geometries[i]->numIndices;
        m_CommandList->Draw(args);
      }
    }
```

对应的结果如下：

![edit-bc3ed7ea4ad642e4965daaebc17980c1-2026-04-12-22-35-46](https://img.blurredcode.com/img/edit-bc3ed7ea4ad642e4965daaebc17980c1-2026-04-12-22-35-46.png?x-oss-process=style/compress)



# VolatileConstantBuffer

这个概念在Vulkan下是有明确区分的：

- Constant Buffer → 对应Vulkan的Uniform Buffer
- VolatileConstantBuffer → 对应Vulkan的Uniform Buffer Dynamic

对应到API的具体行为，最大的区别在于：


## 绑定时的区别

1. 对于普通的ConstantBuffer，每次换绑需要切换不同的SRV（SRV可以View不同的Constant Buffer，也可以View一段Buffer的不同Range）。

比如想要从Constant Buffer的[0,256]区间换绑到[256,512]区间，必须创建两个不同的SRV和两个DescriptorSet，然后执行`bindDescriptorSets`绑定。

切换DescriptorSet是一个开销比较大的操作，尤其是一个DescriptorSet里包含许多描述符的情况下。


2. VolatileConstantBuffer是nvrhi发明出来的概念，但底层的Uniform Buffer Dynamic在API层面也有特殊的行为。

再举上面的例子：
DynamicUniformBuffer允许通过`bindDescriptorSets`这个API的最后一个参数`dynamicOffsets`直接指定偏移值，而无需切换DescriptorSet。

想要从Dynamic Constant Buffer的[0,256]区间换绑到[256,512]区间，只需要创建1个DescriptorSet，并对它执行两次`bindDescriptorSets`，仅偏移值不同即可。


## HOST_COHERENT 还是 FlushMappedMemoryRanges 

一般来说，`DynamicUniformBuffer`是CPU经常需要写入的，而且由于不想打断RenderPass，通常通过`map`出来的指针进行读写。
因此会采用`HostCoherent`内存（`VK_MEMORY_PROPERTY_HOST_COHERENT_BIT`）来让驱动帮忙同步。

但nvrhi这里采用的是`vkFlushMappedMemoryRanges`和`vkInvalidateMappedMemoryRanges`来手动管理，每次`CmdList`关闭时都会手动调用`vkFlushMappedMemoryRanges`来确保所有的Dynamic Uniform Buffer已经更新。

![edit-bc3ed7ea4ad642e4965daaebc17980c1-2026-04-12-22-53-11](https://img.blurredcode.com/img/edit-bc3ed7ea4ad642e4965daaebc17980c1-2026-04-12-22-53-11.png?x-oss-process=style/compress)

![edit-bc3ed7ea4ad642e4965daaebc17980c1-2026-04-12-22-55-14](https://img.blurredcode.com/img/edit-bc3ed7ea4ad642e4965daaebc17980c1-2026-04-12-22-55-14.png?x-oss-process=style/compress)


AI给的建议:

```
除非你正在编写高性能驱动程序或处理极端的吞吐量瓶颈，否则 HOST_COHERENT_BIT 带来的便利性通常超过了其微小的性能差异。而在移动端（如 Android 开发），务必关注 nonCoherentAtomSize，避免因对齐问题导致的同步失败。
```