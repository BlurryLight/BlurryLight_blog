
---
title: "为什么延迟渲染和MSAA不搭"
date: 2022-02-04T15:10:42+08:00
draft: false
# tags: [ "" ]
categories: [ "默认分类"]
# keywords: [ ""]
# lastmod: 2022-02-04T15:10:42+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "5b548f07"
toc: false
# latex support
katex: true
markup: mmark
mmarktoc: true
---

# MSAA与延迟渲染

翻了下之前在Games101上写的MSAA的实现，发现错的离谱(逃。
改了一下以后顺手就把MSAA和延迟渲染这部分写了。


## MSAA的原理

![MSAA](https://img.blurredcode.com/img/202202041420157.jpg?x-oss-process=style/compress)

MSAA的buffer里保存的是着色中心点的颜色，buffer的大小为屏幕大小乘以子`sample`的数量，其需要保存$$n$$个`sample`的深度和`sample`的颜色。
其渲染流程如如下
- 假设先渲染蓝色三角形，后渲染黄色三角形
- 渲染蓝色三角形时，先计算像素中心点着色，计算结果为紫色。对四个采样点进行深度测试和测试是否在三角形内。下面两个`sample`通过测试，所以把紫色复制到这两个`sample`的buf上。
- 渲染黄色三角形，进行同样的测试，黄色三角形只有一个采样点位于三角形内。
- 所有的三角形渲染完成后，对所有的像素的子`sample`的缓冲区进行`resolve`，常见的`resolve`方法是取平均。

## GBuffer与MSAA

MSAA的子`sample`保存的颜色是像素中心点的颜色，其`resolve`阶段在所有三角形的`fshader`运行着色以后进行。

延迟渲染的第二个阶段已经丢失了几何信息(其实际是渲染一个`quad`或者一个大三角形)，所以在延迟渲染的第二个阶段运行MSAA是无意义的。

MSAA运用到延迟渲染的第一个阶段是可以的，目前看到两种方法。
### Per-Sample Shading

在`Gbuffer`中我们往往还要保存深度、法线等信息，对这些信息`resolve`是无意义的，比如下图。同一个像素的4个子`sample`有不同的法线，其加权出来的法线与单独计算光照后再加权得出的结果是不一样的。
![](https://img.blurredcode.com/img/202202041454322.png?x-oss-process=style/compress)

`Shader X7`里的 `Deferred Shading with Multisampling Anti-Aliasing in
DirectX 10`文章采用了`multisampled texture`来保存所有的GBuffer，在`fshader`里对每个`sample`而不是像素进行着色，最后对光照结果进行`resolve`。为了进一步提高效率，考虑到MSAA对三角形内部是不起作用的，所以用了额外的一个`stencil buffer`保存三角形的边缘信息，只对边缘做`MSAA`。

优点：
- 正确的MSAA结果

缺点：
- `GBuffer`膨胀为N倍，N为`Sample`数量
- 不考虑边缘检测的情况下，`Fshader`运行次数膨胀为N倍，考虑的话，需要额外一张`Stencil Texture`
- 需要API提供Per-Sample Shading支持(DX10.0以上)

### Albedo Resolve

从[延迟渲染与MSAA的那些事](https://zhuanlan.zhihu.com/p/135444145)看来的，大概意思是在保存GBuffer的时候只考虑`Albedo`这张纹理采用MSAA，因为对法线和深度进行MSAA是无意义的。在着色阶段的时候采用的是`resolve`以后的`Albedo`，其他正常着色。

思考了一下，感觉不太对。把`resolve`简写为$$R$$，把`Shading`过程简写为$$S$$。MSAA是在着色阶段完成以后进行`resolve`，其过程不等于对一个`resolved`的变量进行着色,和逻辑和上面的法线例子比较类似。并且由于MRT不能单独对某张纹理设置MSAA，所以要渲染两个Pass分别记录`Albedo`和其他`Gbuffer`，`drawcall`数得翻倍。

$$
R(S(Albedo)) \neq S(R(Albedo))
$$

优点：
没看出来有什么优点

缺点：
- 计算结果大概率边缘会有瑕疵
- `drawcall`数翻倍

# 总结

MSAA作为一种几何抗锯齿的方法(其只是增加了对几何的采样，没有额外的光照计算)，对阴影的闪烁或者PBR中容易出现的高光闪烁是不起作用的。在延迟渲染中应用MSAA是可能的，但是代价较高，尤其是带宽开销，效果又欠佳，所以不如用TAA。

# Reference
- [Multisample Anti-Aliasing](http://diaryofagraphicsprogrammer.blogspot.com/2009/06/multisample-anti-aliasing.html)
- Shader X7 Part II 2.8  Deferred Shading with Multisampling Anti-Aliasing in
DirectX 10
- [延迟渲染与MSAA的那些事](https://zhuanlan.zhihu.com/p/135444145)