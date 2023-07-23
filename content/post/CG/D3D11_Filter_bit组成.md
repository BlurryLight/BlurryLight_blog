
---
title: "D3D11_Filter 枚举组装"
date: 2023-07-24T00:56:12+08:00
draft: false
categories: [ "CG"]
isCJKLanguage: true
slug: "203e2ba7"
toc: false
mermaid: false
fancybox: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
---

今天才注意到`D3D11_FILTER`的枚举的数字是由构造的规律的，头文件还提供了方便的构造宏。这里速记一下以备忘。

![D3D11_Filter_bit组成-2023-07-24-01-07-58](https://img.blurredcode.com/img/D3D11_Filter_bit组成-2023-07-24-01-07-58.png?x-oss-process=style/compress)

DX11的Sampler Filter目测由9个Bit组成。
- 前6个bit分别是 mip/mag/min, 每个占2个bit，实际上只会用一个bit(linear/point)
- 第7个bit是`ANISOTROPIC`的标记位，`Anisotropic`存在的时候，后6个bit只能为`010101`,即三个linear
- 8-9的2个bit用来表示`D3D11_FILTER_REDUCTION_TYPE `.

两个例子:
` D3D11_FILTER_MIN_MAG_MIP_LINEAR = 0x15,`,拆解为`0b00'0'01'01'01`，即`min/mag/mip`都是`linear`，`reduction type`是`standard`。

` D3D11_FILTER_MINIMUM_ANISOTROPIC = 0x155,`,拆解为`0b10'1'01'01'01`，即`min/mag/mip`都是`linear`，`anisotropic bit`为1， `reduction type`是`minimul(2)`。

d3d11.h提供两个宏来构建filter

```c
#define D3D11_ENCODE_BASIC_FILTER( min, mag, mip, reduction ) 
#define D3D11_ENCODE_ANISOTROPIC_FILTER( reduction )  
```

可以快速构造出想要的filter 标记，比如想要个最朴素的`linear sampler`，可以

```cpp
D3D11_SAMPLER_DESC samplerDesc = {};
samplerDesc.Filter = D3D11_ENCODE_BASIC_FILTER(D3D11_FILTER_TYPE_LINEAR, 
                    D3D11_FILTER_TYPE_LINEAR,
                    D3D11_FILTER_TYPE_LINEAR,
                    D3D11_FILTER_REDUCTION_TYPE_STANDARD);
//...

```


# reduction type


```cpp
typedef enum D3D11_FILTER_REDUCTION_TYPE {
  D3D11_FILTER_REDUCTION_TYPE_STANDARD = 0,
  D3D11_FILTER_REDUCTION_TYPE_COMPARISON = 1,
  D3D11_FILTER_REDUCTION_TYPE_MINIMUM = 2,
  D3D11_FILTER_REDUCTION_TYPE_MAXIMUM = 3
} ;
```

`Reduction Type`相关的sampler我好像只在Unity用过，用来做shadowmap的PCF,可以一次性采样2x2像素，需要和hlsl里的`SampleCmp/SampleCmpLevelZero`配合使用。
以下包含一点自己的猜测，具体是不是这样用还需要自己写一下。

这是利用了纹理采样一次是实际上采样2x2像素。
- `D3D11_FILTER_REDUCTION_TYPE_STANDARD`
- `D3D11_FILTER_REDUCTION_TYPE_COMPARISON` 感觉和shader里的samplecmp有关，用来做硬件pcf的时候有用，和shadowmap比较
- `D3D11_FILTER_REDUCTION_TYPE_MINIMUM/D3D11_FILTER_REDUCTION_TYPE_MAXIMUM`，返回四个像素的最小最大值。

原来的`linear`只是返回双线性插值的结果，通过调整`reduction type`的话可以返回`min/max`值。
不确定对`Nearest`的采样是否有效，不知道在Point采样的时候是返回`min/max`还是返回最近的像素，不过我猜是返回最近的像素，这几个`flag`应该只适合和`linear sample`搭配在一起用。

# Reference
> 参考：[D3D11_FILTER (d3d11.h) - Win32 apps | Microsoft Learn](https://learn.microsoft.com/en-us/windows/win32/api/d3d11/ne-d3d11-d3d11_filter)
> 参考：[D3D11_FILTER_REDUCTION_TYPE (d3d11.h) - Win32 apps | Microsoft Learn](https://learn.microsoft.com/en-us/windows/win32/api/d3d11/ne-d3d11-d3d11_filter_reduction_type)