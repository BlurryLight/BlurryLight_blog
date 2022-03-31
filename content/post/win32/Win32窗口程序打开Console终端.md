
---
title: "Win32窗口程序打开Console终端"
date: 2022-03-31T18:29:34+08:00
draft: false
# tags: [ "" ]
categories: [ "win32"]
# keywords: [ ""]
# lastmod: 2022-03-31T18:29:34+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "cb7ce10f"
toc: true
mermaid: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
---

默认的`Win32`窗口程序(subsystem:Windows)，入口点为`WinMain`的程序是不会显示Console终端的，意味着`std::cout`一系列的函数都不能用。

要想在执行程序的时候同时打开黑框(Console)有两种方式

# 改变Link符号和入口点

可以通过以下的链接指令修改入口点到`mainCRTStartup`，也可以在`Properties->Linker->System->Subsystem`里修改为`Console`，这样入口点也会调整到`mainCRTStartup`。
```
#ifdef _MSC_VER
#    pragma comment(linker, "/subsystem:windows /ENTRY:mainCRTStartup")
#endif
```

此时程序启动的时候会正常调用`int main`函数，相较于`winMain`函数其主要少了重要的`hInstance`参数，可以通过`GetModuleHandle(0)`获得当前窗口的`hInstance`。

`int main()`和`winMain()`的区别可以见: [程序入口函数 main 和 WinMain](https://kindof.net/noyesno/blog/20200507-9b4f8843)

```cpp
int main()
{
	auto hInstance = GetModuleHandle(0);
	GameApp theApp(hInstance);
	HINSTANCE prev  = NULL;
	LPSTR     cmdline = GetCommandLineA();
	int       showCmd;
	if (!theApp.Init())
		return 0;

	return theApp.Run();
}

```

# 在WinMain函数里重新启用Console
还有一种方式是在`WinMain`函数里重新启用Console，注意最好在其他代码运行前启用。
需要启用宏`#define _CRT_SECURE_NO_WARNINGS`，或者用微软的私活`freopen_s`。

```
#define _CRT_SECURE_NO_WARNINGS
#include <cstdio>
#include <iostream>

int WINAPI WinMain(_In_ HINSTANCE hInstance, _In_opt_ HINSTANCE prevInstance,
	_In_ LPSTR cmdLine, _In_ int showCmd)
{
    //注意这块
	AllocConsole();
	freopen("CONIN$", "r", stdin);
	freopen("CONOUT$", "w", stdout);
	freopen("CONOUT$", "w", stderr);
	std::cout << "Hello\n"; //you should see this on the console
	// other code

	GameApp theApp(hInstance);

	if (!theApp.Init())
		return 0;

	return theApp.Run();
}



```