
---
title: "UE4 Compilation Process Affinity with Intel 12th Gen CPU on Windows 10"
date: 2023-04-13T23:58:44+08:00
draft: false
categories: [ "UE"]
isCJKLanguage: true
slug: "bc4cbce3"
toc: true 
mermaid: false
fancybox: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
---

# Slow Compilation


Today, I've compiled a UE 4.26 release on an `Intel i7 12700` CPU (a heterogeneous archtecture with 8-Cores and 4 E-cores ) running the latest Win10 22H2 system.

However, the compilation was noticeably slower than on an older AMD CPU.
With the task manager, I observed my cpu utilization was between 30% and 50% and it appeared all compilers were running on the E-Cores.

![UE4-Compilation-Process-Affinity-On-Win10-2023-04-15-12-42-43](https://img.blurredcode.com/img/UE4-Compilation-Process-Affinity-On-Win10-2023-04-15-12-42-43.png?x-oss-process=style/compress)

After some research, I found there is another similar problem on Epic Forum [Intel 12th Gen Shader Compilation Process Affinity - Community / Community & Industry Discussion - Epic Developer Community Forums](https://forums.unrealengine.com/t/intel-12th-gen-shader-compilation-process-affinity/268288).
Although, the issue in the post pertains to ShaderCompileWorkder rather than `MSVC`, it does point out that the problem may be related to process affinity.
As far as know, there are notorious bugs related to task sheduling on heterogeneous CPUs with Win10.


# Quick Fix

Some minor modifications are needed on UBT and `BaseEngine.ini`.
- The process affinity is hardcoded as `ProcessPriorityClass.BelowNormal` in UE 4.26. We need to expose it as an `XmlConfigFile` variable and modify it in `BuildConfiguration.xml`.
- `BaseEngine.ini` has an entry about the priority of `ShaderCompileWorker` 

<pre><code>--- a/Engine/Config/BaseEngine.ini
+++ b/Engine/Config/BaseEngine.ini
@@ -1299,7 +1299,7 @@ WorkerTimeToLive=20
 ; For build machines, wait this many seconds before exiting an unused worker (float value)
 BuildWorkerTimeToLive=1200
 ; Set process priority for ShaderCompileWorker (0 is normal)
-WorkerProcessPriority=-1
+WorkerProcessPriority=0
 
 ; These values are for build machines only currently to reduce the number of SCWs spawned to reduce memory pressure
 bUseVirtualCores = False

--- a/Engine/Source/Programs/UnrealBuildTool/Executors/ParallelExecutor.cs
+++ b/Engine/Source/Programs/UnrealBuildTool/Executors/ParallelExecutor.cs
@@ -50,6 +50,9 @@ namespace UnrealBuildTool
 		[XmlConfigFile]
 		bool bStopCompilationAfterErrors = false;
 
+		[XmlConfigFile]
+		private static ProcessPriorityClass <span class = "inlinehl">ProcessPriority</span> = ProcessPriorityClass.BelowNormal;
+
 		/// <summary>
 		/// How many processes that will be executed in parallel
 		/// </summary>
@@ -272,7 +275,7 @@ namespace UnrealBuildTool
 
 			try
 			{
-				using (ManagedProcess Process = new ManagedProcess(ProcessGroup, Action.Inner.CommandPath.FullName, Action.Inner.CommandArguments, Action.Inner.WorkingDirectory.FullName, null, null, ProcessPriorityClass.BelowNormal))
+				using (ManagedProcess Process = new ManagedProcess(ProcessGroup, Action.Inner.CommandPath.FullName, Action.Inner.CommandArguments, Action.Inner.WorkingDirectory.FullName, null, null, <span class="inlinehl">ProcessPriority</span>))
 				{
 					Action.LogLines.AddRange(Process.ReadAllLines());
 					Action.ExitCode = Process.ExitCode;
--
</code></pre>

Then go to `Engine\Saved\UnrealBuildTool\BuildConfiguration.xml` or `C:\Users\<username>\AppData\Roaming\Unreal Engine\UnrealBuildTool\BuildConfiguration.xml`.
Both files will work but the former is preferred. The latter one is global which means it will affect all installed versions of UE on the computer.

```xml
<Configuration xmlns="https://www.unrealengine.com/BuildConfiguration">
    <ParallelExecutor>
        <ProcessPriority>Normal</ProcessPriority>
    </ParallelExecutor>
</Configuration>
```