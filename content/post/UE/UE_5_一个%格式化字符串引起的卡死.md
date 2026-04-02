
---
title: "UE | 一个错误的%格式化字符串引起的卡死"
date: 2026-04-02T22:24:58+08:00
draft: false
categories: [ "UE"]
isCJKLanguage: true
slug: "9fd71eb9"
toc: true
mermaid: false
fancybox: false
blueprint: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
# UEVersion: 5.3.2 
---


真机打包后的包，在 vivo 某台手机上频繁出现卡死无响应。

经过多次实验后，发现每次卡死前都会出现一条固定日志（在 Android 上表现为 ANR，应用失去响应）。

`nativeBatteryEvent(stat = xxx`

https://github.com/EpicGames/UnrealEngine/blob/7643252dbc0e275505d4afe5094778fc80aae0c0/Engine/Source/Runtime/Core/Private/Android/AndroidPlatformMisc.cpp#L366


这条日志是“非充分但必要条件”：出现它不一定会卡死，但发生卡死时一定会出现它。

仔细看了这段代码后，发现这里的 `printf` 存在未定义行为：

```c
	struct FBatteryReceiver: Java::Lang::FObject
	{
		static constexpr FAnsiStringView ClassName = "com/epicgames/unreal/BatteryReceiver";
		
		static void JNICALL dispatchEvent(JNIEnv * jni, jclass clazz, jint status, jint level, jint temperature)
		{
			FPlatformMisc::LowLevelOutputDebugStringf(TEXT("nativeBatteryEvent(stat = %i, lvl = %i %, temp = %3.2f \u00B0C)"), status, level, float(temperature)/10.f);

			ReceiversLock.Lock();
			const bool bWasInLowPowerMode = CurrentBatteryState.Level <= GAndroidLowPowerBatteryThreshold;

			FAndroidMisc::FBatteryState state;
```

这里在 `%i %` 后面试图打印一个百分号，但正确写法应该是 `%%`。因此这里构造了一个错误的格式化字符串，可能导致 `printf` 在运行时出现异常行为（例如读到错误内存，甚至卡死）。


修复这个格式化字符串后，真机上的卡死问题消失。

PS:
截至目前，UE 最新主线仍未修复这个问题。
