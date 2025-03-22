
---
title: "UE | Mobile: Mesh和Material的UV套数不匹配的问题"
date: 2025-03-22T14:51:16+08:00
draft: false
categories: [ "UE"]
isCJKLanguage: true
slug: "bf8a3658"
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

最近发现一些Mesh只有1-2套UV，如果TA错误的使用了需要3-4套UV的材质，那么在PC预览上看起来是正常的，切换到Mobile Preview或者真机上看到的效果都不太对。
调试半天以后确定是UV的问题，去UDN上翻了一下发现也有人报告类似的问题。

[5.2 Bug in FStaticMeshVertexBuffer::BindPackedTexCoordVertexBuffer](https://udn.unrealengine.com/s/question/0D54z00009XIhvJCAT/52-bug-in-fstaticmeshvertexbufferbindpackedtexcoordvertexbuffer)

先说结论: **UE是刻意改成这样的，认为这种不规范的行为导致的bug是可以接受的。**

问题出现在
LocalVertexFactory.ush里

当材质出现了偶数对的UV时，虚幻会将两个float2的UV Pack到一个float4.

```cpp
#if NUM_MATERIAL_TEXCOORDS_VERTEX
	#if !MANUAL_VERTEX_FETCH
			// These used to be packed texcoord arrays, but these cause problems with alighnment on some Vulkan drivers
			#if NUM_MATERIAL_TEXCOORDS_VERTEX > 1
				float4	TexCoords0 : ATTRIBUTE4;
			#elif NUM_MATERIAL_TEXCOORDS_VERTEX == 1
				float2	TexCoords0 : ATTRIBUTE4;
			#endif
```

对应的cpp代码在

```cpp
void FStaticMeshVertexBuffer::BindPackedTexCoordVertexBuffer(const FVertexFactory* VertexFactory, FStaticMeshDataType& Data, int32 MaxNumTexCoords) const
```

PC端没有这个问题是因为PC端走MannulVertexFetch
可以翻一下VS里对应填充UV的代码
```cpp
FMaterialVertexParameters GetMaterialVertexParameters(FVertexFactoryInput Input, FVertexFactoryIntermediates Intermediates, float3 WorldPosition, half3x3 TangentToLocal){

#if MANUAL_VERTEX_FETCH && NUM_MATERIAL_TEXCOORDS_VERTEX
		const uint NumFetchTexCoords = LocalVF.VertexFetch_Parameters[VF_NumTexcoords_Index];
		UNROLL
		for (uint CoordinateIndex = 0; CoordinateIndex < NUM_MATERIAL_TEXCOORDS_VERTEX; CoordinateIndex++)
		{
			// Clamp coordinates to mesh's maximum as materials can request more than are available 
			uint ClampedCoordinateIndex = min(CoordinateIndex, NumFetchTexCoords-1);
			Result.TexCoords[CoordinateIndex] = LocalVF.VertexFetch_TexCoordBuffer[NumFetchTexCoords * (LocalVF.VertexFetch_Parameters[VF_VertexOffset] + Input.VertexId) + ClampedCoordinateIndex];
		}
#elif NUM_MATERIAL_TEXCOORDS_VERTEX
			#if NUM_MATERIAL_TEXCOORDS_VERTEX > 0
				Result.TexCoords[0] = Input.TexCoords0.xy;
			#endif
			#if NUM_MATERIAL_TEXCOORDS_VERTEX > 1
				Result.TexCoords[1] = Input.TexCoords0.zw;
			#endif
```


注意这里移动端和PC端的区别:
1. PC端会clamp到Mesh的最后一套UV，假如Mesh只有一套UV，材质用了两套，那么材质的第二套还是会fetch UV0的数据，相当于duplicate了一份uv0
2. 而移动端是直接读packed float4,读到的值是什么呢..



# 关于图形API 对 InputLayout和 Shader InputData Type数据类型对不上的处理

假如我们的Mesh只有一套UV, 材质需求两套UV

那么我们Mesh的UV InputLayout的格式是R16G16_FLOAT


```cpp
D3D11_INPUT_ELEMENT_DESC()
SemanticName       ATTRIBUTE
SemanticIndex      4
Format             DXGI_FORMAT_R16G16_FLOAT
InputSlot          3
AlignedByteOffset  0
InputSlotClass     D3D11_INPUT_PER_VERTEX_DATA
InstanceDataStepRate 0
```

![edit-022354761a284470816b2658a7cd9f3f-2025-03-21-15-15-35](https://img.blurredcode.com/img/edit-022354761a284470816b2658a7cd9f3f-2025-03-21-15-15-35.png?x-oss-process=style/compress)


而Shader里的是

```cpp
    float4	TexCoords0 : ATTRIBUTE4;
```

输入的数据是float2，但是shader里读的float4。
**部分图形API允许这种行为，不会报错，但是具体的行为是由图形API来规定的**

## OpenGL ES的处理

https://registry.khronos.org/OpenGL/specs/es/3.0/es_spec_3.0.pdf

根据 GLES的Spec的2.8节的最后一行，
`The initial values for all generic vertex attributes are (0.0, 0.0, 0.0, 1.0)`

GL这里的行为是确定的，TexCoords0会被先初始化为(0,0,0,1),然后再从VertexBuffer里根据InputLayout读取xy属性覆盖过来


## Vulkan的处理

[Vertex Input Data Processing :: Vulkan Documentation Project](https://docs.vulkan.org/guide/latest/vertex_input_data_processing.html)

vulkan spec太晦涩了，从khronos的文档里翻了一下，最后一节也描述了对应的表现，和GLES应该是类似的，`vertex attribute`应该是先初始化到`(0,0,0,1)`，再从传进来的buffer里取值。


## DX的处理

DX没找到对应的文档，但是从Renderdoc里抓出来的结果来看和GL是对应的，也是初始化到了(0,0,0,1)
![edit-022354761a284470816b2658a7cd9f3f-2025-03-21-15-21-29](https://img.blurredcode.com/img/edit-022354761a284470816b2658a7cd9f3f-2025-03-21-15-21-29.png?x-oss-process=style/compress)



如果InputLayout指定的类型的Channel数大于shader 里需要的Channel数，那么这些多余的data会被静默discard掉。基本所有API都是对这个良定义的。
比如[Vulkan Spec里](https://docs.vulkan.org/spec/latest/chapters/fxvertex.html#fxvertex-attrib-location)这样说


> The number of components in the vertex shader input variable **need not** exactly match the number of components in the format. If the vertex shader has fewer components, the extra components are discarded.

# 总结

要处理这个bug的话还算比较棘手。
- 从资产上去加一个扫描工具扫描这种情况是最简单的，但是这种处理不了Mesh被逻辑动态挂载新的材质的行为。

- 从原理上来分析，只有材质里出现了偶数对的UV，才会导致这个问题。那么可以考虑在移动端Mesh创建UV的时候始终想办法Padding到偶数对的UV，比如Mesh只有3套，材质里用了4套UV,那么Mesh创建VertexBuffer的时候可以Padding到四套UV,第四套UV的数据复制UV3的数据。 但是这个解法可能下次UE又改做法了然后可能会造成更隐蔽的bug。而且假设Mesh只有1套UV, Material用了3套UV,那么Padding到偶数对也解决不了这个问题。

终极解法：仿造PC端的逻辑，移动端也增加一个uniform,把Mesh现在有多套UV传到shader里，shader里做clamp,以避免采到不存在的值。
