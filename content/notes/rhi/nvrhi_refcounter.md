
---
title: "Nvrhi的RefCounter和侵入式计数"
date: 2023-11-04T17:12:30+08:00
draft: false
categories: [ "nvrhi"]
isCJKLanguage: true
slug: "e7f14935"
toc: true
mermaid: true
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


# RefCountPtr

介绍可以参考:
> 参考：[DirectX11--ComPtr智能指针 - X_Jun - 博客园](https://www.cnblogs.com/X-Jun/p/10189859.html)

DX的类都继承自IUnknown,除掉可以查询接口并转型以外，比较大特点是自带引用计数。
vulkan的资源需要手动管理引用计数，不用的时候归还回去。

统一这两种方式的方式是用侵入式Ptr。
仿造实现一个ComPtr。

另外一个好处是侵入式指针是zero-space，由于它不包含任何成员。

https://github.com/NVIDIAGameWorks/nvrhi/blob/556eb6e22e5c5a61f09b84ad26945d76b0172dfa/include/nvrhi/common/resource.h#L127

微软也有一个不包含Windows SDK专属功能的实现在`DirectX12 for WSL`的头文件里，https://github.com/microsoft/DirectX-Headers/blob/48f23952bc08a6dce0727339c07cedbc4797356c/include/wsl/wrladapter.h#L101
可以跨平台使用。

# IResource,RefCounter,RefCountPtr

情况来到nvrhi管理的资源，由于没有IUnknown可以用，所以需要自己造这么一套机制。

以D3D11Device为例，他的继承关系为

{{<mermaid>}}
graph TD
A[IResource]
B[IDevice]
C[RefCounter_IDevice_]
D[D3D11Device]
E[RefCountPtr_IDevice_]
A-->B
B-->C
C-->D
E-.->D
{{</mermaid>}}

其中`IResource`类似于`IUnknown`，主要的作用有三个

- 提供一个Noncopyable的功能，只允许通过指针间接管理，禁用了值语义
- 提供了AddRef/Release的两个接口

```cpp
class IResource {
protected:
  IResource() = default;
  virtual ~IResource() = default;

public:
  virtual uint32_t AddRef() = 0;
  virtual uint32_t Release() = 0;

private:
  // neither movable nor copyable
  IResource(const IResource &) = delete;
  IResource(const IResource &&) = delete;
  IResource &operator==(const IResource &) = delete;
  IResource &operator==(const IResource &&) = delete;
};
```

其中比较trick的部分是`RefCounter`的实现，它嵌入在整个继承链中

他的声明为
```cpp
template <class T> class RefCounter : public T {...}
```

而使用方法是
```cpp
class Device : public RefCounter<IDevice> {...}
```

## 一个不可行的思路

我一开始不太理解为什么要把RefCounter做进继承链里，认为这里使用多重继承的方式可能更好，RefCounter不需要是一个模板类

但是后来发现这个思路会构成菱形继承，不太好
- `RefCountPtr<IDevice>`需要`AddRef/Release`两个接口，意味着这两个接口要写到`IResource`上
- `IResource`如果要实现`AddRef/Release`，则他内部需要保存一个成员变量，有点破坏纯接口性。
- 如果还是把AddRef/Release的实现做到`RefCounter`上，那么就会构成菱形继承，这种情况是编译不过的 菱形继承一个纯虚接口，要求每个分支都要实现这些函数，并且调用的时候要指定分支。见 https://godbolt.org/z/bvoexadaW

```cpp
class Device : public RefCounter,IDevice  {...}
```

这样继承的类图为

{{<mermaid>}}
graph TD
A[IResource]
B[IDevice]
C[RefCounter]
D[D3D11Device]
E[RefCountPtr_IDevice_]
A-->B
A-->C
B-->D
C-->D
E-.->D
{{</mermaid>}}