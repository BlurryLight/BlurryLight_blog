
---
title: "Donut | 有意思的Bent Normal"
date: 2025-08-05T22:38:28+08:00
draft: false
categories: [ "nvrhi"]
isCJKLanguage: true
slug: "f0273e37"
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



# bent normal

https://github.com/NVIDIA-RTX/Donut/blob/6d3855607bd3b4e06f9fa64b659da7dcaabff11b/include/donut/shaders/utils.hlsli#L139

donut框架里，着色的时候有一个有意思的函数是`GetBentNormal`(即抄即用),研究了一下


```cpp
// Smart bent normal for ray tracing
// See appendix A.3 in https://arxiv.org/pdf/1705.01263.pdf
float3 getBentNormal(float3 geometryNormal, float3 shadingNormal, float3 viewDirection)
{
    // Flip the normal in case we're looking at the geometry from its back side
    if (dot(geometryNormal, viewDirection) > 0)
    {
        geometryNormal = -geometryNormal;
        shadingNormal = -shadingNormal;
    }

    // Specular reflection in shading normal
    float3 R = reflect(viewDirection, shadingNormal);
    float a = dot(geometryNormal, R);
    if (a < 0) // Perturb normal
    {
        float b = max(0.001, dot(shadingNormal, geometryNormal));
        return normalize(-viewDirection + normalize(R - shadingNormal * a / b));
    }

    return shadingNormal;
}
```


原始论文在这里

[The Iray Light Transport Simulation and Rendering System - 1705.01263v1.pdf](https://arxiv.org/pdf/1705.01263)


![edit-e64198f4979049488d8a6842070d3531-2025-08-05-22-30-04](https://img.blurredcode.com/img/edit-e64198f4979049488d8a6842070d3531-2025-08-05-22-30-04.png?x-oss-process=style/compress)


论文里给了一个2D case的情况:

实际上着色时表面的shading normal和三角面的flat normal往往存在较大差距(尤其是还有normal map扰动的情况下)。如果ray tracing依靠shading normal来计算反射，那么就很容易形成自相交(见图3的情况)。

这个论文提出了一种巧妙的方式，通过计算相似三角形的方式来计算一个修正向量来强行把自相交的反射方向给掰到和几何面平行(这样就不会自相交了)。
然后通过入射方向和掰过的反射向量方就可以获取一个新的修正过的方向，就是Bent Normal



效果图如下，注意没有掰法线之前有的面会形成自相交导致的黑色斑块。

![edit-e64198f4979049488d8a6842070d3531-2025-08-05-22-35-33](https://img.blurredcode.com/img/edit-e64198f4979049488d8a6842070d3531-2025-08-05-22-35-33.png)