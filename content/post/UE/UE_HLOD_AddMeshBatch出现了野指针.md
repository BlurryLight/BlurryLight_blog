
---
title: "UE | HLOD AddMeshBatch中MaterialRenderProxy出现了野指针"
date: 2026-08-25T21:35:02+08:00
draft: false
categories: [ "UE"]
isCJKLanguage: true
slug: "7b30bbca"
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

最近，在HLOD Build过程中发现了一个比较稳定的崩溃问题...

# AddMeshBatch 稳定触发崩溃，MaterialRenderProxy成为了野指针

```cpp
void FBasePassMeshProcessor::AddMeshBatch(const FMeshBatch& RESTRICT MeshBatch, uint64 BatchElementMask, const FPrimitiveSceneProxy* RESTRICT PrimitiveSceneProxy, int32 StaticMeshId)
{
	if (MeshBatch.bUseForMaterial)
	{
		// Determine the mesh's material and blend mode.
		const FMaterialRenderProxy* MaterialRenderProxy = MeshBatch.MaterialRenderProxy;
		while (MaterialRenderProxy)
		{
			const FMaterial* Material = MaterialRenderProxy->GetMaterialNoFallback(FeatureLevel);
			if (Material && Material->GetRenderingThreadShaderMap())
			{
				if (TryAddMeshBatch(MeshBatch, BatchElementMask, PrimitiveSceneProxy, StaticMeshId, *MaterialRenderProxy, *Material))
				{
					break;
				}
			}

			MaterialRenderProxy = MaterialRenderProxy->GetFallback(FeatureLevel);
		}
	}
}
```


![UE_HLOD_AddMeshBatch出现了野指针-2026-08-25-21-36-27](https://img.blurredcode.com/img/UE_HLOD_AddMeshBatch出现了野指针-2026-08-25-21-36-27.png?x-oss-process=style/compress)


MeshBatch持有的MaterialRenderProxy和U类的生命周期有直接联系，并且他是裸指针，如果U类静默销毁了，那么确实可能存在这个问题


# ProxyLOD的生成

经过多次定位，发现在出现问题的时候，GameThread的堆栈总是很稳定出现在LODActor的生成过程中。


```cpp
void FProxyGenerationProcessor::ProcessJob(const FGuid& JobGuid, FProxyGenerationData* Data)
{
	TArray<UObject*> OutAssetsToSync;
	const FString AssetBaseName = FPackageName::GetShortName(Data->MergeData->ProxyBasePackageName);
	const FString AssetBasePath = Data->MergeData->InOuter ? TEXT("") : FPackageName::GetLongPackagePath(Data->MergeData->ProxyBasePackageName) + TEXT("/");

	UMaterialInstanceConstant* ProxyMaterial = nullptr;

	if (!Data->RawMesh.IsEmpty())
	{
		Data->MergeData->InProxySettings.MaterialSettings.ResolveTextureSize(Data->RawMesh);

		// Don't recreate render states with the material update context as we will manually do it through
		// the FStaticMeshComponentRecreateRenderStateContext below
		FMaterialUpdateContext MaterialUpdateContext(FMaterialUpdateContext::EOptions::Default & ~FMaterialUpdateContext::EOptions::RecreateRenderStates);

		// Retrieve flattened material data
		FFlattenMaterial& FlattenMaterial = Data->Material;

		// Resize flattened material
		FMaterialUtilities::ResizeFlattenMaterial(FlattenMaterial, Data->MergeData->InProxySettings);

		// Optimize flattened material
		FMaterialUtilities::OptimizeFlattenMaterial(FlattenMaterial);

		// Create a new proxy material instance
		ProxyMaterial = FMaterialUtilities::CreateFlattenMaterialInstance(Data->MergeData->InOuter, Data->MergeData->InProxySettings.MaterialSettings, Data->MergeData->BaseMaterial, FlattenMaterial, AssetBasePath, AssetBaseName, OutAssetsToSync, &MaterialUpdateContext);

		for (IMeshMergeExtension* Extension : Owner->MeshMergeExtensions)
		{
			Extension->OnCreatedProxyMaterial(Data->MergeData->StaticMeshComponents, ProxyMaterial);
		}

		// Set material static lighting usage flag if project has static lighting enabled
		if (IsStaticLightingAllowed())
		{
			ProxyMaterial->CheckMaterialUsage(MATUSAGE_StaticLighting);
		}
	}

	// Construct proxy static mesh
	UPackage* MeshPackage = Data->MergeData->InOuter;
	FString MeshAssetName = TEXT("SM_") + AssetBaseName;
	if (MeshPackage == nullptr)
	{
		MeshPackage = CreatePackage( *(AssetBasePath + MeshAssetName));
		MeshPackage->FullyLoad();
		MeshPackage->Modify();
	}

	UStaticMesh* OldStaticMesh = FindObject<UStaticMesh>(MeshPackage, *MeshAssetName);

	FStaticMeshComponentRecreateRenderStateContext RecreateRenderStateContext(OldStaticMesh);

...
```

这里的步骤很长，
但是大概的过程是:
1. 找到旧的HLODActor
2. 烘一个新的材质上去
3. 把之前已经烘好的新的HLOD Mesh替换上去


这里和材质的替换有关系，所以非常可疑，尤其是涉及到新旧Material的替换。
会不会是旧的材质仍在使用，新的材质替换上去了?


## 在一个Package里New一个已经存在的UObject？


在经过一连串复杂的跟踪后，我发现了一个奇怪的代码

![UE_HLOD_AddMeshBatch出现了野指针-2026-08-25-21-40-16](https://img.blurredcode.com/img/UE_HLOD_AddMeshBatch出现了野指针-2026-08-25-21-40-16.png?x-oss-process=style/compress)

这里有对旧的资产的检查，但是如果它原来就是材质，则什么都不做，直接用同名new了一个。

在一个UPackage里New一个同名的UObject的行为会是什么样呢，在没有看实现之前，合理的推断可能是 1. 会New不出来，报错  2. New出来，静默替换 3. New出来，重命名成一个新的名字。无论是哪一个行为，在HLOD烘焙这个场景下都看起来不太妙。

详细跟进去，发现在NewObject发现在目标Pacakge有同名的UObject的时候，会尝试`Obj->ConditionalBeginDestroy()`销毁旧的UObject并创建新的UObject...

所以Bug很明显，这里直接把旧的材质销毁了...而渲染层还引用着这里的材质呢。

```cpp
			if(!Obj->HasAnyFlags(RF_FinishDestroyed))
			{
				if (FPlatformProperties::RequiresCookedData())
				{
					ensureAlwaysMsgf(!Obj->HasAnyFlags(RF_NeedLoad|RF_WasLoaded),
						TEXT("Replacing a loaded public object is not supported with cooked data: %s (Flags=0x%08x, InternalObjectFlags=0x%08x)"),
						*Obj->GetFullName(),
						InOuter ? *InOuter->GetFullName() : TEXT("NULL"),
						(int32)Obj->GetFlags(),
						(int32)Obj->GetInternalFlags());
				}

				// Get the name before we start the destroy, as destroy renames it
				FString OldName = Obj->GetFullName();

				// Begin the asynchronous object cleanup.
				Obj->ConditionalBeginDestroy();
```


# 修复补丁

找到问题就好了，这里可以加双保险

1. 新的材质替换上去的时候，用`MakeUniqueObjectNmae`
2. 旧的材质可以从package里移出来，挂给引擎的TransientPacakge这个临时Pacakge(这是一个巧妙地删除UObject的方法，把它挂给`TransientPackage`)

下面是添加上去的代码

```cpp

UMaterialInstanceConstant* FMaterialUtilities::CreateInstancedMaterial(UMaterialInterface* BaseMaterial, UPackage* InOuter, const FString& BaseName, EObjectFlags Flags)
{
	...
// We need to check for this due to the change in material object type, this causes a clash of path/type with old assets that were generated, so we delete the old (resident) UMaterial objects
	UObject* ExistingPackage = FindObject<UMaterial>(MaterialOuter, *MaterialAssetName);
	if (ExistingPackage && !ExistingPackage->IsA<UMaterialInstanceConstant>())
	{
#if WITH_AUTOMATION_TESTS
		FAutomationEditorCommonUtils::NullReferencesToObject(ExistingPackage);		
#endif // WITH_AUTOMATION_TESTS
		ExistingPackage->MarkAsGarbage();
		CollectGarbage(GARBAGE_COLLECTION_KEEPFLAGS, true);
	}
	//++ravenzhong NewObject Silently destroy old asset
	if (UMaterialInstanceConstant* ExistingMaterialInstance = FindObject<UMaterialInstanceConstant>(MaterialOuter, *MaterialAssetName))
	{
		UPackage* TransientPackage = GetTransientPackage();
		const FName TransientName = MakeUniqueObjectName(TransientPackage, ExistingMaterialInstance->GetClass(), ExistingMaterialInstance->GetFName());
		const FString TransientNameString = TransientName.ToString();
		const FString OldPathName = ExistingMaterialInstance->GetPathName();
		if (!ExistingMaterialInstance->Rename(*TransientNameString, TransientPackage, REN_DontCreateRedirectors | REN_DoNotDirty))
		{
			UE_LOG(LogMaterialUtilities, Warning, TEXT("Failed to move existing material instance '%s' to '%s.%s' before recreating."),
				*OldPathName,
				*GetPathNameSafe(TransientPackage),
				*TransientNameString);
			return nullptr;
		}

		ExistingMaterialInstance->ClearFlags(RF_Public | RF_Standalone);
		ExistingMaterialInstance->SetFlags(RF_Transient);
	}
	//--ravenzhong

	UMaterialInstanceConstant* MaterialInstance = NewObject<UMaterialInstanceConstant>(MaterialOuter, FName(*MaterialAssetName), Flags);
	checkf(MaterialInstance, TEXT("Failed to create instanced material"));
	MaterialInstance->Parent = BaseMaterial;
	
	return MaterialInstance;

```




