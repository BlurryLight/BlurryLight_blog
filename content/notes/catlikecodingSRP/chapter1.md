
---
title: "Catlike Coding | Chapter 1 Pipeline Asset"
date: 2022-03-08T19:00:42+08:00
draft: false
# tags: [ "" ]
categories: [ "CG"]
# keywords: [ ""]
# lastmod: 2022-03-08T19:00:42+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "18139ebf"
toc: true
mermaid: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
---

这是来自对[Catlike Coding的SRP教程](https://catlikecoding.com/unity/tutorials/custom-srp/)的整理，约等于简单的复制粘贴，其`License`为[MIT-0](https://catlikecoding.com/unity/tutorials/license/)，版权作者为Jasper Flick。
目录包括
- [Chapter 1 Pipeline Asset](/notes/catlikecodingsrp/18139ebf/)
- [Chapter 2 Drawwcalls](/notes/catlikecodingsrp/c2282dd8/)
- [Chapter 3 Directional Lights](/notes/catlikecodingsrp/d791911c/)
- [Chapter 4 Directional Shadows](/notes/catlikecodingsrp/e36ff115/)
- ...

<hr />

# Chapter 1 Pipeline Asset

## Pipeline Asset

需要创建一个`Asset`文件，没什么特殊的就是一个保存设置的序列化文件，里面有一个虚函数`CreatePipeline`作为工厂函数返回一个`IRenderPipeline`抽象类，该工厂函数需要被`override`。

`menuName`允许在右键菜单中加入一个新的`Rendering`的菜单。
```C#
[CreateAssetMenu(menuName = "Rendering/Custom Render Pipeline")]
public class CustomRenderPipelineAsset : RenderPipelineAsset { … }
```

## Pipeline Constructor

### Camera Render
有了工厂函数需要真正的`pipeline`对象，其需要继承`RenderPipeline`类，并且`override`其中的纯虚函数`Render`。

`Render`函数会被每帧调用，在这个主循环里处理渲染事件。
可以创建`CameraRender`类接收一个`camera`和`context`对象并处理这个相机的渲染事件，主循环里把渲染事件发给每个相机处理。

### Draw Skybox

Unity自带方法： `context.DrawSkybox(camera)`绘制天空盒。

这些渲染指令并非立刻提交，而是需要通过一个`context.Submit()`方法提交给GPU。

为了正确渲染画面，调用`draw`指令前需要设置`camera`的参数，需要用到`context.SetupCameraProperties(camera)` 方法。

### Command Buf

老朋友`cmdbuf`了。`DrawSkybox`这种API是特化的，可以通过`context`对象调用，其他的普通的绘制指令需要用`cmdbuf`来记录，最后提交给GPU。

- profile
通过`buffer.BeginSample(name:String)`和`buffer.EndSample(name:String)`插入`profile`相关代码，会在`profiler`里以`name`的名称显示。

- 绘制
在`context.Submit`提交前可以通过`context.ExecuteCommandBuffer(buffer)`来提交cmdbuf记录的指令，并且记得提交后要调用`buffer.clear()`清空cmdbuf。

### Clear RenderTargets
如果我们单独写一条`buffer.ClearRenderTarget(true, true, Color.clear);`，Unity会尝试画一个`Quad`来清空当前的rt。

![](https://img.blurredcode.com/img/202202062333241.png?x-oss-process=style/compress)

如果我们合并写
```C#
		context.SetupCameraProperties(camera);
		buffer.ClearRenderTarget(true, true, Color.clear);
```
会调用`glClearColor`这种API来清空(猜测)，反正是更高效的方式。

![正确的清空姿势](https://img.blurredcode.com/img/202202062331998.png?x-oss-process=style/compress)


### Culling

绘制的时候需要剔除不在视椎体内的物体，剔除所需要的参数被记录在`ScriptableCullingParameters`结构体中。
TODO: 查看该结构体的内容

剔除所需要的参数不用手动计算，用`bool camera.TryGetCullingParameters(out p)`计算，该函数在成功计算参数的时候返回`True`，并把内容填充到`p`里。如果返回`False`说明这个相机参数设置不合法，可以直接报错。

实际执行提出的指令为`CullingResults context.Cull(ref p)`指令，在`buf`里记录一个提出指令，其返回一个`CullingResults`对象，`ref`是为了引用传递，`CullingResults`在`context.DrawRenderers`的时候会被用到。(This data includes information about visible objects, lights, and reflection probes. )

### Drawing Geometry

`DrawRenderers`是绘制接口，需要`cullingResults`和`drawingSettings`和`filterSettings`。

```C#
context.DrawRenderers(
    cullingResults, ref drawingSettings, ref filteringSettings
);
```

在`drawingSettings`需要指定物体绘制的顺序和使用的`ShaderTagID`，`FilterSettings`需要筛选渲染队列中允许的对象。
典型的绘制不透明物体的参数设置
```C#
        var sortingSettings = new SortingSettings(camera)
        {
            //https://docs.unity3d.com/ScriptReference/Rendering.SortingCriteria.CommonOpaque.html
            criteria = SortingCriteria.CommonOpaque //大概是从前到后，多个flags的组合，和材质也有关系
        };
        var drawingSettings = new DrawingSettings(
            unlitShaderTagId, sortingSettings
        )       
        // 这里需要注意的是DrawSettings里面的SetShaderPassName查找的不不不(重要的事情说三遍)是Shader的Pass中那个Name “xxx” 不是那个！！！找的是Tags中的LightMode！
        // https://www.cnblogs.com/shenyibo/p/12485235.html
        // 按顺序查找Pass，先查找Unlit，再查找Lit
        drawingSettings.SetShaderPassName(1,litShaderTagId);
        var filteringSettings = new FilteringSettings(RenderQueueRange.opaque);
        context.DrawRenderers(
            cullingResults, ref drawingSettings, ref filteringSettings
        );
```

通过调整`FilterSettings`可以筛选出渲染队列的不同物体，从而实现透明物体和不透明物体的不同批次渲染。(需要调整sorting到CommanTransparent)，因为透明物体不写深度，所以从前到后渲染不能起到剔除的效果。而要实现正确的颜色混合需要从后到前渲染。
然而其实透明渲染从后到前也并不一定正确，考虑一个非常细长的透明杆沿着`Z`轴放置，如何定义它的位置是一个问题。


## Editor Rendering
在编辑器内的体验提升。

### 渲染不支持的材质

Unity自带一个`Hidden/InternalErrorShader`的shader，熟悉的紫色Shader，新建一个材质。
然后在`drawingSettings`中对不支持的ShaderTagId设置`overrideMaterial`，这些带有不支持的ShaderTag的物体就会经过错误的material渲染成醒目的紫色。
```C#
		var drawingSettings = new DrawingSettings(
			legacyShaderTagIds[0], new SortingSettings(camera)
		) {
			overrideMaterial = errorMaterial
		};
```

![](https://img.blurredcode.com/img/202202070036830.png?x-oss-process=style/compress)

### Partial Class

一个C#的特性。允许通过`partial`关键字把一个类分散定义在多个文件内，适合将一些只在`Editor`内运行的代码分散出来，并加上

```C#
partial class CameraRenderer {
#if UNITY_EDITOR
    // some work only valid in Editor
#endif
}
```

函数也同样可以声明为`partial`，如果一个声明为`partial`的代码在编译的时候没有实现(因为实现被宏注释掉了)，那么编译器会自动略过对这些函数的调用(The compiler will strip out the invocation of all partial methods that didn't end up with a full declaration.)。

### Draw Gizmos
只在Editor里有效，并且Gizmos应该只在物体被选中的时候被绘制,接口是`bool UnityEditor.Handles.ShouldRenderGizmos()`
直接调API就完事，Gizmos分为两类不过我暂时不知道有啥区别。
```C#
	partial void DrawGizmos () {
		if (Handles.ShouldRenderGizmos()) {
			context.DrawGizmos(camera, GizmoSubset.PreImageEffects);
			context.DrawGizmos(camera, GizmoSubset.PostImageEffects);
		}
	}
```

### Drawing Unity UI 绘制UI
https://docs.unity3d.com/Packages/com.unity.ugui@1.0/manual/UICanvas.html

UI的绘制可以分为三种情况。

![edit-715422187a0c42adb4488350fc0ee4ec-2022-02-08-01-15-33](https://img.blurredcode.com/img/edit-715422187a0c42adb4488350fc0ee4ec-2022-02-08-01-15-33.png?x-oss-process=style/compress)

- Overlay
 
`Overlay`的绘制是绘制一个半透明的`quad`，是屏幕空间的类似于后处理的效果，直接绘制在framebuffer上，其不通过自定义管线。

![](https://img.blurredcode.com/img/202202080118111.png?x-oss-process=style/compress)

- Screen Space - Camera

需要选择一个相机作为`Render Camera`，然后还会把UI放在透明物体里渲染。

![](https://img.blurredcode.com/img/202202080121034.png?x-oss-process=style/compress)

- World mode
  
就像真实的物体一样被渲染，可以调节他的transformation之类信息。其单位变成`mm`，而在屏幕空间其单位为像素`pixel`。

比如`HoLolens`的UI就是用`world mode`创建的。

在Unity的编辑器的`Scene`窗口(`Scene`窗口会额外创建一个摄像机)，UI都会以`world mode`来绘制。在自定义管线中我们需要判断相机是否为`scene`创建的相机，并且调用额外的函数以在`scene`窗口中绘制UI。

```C#
	partial void PrepareForSceneWindow () {
		if (camera.cameraType == CameraType.SceneView) {
			ScriptableRenderContext.EmitWorldGeometryForSceneView(camera);
		}
	}
```


# 多摄像机支持

相机有个`Depth`参数，默认从-1开始，从小到大渲染。

![](https://img.blurredcode.com/img/202202080136800.png?x-oss-process=style/compress)

## Camera name and Buffer Name
为了调试方便(在profiler)里看起来更清楚，可以把cmdbuf的名字和camera.name绑定起来，并且通过一个常量`SampleName`保存。
后续的` buf.BeginSample(name)`和`EndSample`都可以调用这个常量而无需内存分配。
```C#
    const string SampleName = bufferName;
	partial void PrepareBuffer () {
		buffer.name = SampleName = camera.name;
	}
```

## Layers
可以在`inspector`里调整camera可以看到哪些层，物体也可以选择其存在与哪些层，可以选择性提出一些物体

## Clear RenderTarget

camera的`clear`属性被保存在`camera.clearFlags`里。
The CameraClearFlags enum defines four values. From 1 to 4 they are Skybox, Color, Depth, and Nothing. 

只要不是`nothing`就要清理深度，`color`可以用`camera.backgroundColor.linear`获取inspector里的颜色。

![](https://img.blurredcode.com/img/202202080140276.png?x-oss-process=style/compress)
