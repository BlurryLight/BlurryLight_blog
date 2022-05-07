
---
title: "Catlike Coding | Chapter 3 Directional Lights"
date: 2022-03-08T19:12:47+08:00
draft: false
# tags: [ "" ]
categories: [ "CG"]
# keywords: [ ""]
# lastmod: 2022-03-08T19:12:47+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "d791911c"
toc: true
mermaid: false
# latex support
katex: true
markup: mmark
mmarktoc: true
---
## Lighting

### Lit Shader

```
		Pass {
			Tags {
				"LightMode" = "CustomLit"
			}

			…
		}
```
在`Pass`里设置的`LightMode`比较重要，这是在`C#`里通过`new ShaderTagId("CustomLit");`获取的`shaderTagId`，并且需要通过`drawingSettings.SetShaderPassName(1, litShaderTagId);`以使得该管线可以通过这个shader渲染。

### Normal Vectors

在`vshader`的输入里使用`NORMAL`语义以获得正确的法线输入。
`v2f`结构体里的变量的语义可以自己定(不要和其他的语义重了就行)，比如可以定义个`VAR_NORMAL,VAR_BASE_UV`，也可以像buildin管线的惯例用`TEXCOORDX`。

### Interpolated Normals

老生常谈的问题，因为三角面片插值法线的时候可能插值出非归一化的法线值，所以在fshader里第一件事就是重新归一化法线。

灰色是插值出来的长度，黑色的部分是归一化以后增加的长度。

![](https://img.blurredcode.com/img/202202112154330.png?x-oss-process=style/compress)

### Surface Properties

可以创建一个结构体`struct Surface`以存放与着色有关的属性。

### Calculating Lighting

Nothing important.

## Lights
`directional lights only`.

### Light structure
同样可以用`Light`结构体保存Light的方向、颜色、强度等信息。

### Sending Light Data to the GPU

在`Shader`里定义`Directional Light`相关的属性，并在`C#`里传进去。
```
CBUFFER_START(_CustomLight)
	float3 _DirectionalLightColor;
	float3 _DirectionalLightDirection;
CBUFFER_END
```

注意在shader里的`lightDirection`是从着色点`p`指向光源的 $$ \omega_i $$。

`color.linear` 自带从SRGB到`Linear`的转换。
```C#
buffer.SetGlobalVector(dirLightColorId, light.color.linear * light.intensity);
		buffer.SetGlobalVector(dirLightDirectionId, -light.transform.forward);
```

### Visible Lights

Unity在`cull`的时候会计算相机视野内的像素被哪些光源照亮。
(TODO: Tile-based Rendering)

```C#
...
void SetupLights () {
		NativeArray<VisibleLight> visibleLights = cullingResults.visibleLights;
	}
```
NativeArray是一个类似于array但是内部保存的东西与native memory有关(unsafe代码？)

### Multiple Directional Lights

```C#
dirLightColors[index] = visibleLight.finalColor;
dirLightDirections[index] = -visibleLight.localToWorldMatrix.GetColumn(2);
```
`finalColor = light.Color * light.intensity`，但是默认情况下不是线性空间，如果要线性的颜色需要设置`GraphicsSettings.lightsUseLinearIntensity = true;`
(If this is true, Light intensity is multiplied against linear color values. If it is false, gamma color values are used. Default is false)

M矩阵类似于TBN，三个轴是局部坐标系在世界坐标系下的基表示，第三个轴是forward这个轴。

### Shader Loop

没什么说的，记录`count`变量(来自C#)，然后用for-loop循环着色。

### Shader Target Level

Loop over variable是一个比较现代的特性。(GPU也太辣鸡了)

#pragma target 3.5 丢弃WebGL1.0和OpenGL ES 2.0可以减少一些麻烦。


## BRDF

 Unity2MinimalCookTorranceBRDF
 有空专门开个文章讨论
 
 ## Transparency
 
 如果只是单纯的乘以`src.alpha`，那么高光项的颜色也会变得透明，这是不对的。diffuse的部分能量对透明物体一部分穿透了，一部分反射了，所以变暗是正常的，但是高光部分不会(要么全部穿透要么全部反射)，所以blend公式不适合应用在高光项里。
 
 高光项出现了洞

![chapter3-2022-03-08-19-21-19](https://img.blurredcode.com/img/chapter3-2022-03-08-19-21-19.png?x-oss-process=style/compress)
 
 ### Premultiplied Alpha
 
 只fade diffuse的部分，保持specular为全部强度，这意味着需要手动在shader里blend，所以把`src Blend` 设置为 `one`。
 
 在shader的`brdf.diffuse`里手动乘以`src.alpha`。
 
 ```
 brdf.diffuse *= surface.alpha;
```

带有完整高光的例子

![chapter3-2022-03-08-19-22-03](https://img.blurredcode.com/img/chapter3-2022-03-08-19-22-03.png?x-oss-process=style/compress)


### Premultiplication Toggle

`brdf.diffuse * surface.alpha`这句指令对于不带半透明的物体或者需要使用硬件blend的材质是多余的。
可以添加一个shader变体。
```
[Toggle(_PREMULTIPLY_ALPHA)] _PremulAlpha ("Premultiply Alpha", Float) = 0
```


## Shader GUI

可以给Shader添加一个`CustomEditor`，并新建一个类`public class CustomShaderGUI : ShaderGUI {`并且定义Shader相关的变量。

```
Shader "Custom RP/Lit" {
	…

	CustomEditor "CustomShaderGUI"
}
```

需要重写`OnGUI`函数，其原型为
```C#
	public override void OnGUI (
		MaterialEditor materialEditor, MaterialProperty[] properties
	) {
		base.OnGUI(materialEditor, properties);
	}
```

对于GUI编辑的Material，可以通过`materialEditor.targets`(https://docs.unity3d.com/ScriptReference/Editor-targets.html)获得，目前只有一个，`properties`是可以编辑的属性，

![](https://img.blurredcode.com/img/202202261111886.png?x-oss-process=style/compress)

要设置属性需要从`properties`这个数组里查找，Unity提供了`ShaderGUI.FindProperty`方法

```C#
void SetProperty (string name, float value) {
		FindProperty(name, properties).floatValue = value;
	}
```
