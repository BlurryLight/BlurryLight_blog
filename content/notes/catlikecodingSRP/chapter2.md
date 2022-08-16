
---
title: "Catlike Coding | Chapter 2 Drawcalls"
date: 2022-03-08T19:12:44+08:00
draft: false
# tags: [ "" ]
categories: [ "CG"]
# keywords: [ ""]
# lastmod: 2022-03-08T19:12:44+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "c2282dd8"
toc: true
mermaid: false
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
# Chapter 2 Drawcalls


## Shader 基础
没什么好说的。

 坐标和纹理坐标使用`float`,其他的都用half就足够了。
 桌面端不支持真的half，都是float，移动端很讲究这个。
 
 `sementaics`:
 - POSITION : float3 输入的坐标
 - SV_POSITION: float4 vs输出坐标
 - SV_TARGET: float4 fs输出


常用的`hlsl`

```hlsl
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
```

要在`inspector`里设置变量需要在`Properties`里添加，并在使用时候需要先声明一个同名的变量。


## Batching

`drawcall`需要走PCIE总线，会很慢，即使发送的数据很少。

### SRP Batcher

`SRP Batcher`需要shader兼容，在shader的`inspector`里可以看到。
`SRP Batcher`通过缓存一些材质的属性来减少drawcall，以避免每次绘制的时候都要重新设置所有的属性。

这一块catlike没有展开讲，详细的信息在这里[SRP Batcher](https://blog.unity.com/technology/srp-batcher-speed-up-your-rendering)。


![](https://img.blurredcode.com/img/202202082332981.png?x-oss-process=style/compress)
如图所示，`Mateiral`相关的属性一旦被设置就被驻留在GPU内存上，接下来的每一帧渲染CPU只会设置transform等属性，material的属性在更改的时候才会触发新的`drawcall`。

兼容SRP Batcher的shader需要满足以下两点：
- 对于任何该由引擎填充的变量，应该被声明在`UnityPerDraw`这个`cbuffer`里，并且按照一定的名字被设置。
- 对于任何材质相关的变量，其必须被声明在`UnityPerMaterial`这个`cbuffer`里，不允许有cbuffer外的单独的变量声明。

如果使用`MaterialPropertyBlock`是没法使用SRP Batcher的(每个物体不同属性)，可以用GPU Instance。

`UnityPerDraw`允许的属性，最后一栏是是否允许为`half`(`real4`)。

![](https://img.blurredcode.com/img/202202082340531.png?x-oss-process=style/compress)

`catlike`的博客里描述The exact order doesn't matter，但是实际上SRP博客里说的是`The variable declaration order inside of “UnityPerDraw” CBUFFER is also important.`，最好按照顺序来。(试了下不按顺序来似乎也能过)

似乎可以塞入多个属性(条件不明，似乎一个block里的变量不能随便删减)

```hlsl
//这个过不了
CBUFFER_START(UnityPerDraw)
float4x4 unity_ObjectToWorld;
float4x4 unity_WorldToObject;
// float4 unity_LODFade;
real4 unity_WorldTransformParams;
CBUFFER_END

//这个能过
CBUFFER_START(UnityPerDraw)
float4x4 unity_ObjectToWorld;
float4x4 unity_WorldToObject;
float4 unity_LODFade;
real4 unity_WorldTransformParams;
float4 unity_LightmapST;
float4 unity_lightData;
CBUFFER_END
```
在profile里能看见这样的栏目代表SRP Batcher启动成功，但是记得这不是某一个drawcall，而是Unity把多个连续的过程显示为一个。
![](https://img.blurredcode.com/img/202202082350366.png?x-oss-process=style/compress)


### Many Colors

SRP Batcher把材质的信息保存在GPU的cbuffer里。SRP Batcher能合并的材质需要其内存布局相同。
如果我们要每个物体一个颜色，需要每个物体创建一个材质，不可行。
Unity提供了一个`MaterialPropertyBlock`的结构体，以设置`per-object material`属性。
但是SRP Batcher不能对包含有`MaterialPropertyBlock`的物体合批。
```C#
		block.SetColor(baseColorId, baseColor);
		GetComponent<Renderer>().SetPropertyBlock(block);
```

### GPU Instancing

使用GPU Instance可以做到带`MaterialPropertyBlock`的合批。
`#pragma multi_compile_instancing`指令必须在shader里使用，会生成不同的shader变体。

需要包含以下文件，以数组的形式定义一些变量(Unity_MATRIX_M)之类的，但是要正确支持instance我们还需要知道每个物体的`index`。

```
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
```

`index`信息在vshader阶段传入，因此我们必须把`vshader`的输入转换为一个结构体(正常情况下也是结构体)，并定义`UNITY_VERTEX_INPUT_INSTANCE_ID`这个成员(macro)，并且在`vshader`的开始的时候赋值(UNITY_SETUP_INSTANCE_ID(input);)。(This extracts the index from the input and stores it in a global static variable that the other instancing macros rely on.)

```
float4 UnlitPassVertex (Attributes input) : SV_POSITION {
	UNITY_SETUP_INSTANCE_ID(input);
	float3 positionWS = TransformObjectToWorld(input.positionOS);
	return TransformWorldToHClip(positionWS);
}
```

以上操作对`fshader`也适用，在`v2f`结构体中也需要定义`index`，并且在`vshader`中使用类似`UNITY_TRANSFER_INSTANCE_ID(input, output);`这种来传递`index`(因为index输入在vshader，需要传递给fshader)。

如果我们要支持`per-instance material data`，我们需要将`UnityPerMaterial`定义为

```
UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
    UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)
```

![chapter2-2022-03-08-19-19-28](https://img.blurredcode.com/img/chapter2-2022-03-08-19-19-28.png?x-oss-process=style/compress)

### Dynamic Batching

unity自带的一种可以把小的mesh合并成大的mesh的东西，用处不大。


### Configuring Batching

SRP Batcher是一个类似开关，打开设置、关闭设置，是一个整个管线的设置。

`DynamicBatching`和`GPU Instancing`可以设置为逐相机的设置，其在传递给相机渲染(cameraRender)的时候被传递过去
,最终的设置是在每帧的`drawSettings`里。
```C#
GraphicsSettings.useScriptableRenderPipelineBatching = useSRPBatcher;
...
// per render call
			renderer.Render(
				context, camera, useDynamicBatching, useGPUInstancing
			);

...
// in cameraRender
        var drawingSettings = new DrawingSettings(
            unlitShaderTagId, sortingSettings
        )
        {
            enableInstancing = GPU_instancing,
            enableDynamicBatching = dynamic_batch
        };

```

另外支持`GPU Instancing` 的材质的`inspector`上也会有一个开关，关掉后这个material的渲染不会触发instance。


## Transparency

在`Pass`前使用Blend可以调节混合模式
```
		Pass {
			Blend [_SrcBlend] [_DstBlend]

			HLSLPROGRAM
			…
			ENDHLSL
		}
```
### No writing Depth

`ZWrite [_ZWrite]`在Pass前控制深度写入，一般透明物体不写深度(但是要做深度测试)，因为透明物体能看见后面的物体，写深度会导致后面的物体被剔除。

### Textureing

声明纹理和采样器，名字要注意匹配。
```
TEXTURE2D(_BaseMap); 
SAMPLER(sampler_BaseMap);
```

如果在GPU Instance里要使用`_BaseMap_ST`，要声明在GPU Instance的变量区域里。

`UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)`

### Alpha Clipping

在Shader里可以使用`clip(value)`函数丢弃value <= 0的像素，比如
`clip(base.a - UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff));`，丢弃比`_Cutoff`小的向量。

### Shader Features

可以通过`#pragma shader_feature xxx`定义shader变体，会生成两个shader(指数级上升)。

生效的话，可以通过`[Toggle(_CLIPPING)] _Clipping ("Alpha Clipping", Float) = 0`这样的声明，`Toggle`这个关键词会调用不同的变体，也可以在C#端手动启用`keyword`。