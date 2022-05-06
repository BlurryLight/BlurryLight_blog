
---
title: "Unity TAA实现杂记"
date: 2022-05-06T18:21:10+08:00
draft: false
# tags: [ "" ]
categories: [ "CG"]
# keywords: [ ""]
# lastmod: 2022-05-06T18:21:10+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "9f1444db"
toc: false
mermaid: false
# latex support
katex: true
markup: mmark
mmarktoc: true
---

# TAA

主要理论参考资料可以参考`Inside`的分享[GDC Vault - Temporal Reprojection Anti-Aliasing in INSIDE](https://www.gdcvault.com/play/1022970/Temporal-Reprojection-Anti-Aliasing-in)，主要实现代码可以参考Unity的[Post Processing v2的实现](https://github.com/Unity-Technologies/PostProcessing/blob/v2/PostProcessing/Runtime/Effects/TemporalAntialiasing.cs)，相较于Inside的实现其更加干净，而且更容易看懂。
## 框架
![edit-84c9ebe0655e44b9a7e08e01ff355f1f-2022-05-06-17-04-14](https://img.blurredcode.com/img/edit-84c9ebe0655e44b9a7e08e01ff355f1f-2022-05-06-17-04-14.png?x-oss-process=style/compress)

几个注意的点:
1. 输入的所有数据都是jitter后的
2. `unjitter`只发生在混合阶段，用以采样`_MainTex`，也即是jitter后的color buf。为了采样`unjitter`的数据，需要调整uv坐标。
3. `reproj`是找到当前帧的像素在之前帧的位置，有一些细节要处理(depth dilate)

## Jitter 视椎体

要注意的点是`Jitter`实际上是亚像素级别的轻微偏移裁剪近平面，形成`Temporal`上的超采样。

```C#
		_Jitter = new Vector2(
			2.0f * (HaltonSequence[Index].x - 0.5f) / camera.pixelWidth,
			2.0f * (HaltonSequence[Index].y - 0.5f) / camera.pixelHeight);
		_Jitter *= JitterScale;
		// Unity的矩阵是row-major
		// matrix[x,y]指的是x row, y col
		proj.m02 += _Jitter.x;
		proj.m12 += _Jitter.y;
```
把`_Jitter`分量放在`proj.m02`和`proj.m03`的位置，在齐次坐标系下其会成为`(_jitter.x * z_v) ,(_jitter.y * z_v)`,`z_v`是`view-space z`坐标。
经过透视除法后，z_v分量被消去。所剩下的在NDC坐标系下的偏移就是`_jitter.xy`，所以`_jitter.xy`设置为`[-1,1]`偏移就行。

## Motion Vectors的计算

`Motion Vectors`表示了同一个顶点在前后两帧中被渲染到`screenspace`的`uv`坐标之差。
不考虑jitter情况下，计算`Motion Vectors`可以划分为三种情况:
1. 相机不动，场景无运动物体: 不需要考虑`Motion Vectors`，加点jitter出来的结果直接颜色混合就行。
2. 镜头在动，场景不动：在冯乐乐的书籍里讨论了在这种场景下计算Motion Blur的方法。由于没有物体的运动，可以不通过额外的Pass(利用cur_vp矩阵和prev_vp矩阵)简单计算Motion Vector。
3. 镜头在动，场景在动：需要保存上一帧的mvp和这一帧的mvp，上一帧的uv信息可以通过上一帧MVP得到，当前帧的UV信息可以通过当前帧的MVP得到。需要额外一个Pass渲染整个场景的物体，以计算每个物体的Motion Vectors并写入到`R16G16_TYPELESS`纹理中。精细化的处理可以单独处理动态物体，以降低Overdraw。
   
写成伪代码可以写作
```
    newNDCPos = projection * view * translation * position;
    preNDCPos = projection * previousView * previousTranslation * position;
    new_uv = 0.5 * newNDCPos.xy + 0.5;
    pre_uv = 0.5 * preNDCPos.xy + 0.5;
    motion_vector = new_uv - pre_uv;
```

Unity的默认管线提供了`DepthTextureMode.MotionVectors`选项以帮助计算`Motion Vectors`，但是对于`Instance`的物体还是需要手动在Shader里计算Motion Vectors。
具体的代码实现可以看[Motion.cginc](https://github.com/BlurryLight/InstancedMotionVector/blob/4128fe5379ecd8734c5f65fe735bd25bfb11aae1/Assets/InstancedMotionVector/Motion.cginc#L20)
 
## Reprojection

采样Motion Vectors纹理获得`Motion Vectors`，即可获得上一帧的，也即在`_HistoryBuffer`纹理上的采样坐标。
伪代码可写作
```c
float2 HistoryUV = i.texcoord - Motion;
float4 HistoryColor = _HistoryTex.Sample(sampler_LinearClamp, HistoryUV);
```

## 对抗Artifacts

### Ghosting
鬼影，又被称为history mismatch，是指在重投影的过程中(Reproj)，当前`pixel`的像素被重投影到上一帧的`color buffer`寻找其历史着色，但是由于几何关系遮挡等问题重投影的像素并非是这一个像素的历史像素，被称为`history mismatch`。

![edit-84c9ebe0655e44b9a7e08e01ff355f1f-2022-05-06-17-04-31](https://img.blurredcode.com/img/edit-84c9ebe0655e44b9a7e08e01ff355f1f-2022-05-06-17-04-31.png?x-oss-process=style/compress)

对抗`Ghosting`主要靠检测颜色，如果一个像素重投影采样历史帧的颜色和当前帧的颜色相差很大，可以充分认为发生了`history mismatch`。
一种可行的方式是采样当前像素在当前帧周围的 $$ 3\times3 $$ 邻居的像素的颜色值，计算一个最大的颜色`AABB`包围盒。这个所谓的**颜色**可以选用在不同的色彩空间，比如RGB,YCoCg等不同的颜色空间做。对于在包围盒以外的点，也即是发生了`history mismatch`的像素，有`clamp`和`clip`两种不同的处理方式。
![edit-84c9ebe0655e44b9a7e08e01ff355f1f-2022-05-06-17-52-18](https://img.blurredcode.com/img/edit-84c9ebe0655e44b9a7e08e01ff355f1f-2022-05-06-17-52-18.png?x-oss-process=style/compress)

Neighborhood clamping也有他的问题(https://blog.csdn.net/weixin_30396699/article/details/99515560)，如在相邻像素差别很大的情况下所计算的颜色包围盒可能相当大，此时裁剪完全失效。

同时，对于`history mismatch`的处理方式也是值得考量的。
极端情况下，一律接受`history`，那么就是鬼影加上画面变糊，一律拒绝`history`，那么就是没有TAA抗锯齿的效果。
因此`AABB`画的越大，画面就会越糊，`AABB`越小，比如Nvidia提出的variance Clip，越容易拒绝历史帧的颜色，走样就会冒出来。

### 锯齿
- 边缘几何锯齿

由于`Motion Vectors`图也是有锯齿的，所以直接用中心点采样的方式在边缘处抗锯齿会失效。
一种保守的策略是选取$$3\times3$$区域内的深度最小的点，这样可以确保在几何边缘的像素点能采样到`Motion Vector`，从而正确采样history颜色。
![edit-84c9ebe0655e44b9a7e08e01ff355f1f-2022-05-06-18-02-20](https://img.blurredcode.com/img/edit-84c9ebe0655e44b9a7e08e01ff355f1f-2022-05-06-18-02-20.png?x-oss-process=style/compress)

- 内部几何锯齿

这个问题比较复杂，往往是由于小三角形引起的。比如远处的树叶等小三角形，其大小甚至小于一个像素，这会导致在相机jitter过程中该三角形一会出现一会不出现。
灵魂画师画个图，方框代表一个像素。在`jitter`过程中，采样点不一定能采样到这个三角形。
![TAA的Unity实现杂记-2022-05-06-19-00-01](https://img.blurredcode.com/img/TAA的Unity实现杂记-2022-05-06-19-00-01.png?x-oss-process=style/compress)

这一问题的解决方式在这篇文章中得到了讨论(https://zhuanlan.zhihu.com/p/71173025)。

- 着色高光锯齿

这个问题的成因感觉还没完全想清楚，但是大概和上一个的原因差不多。
一些零碎的点状的高光，在相机抖动的过程中，可能一帧高光被采样到，一帧没有。这样会导致`AABB Clip`反复发生，从而使得该像素不能稳定的和历史帧的颜色混合，呈现出高光闪烁的特点。
要压制这个问题可以考虑做一次filter以压制这种高光，不过会导致画面变糊。
其他的方式可以参考这篇文章(https://zhuanlan.zhihu.com/p/64993622)。

### 画面变模糊
`Unity`在TAA处理中还加入了一个锐化来防止画面变糊。

# 结果
左:NO TAA 右: TAA
<div id="image-compare">
  <img src="https://img.blurredcode.com/img/TAA的Unity实现杂记-2022-05-06-19-18-14.png?x-oss-process=style/compress" alt="NO TAA" />
  <img src="https://img.blurredcode.com/img/TAA的Unity实现杂记-2022-05-06-19-17-58.png?x-oss-process=style/compress" alt="TAA" />
</div>


# Reference

1. [TAA原理与OpenGL实现 - Irimsky](https://www.irimsky.top/archives/301/)
2. [Temporal AA Anti-Flicker](https://zhuanlan.zhihu.com/p/71173025)
3. [DX12渲染管线(2) - 时间性抗锯齿(TAA)](https://zhuanlan.zhihu.com/p/64993622)