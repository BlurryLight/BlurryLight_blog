
---
title: "UE | HLOD优化 加快Build速度"
date: 2025-06-13T21:30:24+08:00
draft: false
categories: [ "UE"]
isCJKLanguage: true
slug: "3902fd43"
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


# 使用最后一级LOD的资源


虚幻默认HLOD Builder只提供了两个选项:
- 始终选择LOD0的资源
- 会使用一个1920x1080x45FOV 和某个距离的相机的投影矩阵计算一下LOD，使用这一级LOD的资源

对现在大量使用Nanite项目来说，LOD0可能是一个非常稠密的Mesh，导致Build HLOD的速度非常慢，内存要求也非常夸张，打包机性能差点可能都编不出来。

这里可以Hack一下引擎，选择Mesh的最后一级LOD，至少在日常迭代期可以使用这种HLOD，可以有效加快HLOD的Build速度。

# 分布式Build

参考:
[Distributing HLOD Building | Epic Developer Community](https://dev.epicgames.com/community/learning/knowledge-base/jP4m/unreal-engine-distributing-hlod-building)


虚幻给了一个像模像样的`BuildWorldPartitionHLODs.xml`的BuildGraph示例作为分布式编译的参考，但是没看懂怎么用的。对BuildGraph也不太熟。不过BuildGraph里也是调用的`commandlet`的指令，所以我们可以跟一下里面到底做了什么。

在HLOD Builder的`Commandlet`的源码注释里能翻到一些更多的信息


```c
// Engine/Source/Editor/UnrealEd/Private/WorldPartition/WorldPartitionHLODsBuilder.cpp
/*
	Working Dir structure
		/HLODBuilder0
			/Add
				NewFileA
				NewFileB
			/Delete
				DeletedFileA
				DeletedFileB
			/Edit
				EditedFileA
				EditedFileB

		/HLODBuilder1
			...
		/ToSubmit
			...

	Distributed mode
		* Distributed mode is ran into 3 steps
			* Setup (1 job)		
			* Build (N jobs)	
			* Submit (1 job)	
		
		* The Setup step will place files under the "HLODBuilder[0-N]" folder. Those files could be new or modified HLOD actors that will be built in the Build step. The setup step will also place files into the "ToSubmit" folder (deleted HLOD actors for example).
		* Each parallel job in the Build step will retrieve files from the "HLODBuilder[0-N]" folder. They will then proceed to build the HLOD actors as specified in the build manifest file. All built HLOD actor files will then be placed in the /ToSubmit folder.
		* The Submit step will gather all files under /ToSubmit and submit them.
		

		|			Setup			|					Build					  |		   Submit			|
		/Content -----------> /HLODBuilder -----------> /Content -----------> /ToSubmit -----------> /Content
*/

const FName FileAction_Add(TEXT("Add"));
const FName FileAction_Edit(TEXT("Edit"));
const FName FileAction_Delete(TEXT("Delete"));
```

具体上来说，分布式编译分为5个步骤:

1. 调用`-SetupHLODs -BuilderCount=N -DistributedBuild`  初始化分布式Build的参数，虚幻会搜集所有需要Build的HLODActors，并划分到不同的`HLODBuilder0`, `HLODBuilder1`, ... 目录下。还会生成一个额外的`HLODBuildManifest.ini`和`BuildProducts.txt`两个文件，记录HLODBuilder的一些信息。

2. 把生成的这些文件sync到其他机器上去
3. 每个机器上运行`-BuildHLODs -BuilderCount=N -DistributedBuild -BuilderIdx=X"`，每个机器会Build指定目录下的HLODActors，并将结果放到`HLODTemp`目录
4. 从每个机器上收集所有的`HLODTemp`目录下的结果文件，放到一个整体的`HLODTemp`目录下
5. 最后运行`-FinalizeHLODs -BuilderCount=N -DistributedBuild`，这个命令会把`HLODTemp`目录下生成好的HLOD Actor拷贝回工程目录，并上传到版本控制。


以上步骤里，虚幻做了`1,3,5`这三个步骤的命令行指令，`2,4`虚幻没提供解决方案，需要自己写脚本处理。另外假如有多个机器参与Build，那么这几台机器的工作空间需要同步到同一个版本，这个也需要自己写脚本来处理。


## 单机单工作空间多进程Build

对`HLOD`的Build过程进行性能分析发现，CPU平均只有`25% - 50%`的利用率，原因是很多时候会卡在单线程的一些重量级任务里，比如等待`UVAtlas`展UV。 虚幻默认是没实现多个`HLODActor`并行Build的，可能也比较困难把，毕竟Actor / UStaticMesh之类U类相关的函数都强制锁死单线程，想改成`ParallelFor`来做的话，除非对HLOD底层Build的代码非常熟悉，知道哪些地方要加锁，不然可能很难弄对。

另外一个思路就是既然一个进程没法把CPU利用满，那么开多个进程**模拟**分布式Build的效果，每个进程都Build一部分的HLOD Actors。这样就可以充分利用CPU资源了。 这部分虚幻也是有先例的，虚幻5.3以后打包时候Cook资源也是采用多进程Cook，在同一个工作空间里起了多个进程来Cook不同的资源，最后只需要把结果合并到一个目录下就行了。

## 在同一个工作空间起多个进程的一些小坑

1. 日志需要手动指定名字，虚幻默认会使用`<ProjectName>.log`的名字，如果多个进程起来会造成日志文件碰撞。 命令行可以通过指定`-abslog=xxx`指定日志名字
2. 命令行可以考虑给一个`-multiprocess`(多进程cook会带这个参数)，ue里很多地方会写文件的时候都会考虑这个参数，避免多个进程同时写同一个文件导致冲突。比如`AssetRegistryCache`
![UE_HLOD2_加快Build速度-2025-06-14-22-37-02](https://img.blurredcode.com/img/UE_HLOD2_加快Build速度-2025-06-14-22-37-02.png?x-oss-process=style/compress)

3. DDC碰撞问题。这个问题有点不太好解决，但是好像危害也不大。虚幻会在Build资源的时候更新并写入DDC，这样比如A进程和B进程同时加载到一个DDC缓存里没有的Texture,那么A和B都会试图更新DDC缓存。这个时候就会有两个进程同时写入同一个DDC缓存的文件。UE5.5以后会观察到在多进程Build的时候日志会有零零星星的`DDC Collision`的警告信息。 这个用了一个比较丑的方法绕开，就是启动Builder进程的时候依次延迟几十秒。这样会大大降低A/B进程同时加载到没有缓存的资源的概率(最开始起来的进程大概率已经更新过DDC了)，后面的进程会直接命中cache。

# 结果
经过以上的一些优化措施，我们极大的加快了HLOD的Build速度。
之前全量Build一次要2-3小时，优化以后全量只需要50分钟左右。
日常流水线的定时任务，每天晚上增量Build只需要二十分钟左右。

这对于调试HLOD的效果和性能是非常有帮助的，可以快速的迭代和测试HLOD的参数。