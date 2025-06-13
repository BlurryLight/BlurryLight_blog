
---
title: "UE | HLOD优化 1-纠正错误的法线"
date: 2025-06-07T22:05:28+08:00
draft: false
categories: [ "UE"]
isCJKLanguage: true
slug: "49830e01"
toc: true
mermaid: false
fancybox: false
blueprint: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
UEVersion: 5.5.4
---


# HLOD builder

UE有好几套不同的合并Mesh，Baking材质的实现，Modeling Tool里有一套，UE4时期集成Simplygon有一套， HLOD这里也有好几种不同的baking method。

甚至存在一些相同类名相同功能的类但是实现不同的...咱也不敢想咱也不敢问

![UE_HLOD_错误的法线-2025-06-07-22-09-29](https://img.blurredcode.com/img/UE_HLOD_错误的法线-2025-06-07-22-09-29.png?x-oss-process=style/compress)


# Mesh HLODBuilder


UE现在用的比较多的主要有个4个HLOD Builder:

- Simplify Mesh HLODBuilder
- Merge Actors HLODBuilder
- Batch Instance HLODBuilder
- Approximate Mesh HLODBuilder


这四个类的入口有两个地方：

第一个入口在选中Actors以后点顶部菜单的`Actors -> Merge Actors`可以进入。 这里可以对单独的Actor进行合并操作，并且精心调制合并的参数（实际上这个手段更适合用来做一些debug操作，毕竟一个地图几十万个Actors谁会去一个一个的选啊)

![UE_HLOD_错误的法线-2025-06-07-22-12-03](https://img.blurredcode.com/img/UE_HLOD_错误的法线-2025-06-07-22-12-03.png?x-oss-process=style/compress)



第二个入口在顶部菜单的`Build->BuildHLODs`，这个是对整个地图的Actors进行Build HLOD的入口。

每个Actor可以和一个`UHLODLayer`类关联上(这里可以hook引擎的代码来做一些逻辑自动将一些Actor关联到HLOD Layer上)，然后引擎会根据每个HLODLayer上选择的HLOD Builder来进行Build。


![UE_HLOD_错误的法线-2025-06-07-22-13-47](https://img.blurredcode.com/img/UE_HLOD_错误的法线-2025-06-07-22-13-47.png?x-oss-process=style/compress)

# 法线问题其1 法线空间

最近在使用HLOD Builder的时候遇到了一个问题，HLOD Builder生成的Mesh法线不正确。

经过了一番仔细的调查，发现原因是:

- 虚幻的材质系统即支持`Tangent Space Normal`也支持`World Space Normal`
- HLOD Builder在烘焙材质的时候直接取原材质的Normal引脚输出的结果烘焙到一个贴图上
- 这个贴图会被设置到一个新的材质上，这个材质由我们指定

一个输出世界法线的例子(注意材质的属性上要去掉TangentSpaceNormal)
![UE_HLOD_错误的法线-2025-06-07-22-20-45](https://img.blurredcode.com/img/UE_HLOD_错误的法线-2025-06-07-22-20-45.png?x-oss-process=style/compress)
![UE_HLOD_错误的法线-2025-06-07-22-42-15](https://img.blurredcode.com/img/UE_HLOD_错误的法线-2025-06-07-22-42-15.png?x-oss-process=style/compress)

这里就会出现一个问题:

- 如果我们指定的HLOD使用的BaseMaterial是Tangent Space Normal的材质，但是正在烘焙的原始材质的引脚输出的是World Space Normal，那么烘焙出来的贴图就会是错误的。
- 反之亦然。

## 解决方案


经过了调查确定上面的case有问题后，那么就读代码吧。

先从`UHLODBuilderMeshSimplify`看起，可以注意到最后进到了`void FMeshMergeUtilities::CreateProxyMesh`，然后材质部分的是依靠`MaterialBaking`这个模块。

`IMaterialBakingModule& MaterialBakingModule = FModuleManager::Get().LoadModuleChecked<IMaterialBakingModule>("MaterialBaking");`


那么跳到`MaterialBakingModule`的实现，可以找到`FMaterialBakingModule::CreateMaterialProxy`这个类，这个类对每个材质编译了很多新的变体来获取每个引脚的输出。


跟下去我们会发现很可疑的代码:

这里虚幻看起来也意识到了这个问题，并写了一些代码来处理。如果正在编译的材质和BaseMaterial的Normal不在同一个空间，那么这里会额外插入一些语句来对齐normal。

```cpp

	int32 CompileNormalTransform(FMaterialCompiler* Compiler, int32 NormalInput) const
	{
		return bTangentSpaceNormal && !Material->bTangentSpaceNormal
			? Compiler->TransformVector(MCB_World, MCB_Tangent, NormalInput) : NormalInput;
	}

	/** helper for CompilePropertyAndSetMaterialProperty() */
	int32 CompilePropertyAndSetMaterialPropertyWithoutCast(EMaterialProperty Property, FMaterialCompiler* Compiler) const
	{
		if (Property == MP_EmissiveColor)
		{
			case MP_Normal:
			case MP_Tangent:
				return CompileNormalEncoding(
					Compiler,
					CompileNormalTransform(&ProxyCompiler, MaterialInterface->CompileProperty(&ProxyCompiler, PropertyToCompile, ForceCast_Exact_Replicate)));
```


既然这里有代码，就直接断点在这里跟一下为什么没有执行到正确的逻辑。


经过一番跟踪，发现这个代码的执行条件是`bTangentSpaceNormal && !Material->bTangentSpaceNormal`，也就是`HLOD BaseMaterial`是`Tangent Space Normal`，但是正在烘焙的材质不是。 但是我这里 `bTangentSpaceNormal` 始终是`false`。说明`HLODBuilder`那边没有正确设置这个标志。

往回跟发现在`FMeshMergeUtilities::CreateProxyMesh`这个调用点确实没有看到任何处理`bTangentSpaceNormal`的代码，这显然是不对的，我们需要根据`BaseMaterial`的`Normal Space`来设置这个标志。


找到合适的地方插入了一行代码以后就立竿见影了

```cpp
void FMeshMergeUtilities::CreateProxyMesh(const TArray<UStaticMeshComponent*>& InComponentsToMerge, const struct FMeshProxySettings& InMeshProxySettings, UMaterialInterface* InBaseMaterial,
	UPackage* InOuter, const FString& InProxyBasePackageName, const FGuid InGuid, const FCreateProxyDelegate& InProxyCreatedDelegate, const bool bAllowAsync, const float ScreenSize) const
{
    ....
			FMaterialData MaterialSettings;
			MaterialSettings.Material = Material;
			
			// ++ravenzhong: see class FExportMaterialProxy::CompileNormalTransform
			// if our Source Components outputs world-normal
			// our base material is tangent-normal
			// we need to do an additional transform here
			MaterialSettings.bTangentSpaceNormal = InBaseMaterial->GetMaterial()->bTangentSpaceNormal; // should we transform
			//--ravenzhong

			for (const FPropertyEntry& Entry : Options->Properties)
			{
				if (!Entry.bUseConstantValue && Material->IsPropertyActive(Entry.Property) && Entry.Property != MP_MAX)
				{
					MaterialSettings.PropertySizes.Add(Entry.Property, Entry.bUseCustomSize ? Entry.CustomSize : Options->TextureSize);
				}
			}
```

![UE_HLOD_错误的法线-2025-06-07-22-31-56](https://img.blurredcode.com/img/UE_HLOD_错误的法线-2025-06-07-22-31-56.png?x-oss-process=style/compress)


# 法线问题其2 错误的法线混合

修了上面的问题后，我在demo场景 Build Mesh总算是对了。
信心满满的去流水线重新build了一下HLOD，结果发现还是有问题。


经过了一番调查，发现同样有问题的Mesh，只要放在我们的主场景就有问题，放在我新建的关卡就没问题。而且有的材质都是好的，但是有的材质是错误的。出错误的材质都是我们自己做的材质，官方的材质都没问题。

一定是我们做的材质哪里有问题。打开材质研究了一会，发现`Normal`在最后输出前经过了一个可疑的`RVT Blend`有关的material function。

考虑到一个假设： 流水线Build HLOD并没有完整的编辑器视口，而是通过`UnrealEditor-cmd.exe` 和 `-allowcommandletrendering`参数来运行的，有理由怀疑在这种case下RVT没有正常工作，导致RVT的数据是错乱的。


恰好从Simplygon的文档里看到了虚幻提供一个`MaterialProxyReplace`节点，当Build
HLOD等case的时候，材质会用下面的分支，当正常游戏时，材质用上面的分支。

[Material baking | Simplygon 10.4.117.0](https://documentation.simplygon.com/SimplygonSDK_10.4.117.0/ue5/concepts/materialbaking.html)

于是我直接把未经过RVT的Normal接到`MaterialProxy`输出上，重新Build HLOD，结果一切就好了。

![UE_HLOD_错误的法线-2025-06-07-22-38-32](https://img.blurredcode.com/img/UE_HLOD_错误的法线-2025-06-07-22-38-32.png?x-oss-process=style/compress)



# 错误的BaseColor

注意到场景里有一些Mesh的BaseColor也有问题，经过调查以后发现这些材质是`Unlit`材质，TA在`Unlit`引脚直接进行了一些简易的光照计算来做一些效果。
快速对节点进行二分查找以后，发现问题来自`CameraVector`这个节点。


这里为了查找问题直接把`CameraVector`的输出直接接到`BaseColor`上，Build HLOD来看。


![UE_HLOD_错误的法线-2025-06-13-21-23-36](https://img.blurredcode.com/img/UE_HLOD_错误的法线-2025-06-13-21-23-36.png?x-oss-process=style/compress)

- Simplify的结果似乎是每个面正对着拍的结果
- Approximate的结果似乎是斜着一点拍的

![UE_HLOD_错误的法线-2025-06-13-21-23-08](https://img.blurredcode.com/img/UE_HLOD_错误的法线-2025-06-13-21-23-08.png?x-oss-process=style/compress)


材质里这种和场景有关的节点应该都不太能获得正确的结果，想了下可能有问题的节点还挺多的:

- 从外部MPC获取数据的话需要考虑MPC的值
- 和Camera / WorldPosition有关的节点
- 和Time有关的节点

碰到以上这些效果只有想办法用`MaterialProxyReplace`来处理了...

