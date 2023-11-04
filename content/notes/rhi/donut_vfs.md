
---
title: "Donut virtual filesystem的设计"
date: 2023-11-04T17:08:17+08:00
draft: false
categories: [ "nvrhi"]
isCJKLanguage: true
slug: "0385ff99"
toc: true 
mermaid: false
fancybox: false
blueprint: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
---


{{% spoiler "笔记栏文章声明"%}} 
    {{% notice warning %}}
    笔记栏所记录文章往往未经校对，或包含错误认识或偏颇观点，亦或采用只有自身能够理解的记录。
    {{% /notice %}}
{{% /spoiler %}}


donut有一个vfs的设计，思想可能来自于linux，继承自VFS的只需要实现最基本的几个接口就可以了。
它主要是解决一个渲染框架去读取资源的问题。
一般渲染框架都会带一个类似的方案，比如根据自身的exe所在的位置去搜索`Resources`目录之类的。

#  fs::path的路径格式

- native format
- generic_format

在posix下两种没有区别。
在windows下，`generic_format`会用`/`，而`native-format`会用`\\`

https://github.com/MeouSker77/Cpp17/blob/master/markdown/src/ch20.md

![677fdcc8a4e49487c9111010ae1df80e.png](:/ea7e1289b7f440798c7c8d4c8a19e4ce)


一个有点意思的测试程序

```cpp
#include <filesystem>
#include <iostream>
namespace fs = std::filesystem;
int main()
{
    std::string strpath = "C:\\file.txt";
    fs::path path(strpath);
    std::cout << path.u8string() << std::endl;
    std::cout << path.generic_string() << std::endl;

    std::string str2path = "C:/file.txt";
    path = str2path;
    std::cout << path.u8string() << std::endl;
    std::cout << path.generic_string() << std::endl;
}

```

这段程序在MSVC/Mingw64 gcc上输出
```
C:\file.txt
C:/file.txt
```

而在WSL的GCC上输出
```
C:\file.txt
C:\file.txt
C:/file.txt
C:/file.txt
```


说明`generic_string`的处理与平台有关，而与编译器无关。我一开始以为他会根据path的内容来转，实际上不是。
- 在WIndows平台上，`generic_string`会把`\`转成`/`
- 在Linux平台上，即使出现`\`字符串，也不会转成`/`



# IFileSystem

```cpp
  // Basic interface for the virtual file system.
    class IFileSystem
    {
    public:
        virtual ~IFileSystem() = default;
        virtual bool folderExists(const std::filesystem::path& name) = 0;
        virtual bool fileExists(const std::filesystem::path& name) = 0;
        virtual std::shared_ptr<IBlob> readFile(const std::filesystem::path& name) = 0;
        virtual bool writeFile(const std::filesystem::path& name, const void* data, size_t size) = 0;
        virtual int enumerateFiles(const std::filesystem::path& path, const std::vector<std::string>& extensions, enumerate_callback_t callback, bool allowDuplicates = false) = 0;
        virtual int enumerateDirectories(const std::filesystem::path& path, enumerate_callback_t callback, bool allowDuplicates = false) = 0;
    };
```

# NativeFilesystem


`NativeFilesystem`基本上等于空实现，它要求传入的`Path`是系统Native的路径，比如`C:\test.txt`，`/home/`等这种路径。
然后所有的API都是直接通过`std::filesystem`相关的功能实现。

# RelativeFilesystem

`RelativeFileSystem`也没什么意思，他只是在其他的Filesystem上套了一层。
构建的时候需要保存一个`BasePath`，然后调用所有的API的时候，`RelativeFS`都会拼接路径。



```cpp
class RelativeFileSystem : public IFileSystem
{
private:
    std::shared_ptr<IFileSystem> m_UnderlyingFS;
    std::filesystem::path m_BasePath;
public:
    RelativeFileSystem(std::shared_ptr<IFileSystem> fs, const std::filesystem::path& basePath);

    [[nodiscard]] std::filesystem::path const& GetBasePath() const { return m_BasePath; }

    bool folderExists(const std::filesystem::path& name) override;
    bool fileExists(const std::filesystem::path& name) override;
    std::shared_ptr<IBlob> readFile(const std::filesystem::path& name) override;
    bool writeFile(const std::filesystem::path& name, const void* data, size_t size) override;
    int enumerateFiles(const std::filesystem::path& path, const std::vector<std::string>& extensions, enumerate_callback_t callback, bool allowDuplicates = false) override;
    int enumerateDirectories(const std::filesystem::path& path, enumerate_callback_t callback, bool allowDuplicates = false) override;
};
```


比如`fileExists`的实现

```cpp
std::shared_ptr<IBlob> RelativeFileSystem::readFile(const std::filesystem::path& name)
{
    return m_UnderlyingFS->readFile(m_BasePath / name.relative_path());
}
```

最常见的使用方式是先构建一个NativeFileSystem作为底层，然后将某个路径传进去。
这样可以通过直接输入文件名来访问 basePath /filename。


# RootFileSystem

RootFileSystem是最接近Linux的，它允许我们将某个路径**挂载**到某个挂载点，然后通过挂载后的路径访问。

```cpp
vfs::RootFileSystem rootFS;
rootFS.mount("/tests", "/home/user/");
rootFS.fileExists("/tests/CMakeLists.txt"); // 等于访问 /home/user/CMakeLists.txt
```

它的核心逻辑在

```cpp
bool RootFileSystem::findMountPoint(const std::filesystem::path& path, std::filesystem::path* pRelativePath, IFileSystem** ppFS)
{
    // 传入Path /tests/CMakeLists.txt,正规化
    std::string spath = path.lexically_normal().generic_string();

    for (auto it : m_MountPoints) // m_MountPoints : pair{"/tests",IFileSystem*}
    {
        // 这里通过字符串去匹配前面的几个字符，要求完全匹配上
        if (spath.find(it.first, 0) == 0 && ((spath.length() == it.first.length()) || (spath[it.first.length()] == '/')))
        {
            // 这里返回CMakeLists.txt
            if (pRelativePath)
            {
                std::string relative = spath.substr(it.first.size() + 1);
                *pRelativePath = relative;
            }
            // 并且返回保存的IFileSystem
            if (ppFS)
            {
                *ppFS = it.second.get();
            }

            return true;
        }
    }

    return false;
}
```

所以`RootFileSystem`需要和`RelativeFileSystem`搭配着使用。
因为它在访问`/test/CMakeLists`这种路径的时候，会把匹配上的mount point (`/test`)转为保存的IFileSystem,再通过`CMakeLists.txt`这个名字去访问。

如果是`NativeFilesystem`的话，需要通过愚蠢的路径去访问。

```cpp
// 未测试
std::shared_ptr<NativeFileSystem> nativeFS = std::make_shared<NativeFileSystem>();
m_RootFs = std::make_shared<RootFileSystem>();
m_RootFs->mount("/native", nativeFS);
m_RootFs->fileExists("/native//home/user/CMakeLists.txt");
```
```