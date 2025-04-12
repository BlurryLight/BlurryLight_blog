
---
title: "UE5 | Mobile GPUScene 超过LWC Tile的Actor的显示问题"
date: 2025-04-12T14:04:32+08:00
draft: false
categories: [ "UE"]
isCJKLanguage: true
slug: "77029615"
toc: true
mermaid: false
fancybox: false
blueprint: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
UEVersion: 5.3.2 
---

注意这个Bug和UE5.x的Mobile GPUScene的实现方案强相关，忘了是5.x改到有Bug的实现方案的，UE5.3中为了绕开Mali GPU Vertex Shader不能读取SSBO的问题选择了把一部分紧凑的GPUScene上的数据(准确的说，每个Primitive 80个字节，5个float4) Encode到了Vertex Attribute上作为VS计算坐标的输入。  UE5.4以后Mobile GPUScene又改了实现，我还没细看，据说是改成了用UBO的方式来传递数据。

简单的说，Mobile GPUScene上VS读取的数据里没有LWC坐标的TilePosition的信息(需要额外的三个int)，所以UE5.3的Mobile GPUScene只能表示LWC TileSize内的Actor坐标(大约20公里)，超出这个坐标算出来的坐标是错误的。


# Bug现象 

新建一个Cube Actor移动到这个位置

```
XYZ (X=-2870208.313199,Y=718670.497198,Z=342.168112)
Scale (X=10000.000000,Y=10000.000000,Z=10000.000000)
```

注意以下的动图(提前打开了`showflag.bounds 1`)以观察Actor Bounds,可以注意到 在PC Preview上位置是对的，而切换到Mobile Render可以注意到 其渲染出来的Mesh和CPU上计算出来的Bounds是脱节的，Bounds不能正确包裹Mesh。

这会导致在转镜头的时候Mesh在镜头内闪烁(因为 frustum culling依靠cpu的bounds来进行剔除)。


![UE53_Mobile_GPUScene_超过LWC_Tile的物体的坐标问题-2025-04-12-14-13-18](https://img.blurredcode.com/img/UE53_Mobile_GPUScene_超过LWC_Tile的物体的坐标问题-2025-04-12-14-13-18.webp)


# GPU上Mesh的位置和Bounds的计算

在CPU上虚幻的Bounds计算都是64位的，比如可以看 Planarreflection内的计算


![UE53_Mobile_GPUScene_超过LWC_Tile的物体的坐标问题-2025-04-12-14-53-27](https://img.blurredcode.com/img/UE53_Mobile_GPUScene_超过LWC_Tile的物体的坐标问题-2025-04-12-14-53-27.png?x-oss-process=style/compress)
FMatrix的定义都是double

```cpp
		FBox LocalBounds(-LocalExtent, LocalExtent);
		WorldBounds = LocalBounds.TransformBy(NewTransform);
```


而GPU Scene相关Transform矩阵的计算则是

```cpp

FSceneDataIntermediates GetSceneDataIntermediates(uint DrawInstanceId, float4 InstanceOrigin, float4 InstanceTransform1, float4 InstanceTransform2, float4 InstanceTransform3, float4 InstanceAuxData)
{

	float3 TilePosition = float3(0,0,0); // Bug在这一行，虚幻直接假设了Mobile GPUScene的TilePosition是0
	InstanceData.LocalToWorld = Primitive.LocalToWorld;

	float4x4 LocalToRelativeWorld = float4x4(
		float4(InstanceTransform1.xyz, 0.0f), 
		float4(InstanceTransform2.xyz, 0.0f), 
		float4(InstanceTransform3.xyz, 0.0f), 
		float4(InstanceOrigin.xyz, 1.0f));

	InstanceData.LocalToWorld = MakeLWCMatrix(TilePosition, LocalToRelativeWorld);
	...
```

注意这里Mobile GPUScene压根没有处理LWC的TilePosition相关的代码。
LWC直接把TilePosition设置成了float3(0,0,0)

`InstanceTransform1/2/3`的xyz分量encode了Actor的Scale/Transform,而InstanceOrigin是Actor中心相对于相机的位置。


但是InstanceOrigin实际上是包含了LWC的坐标，其来源是从CPU这边转换过来的。

CPU上构建`PrimitiveUniformData`的数据的时候，Actor的`AbsoluteWorldPosition`先被转成 LWC坐标再上传到了GPU上，而GPUScene从PrimitiveData内读取坐标再转存到GPUScene

一个LWC坐标包含一个 XYZ的TilePos和XYZ的Offset

真实坐标等于  TilePos * (UE_LWC_RENDER_TILE_SIZE 2097152.0) + Offset
这样浮点只用记录2097152内的偏移量，能够极大提高精度

```cpp
	inline const FPrimitiveUniformShaderParameters& Build()
	{
		const FLargeWorldRenderPosition AbsoluteWorldPosition(AbsoluteLocalToWorld.GetOrigin());
		const FVector TilePositionOffset = AbsoluteWorldPosition.GetTileOffset();

		Parameters.TilePosition = AbsoluteWorldPosition.GetTile();

		{
			// Inverse on FMatrix44f can generate NaNs if the source matrix contains large scaling, so do it in double precision.
			// Also use double precision to calculate WorldToPreviousWorld to prevent precision issues at far distances
			FMatrix LocalToRelativeWorld = FLargeWorldRenderScalar::MakeToRelativeWorldMatrixDouble(TilePositionOffset, AbsoluteLocalToWorld);
			..
			Parameters.LocalToRelativeWorld = FMatrix44f(LocalToRelativeWorld);

```

VS里读取到的InstanceOrigin是从GPUScene中读取，实际的来源是来自` WritePackedInstanceData`函数中的 


```c
	// This will only write out the relative instance transform, but that's fine; the tile coordinate of the instance transform comes from the primitive data
	// 这里已经是经过CPU处理后的坐标了
	float4 InstanceOriginAndId = InstanceData.LocalToWorld.M[3];
```


这可能有点绕，总的来说

```
1. CPU上Actor的坐标是Double表示
2. Actor在GPU上的FPrimitiveUniformShaderParameter的坐标经过了LWC坐标转换，double拆成了一个TilePosition和一个Offset两个float表示
3. Mobile GPUScene在组织数据的时候，从FPrimitiveUniformShaderParameter只读取了TileOffset，无视了TilePosition
4. VertexShader从Mobile GPUScene的取数据组装Transform矩阵时无法读取到正确的TilePosition，当物体超出LWC Tile的范围时(即TilePosition不再是(0,0,0))，计算出来的坐标是错误的
```


# 修复方案

没啥特别好的修复方案, 主要参考下5.4的GPUScene是怎么解决这个问题的。