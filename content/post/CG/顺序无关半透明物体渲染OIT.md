
---
title: "顺序无关半透明物体渲染OIT"
date: 2022-05-07T23:54:19+08:00
draft: false
# tags: [ "" ]
categories: [ "CG"]
# keywords: [ ""]
# lastmod: 2022-05-07T23:54:19+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "4c17b61d"
toc: false
mermaid: false
# latex support
katex: true
markup: mmark
mmarktoc: true
---

# 半透明物体和深度

正确绘制半透明物体渲染需要技巧。
一种顺序相关的渲染方式是
- 渲染所有不透明物体
- 关闭深度写入
- 排序所有透明物体
- 从后到前渲染透明物体
- 打开深度写入

渲染半透明物体需要考虑深度测试，因为这些物体可能被不透明物体遮挡。所以要先渲染不透明物体，然后再渲染半透明物体。
但是在渲染时需要关闭深度写入。
在能够完美按照从后到前顺序渲染的时候，实际上是实现了朴素版本的画家算法，所以写zbuffer没啥意义。
但是从后向前渲染的时候如果出现半透明物体交叉的情况，这种情况是排序不了的，会出现后渲染的物体一部分像素被剔除，关闭深度写入能避免这个问题(但是在做后处理的时候会碰见其他问题，比如DOF这种依赖深度的后处理会对半透明物体，也有可能混合颜色会出问题)。


# OIT

https://jcgt.org/published/0002/02/09/paper.pdf

单次blend的公式可以写作如下，其中$$C_1$$是`SRC`的像素颜色和alpha通道值$$\alpha_1$$预相乘的结果。

$$
C_f = C_1 + (1 - \alpha_1)C_0
$$

上面这个公式递推一下，可以把多个堆叠的半透明物体的公式写出来

$$
C_{f}=\left[C_{n}+\left(1-\alpha_{n}\right) \cdots\left[C_{2}+\left(1-\alpha_{2}\right)\left[C_{1}+\left(1-\alpha_{1}\right) C_{0}\right]\right] \cdots\right]
$$

对于这个公式，没有可以展开化简的手段(类似于光线追踪的递推形式)。
想要解析的解它要么通过ray tracing的方式一步到位，要么就要一层一层的解(back to front render，或者depth peeling的方式)。

## Depth Peeling

~~**我觉得我还没有真正理解它。**~~

~~本来想自己实现一下没想到翻车了0v0，实现了`Depth Peeling`的效果，但是混合有Bug，没找到原因。~~
~~正确的工程可以看[FrontToBackPeeling](https://github.com/bagobor/opengl33_dev_cookbook_2013/tree/master/Chapter6/FrontToBackPeeling)~~

一个用Unity正确实现的工程可以见:[depthPeeling-fork](https://github.com/BlurryLight/depthPeeling-fork)。

大概过程就跟剥洋葱一样，需要重复渲染场景很多次，没有太多的实用价值。

一种naive的思路可以是：
0. 全程关闭blend，最后一个pass手动实现混合，新建一个`vector<Texture>`。
1. 首先渲染整个场景，获得所有的半透明物体的最表面的一层，记录渲染的color和深度到纹理。
2. 渲染整个场景，将渲染过程中小于等于上一个Pass的深度的像素`discard`掉，渲染上一次渲染的场景后面的物体，并记录颜色和alpha值。
3. 重复上述过程，直到达到预设的最大剥离次数或者没有半透明物体可以渲染。
4. 做一次全屏后处理，从后到前依次混合每一次混合的纹理，混合公式可以采用默认的`SrcAlpha, OneMinusSrcAlpha`混合。也可以根据`Nvidia`的[实现笔记 Page6](https://my.eng.utah.edu/~cs5610/handouts/DualDepthPeeling.pdf)所记录的公式从前往后混合。

一种更复杂的策略是每剥离一次就混合一次，这样不用暂存中间纹理结果。如下图所示。

{{< figure src="https://img.blurredcode.com/img/edit-bb6690fb71fe44bfa6f1e10014e6b767-2022-05-07-23-44-22.png?x-oss-process=style/compress" width="70%" caption="最开始的Pass">}}


{{< figure src="https://img.blurredcode.com/img/edit-bb6690fb71fe44bfa6f1e10014e6b767-2022-05-07-23-52-01.png?x-oss-process=style/compress" width="70%" caption="后续剥离过程">}}
## Weighted Blended OIT

`Weighted Blended OIT`是一种近似解法，其主要是寻找以上的公式的一个近似解。

Meshkin[2007]的近似解法是
$$
C_{f}=\left(\sum_{i=1}^{n} C_{i}\right)+C_{0}\left(1-\sum_{i=1}^{n} \alpha_{i}\right)
$$

只有在$$\alpha$$很小的时候才比较接近。(最右边是真值，最左边是乱序渲染)

![edit-bb6690fb71fe44bfa6f1e10014e6b767-2022-04-18-00-35-20](https://img.blurredcode.com/img/edit-bb6690fb71fe44bfa6f1e10014e6b767-2022-04-18-00-35-20.png?x-oss-process=style/compress)


### 实现

本文的近似是
$$
C_{f}=\frac{\sum_{i=1}^{n} C_{i} \cdot w\left(z_{i}, \alpha_{i}\right)}{\sum_{i=1}^{n} \alpha_{i} \cdot w\left(z_{i}, \alpha_{i}\right)}\left(1-\prod_{i=1}^{n}\left(1-\alpha_{i}\right)\right)+C_{0} \prod_{i=1}^{n}\left(1-\alpha_{i}\right)
$$

主要是权重函数$$w(z,\alpha_i)$$考虑了距离因素$$z$$。
一个直观的理解在相同的$$\alpha$$的下，距离相机越近的透明像素，应该贡献更多的颜色值。


$$w$$函数大致呈现下降趋势。
![edit-bb6690fb71fe44bfa6f1e10014e6b767-2022-04-18-00-38-27](https://img.blurredcode.com/img/edit-bb6690fb71fe44bfa6f1e10014e6b767-2022-04-18-00-38-27.png?x-oss-process=style/compress)

$$w$$函数的选取直接决定了最后表现，需要反复调。

作者给出了一些还行的`W`函数，其中$$z$$是view-space下的坐标(<=500)不适用于大场景，$$d(z)$$是ndc下的坐标。
![edit-bb6690fb71fe44bfa6f1e10014e6b767-2022-04-18-00-39-32](https://img.blurredcode.com/img/edit-bb6690fb71fe44bfa6f1e10014e6b767-2022-04-18-00-39-32.png?x-oss-process=style/compress)

`w`的数值可能很大(3000+)，所以至少需要一个`RGBA16`的纹理。
还需要另外一个`R8`纹理以存放所有累乘的$$1 - \alpha$$。

Nvidia的[实现工程](https://docs.nvidia.com/gameworks/content/gameworkslibrary/graphicssamples/opengl_samples/weightedblendedoitsample.htm)里简短几句话介绍了WBOIT的实现关键:

{{% notice info %}}
Weighted Blended OIT is a fast approximation of the depth peeling result, in a single geometry pass.
In this geometry pass, the fragments are blended into a Frame Buffer Object with 2 draw buffers. 
In the first draw buffer (with format RGBA16F),

- RGB stores `Sum[FragColor.rgb * FragColor.a * Weight(FragDepth)]`
- Alpha stores `Sum[FragColor.a * Weight(FragDepth)]`

In the second draw buffer (with format R8),
- R stores `Product[1.0 - FragColor.a]`
{{% /notice %}}

具体的实现看https://github.com/BlurryLight/DiRenderLab/tree/main/examples/oit
和
https://github.com/BlurryLight/DiRenderLab/blob/712cc8f6f8ec78d61faa842bd13a37d17cc7ca9d/resources/shaders/oit/oit_transparent.frag#L32

注意要利用`FBO`的`BlendFunc`以调整不同的值是累加还是累乘(很巧妙）。

# Reference

- [LearnOpenGL Weighted-Blended OIT](https://learnopengl.com/Guest-Articles/2020/OIT/Weighted-Blended)
- [Nvidia Weighted Blended OIT Sample](https://docs.nvidia.com/gameworks/content/gameworkslibrary/graphicssamples/opengl_samples/weightedblendedoitsample.htm)
- [Weighted Blended Order-Independent Transparency](https://jcgt.org/published/0002/02/09/paper.pdf)