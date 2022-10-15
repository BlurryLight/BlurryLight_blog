
---
title: "HBAO的Unity实现杂记"
date: 2022-10-15T22:13:09+08:00
draft: false
categories: [ "CG"]
isCJKLanguage: true
slug: "e9d23ec7"
toc: false
mermaid: false
fancybox: true
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
---

## HBAO实现杂记

主要参考原始的[Image-Space Horizon-Based Ambient Occlusion.pdf](https://developer.download.nvidia.com/presentations/2008/SIGGRAPH/HBAO_SIG08b.pdf)。
主要思想是以在半圆内朝着不同的方向步进，步进的方向越崎岖，则最后的AO值越大。
核心公式在第12页，

![HBAO的Unity实现杂记-2022-10-15-22-51-41](https://img.blurredcode.com/img/HBAO的Unity实现杂记-2022-10-15-22-51-41.png?x-oss-process=style/compress)

### Tangent Bias

![edit-a72f1521e2194ba8acb7071e7d881b00-2022-10-13-16-53-45](https://img.blurredcode.com/img/edit-a72f1521e2194ba8acb7071e7d881b00-2022-10-13-16-53-45.png?x-oss-process=style/compress)

为了减少步进的表面不平带来的jitter问题，加入bias。

在一些几何体面数不够的时候(本来应该是一个光滑的曲面)，会在三角面片的接缝出现一些AO的计算。
因此需要一个Bias参数用来忽略一些较小的AO值(通过抬升Tangent向量实现)。

要获得每个像素的切线方向只有估算。在估算某个像素对应的位置的切线时候，我们只有用屏幕空间周围的像素来估算。
PPT里用的是`dpdx,dpdy`的方式进行估计，其思想类似于函数求导时的有限差分方法。
测试了一下，使用对称差分的方式获得的效果比较好。代码类似于
```c
float3 tangent =
    FetchViewPos(input.uv + dir * _MainTex_TexelSize.xy) -
    FetchViewPos(input.uv - dir * _MainTex_TexelSize.xy);
tangent = normalize(tangent);
```


### 距离加权采样

为了减少由于半球采样带来的不连续的问题(由于半径限制，部分采样点在A像素点能采样到，B像素点采样不到，导致这两个像素点计算的AO值会有明显的差异)，加入距离衰减使得出现在A,B两个像素的AO值获得一个柔滑的过度。

![HBAO的Unity实现杂记-2022-10-15-23-07-52](https://img.blurredcode.com/img/HBAO的Unity实现杂记-2022-10-15-23-07-52.png?x-oss-process=style/compress)

观察图中的公式，假设权重`W(S) = 1`恒定为1，那么累加的加权后的`WAO`等于

`AO(S2) - AO(S1) = sin(S2) - sint`。

逐步加权采样的实现要点:
1. 需要有一个Top变量追踪当前最大的`sin(theta) - sin(Tanget)`，初始化为0
2. 每个步进只计算比当前AO大的点
3. 越靠近半圆的边界，对AO的贡献越低

```c
inline float fullAO(float3 pos, float3 stepPos, float3 normal,float3 tangent ,inout float top)
{
    float3 h = stepPos - pos;
    float3 h_dir = normalize(h);
    // 计算采样点的sin
    float tanH = ViewPosTangent(h_dir);
    float sinH = TanToSin(tanH);
    // 计算Tanget的sin
    float tanT = BiasedViewPosTanget(tangent,_AOBias);
    float sinT = TanToSin(tanT);

    // 当前采样的AO值
    float sinBlock = sinH - sinT; 
    // 如果低于之前的采样点，就是0，如果比之前的采样点大，则计算它的贡献(但是要算上距离衰减)
    float diff = max(sinBlock - top, 0);
    top = max(sinBlock, top);

    // 计算采样点距离采样中心的距离，衰减为 1 - d^2/r^2
    float dist = length(h);
    return diff * FallOff(dist);
}
```
# 实现上的差异

1. PPT第46页提到的`Snap UV`在代码中似乎会引入画面出现某种奇怪的花纹，也许是我没实现正确。使用`Bilinear Sampling`没有看到肉眼可见的瑕疵，所以没有做。
2. PPT第27页提到的`DepthAware Blur`没有做，换成了简单的Gaussian Blur，会造成边缘有点模糊。


实现效果见下图，图片点击可放大
{{<fancybox URL="https://img.blurredcode.com/img/HBAO的Unity实现杂记-2022-10-15-22-45-17.png?x-oss-process=style/compress" Caption="全分辨率下未模糊AO图" >}}


{{<fancybox URL="https://img.blurredcode.com/img/HBAO的Unity实现杂记-2022-10-15-23-13-29.png?x-oss-process=style/compress" Caption="狮子头细节AO" >}}

# Reference
1. https://github.com/scanberg/hbao/blob/master/resources/shaders/hbao_frag.glsl
2. https://github.com/shadylyf321/HBAO

# 附录
Gist: https://gist.github.com/BlurryLight/b351cd29a21399681df5a1ac66c0b3d3
<script src="https://gist.github.com/BlurryLight/b351cd29a21399681df5a1ac66c0b3d3.js"></script>
