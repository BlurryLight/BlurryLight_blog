
---
title: "CPP线程池的实现"
date: 2020-12-01T20:51:22+08:00
draft: false
# tags: [ "" ]
categories: [ "cpp"]
# keywords: [ ""]
lastmod: 2020-12-01T20:51:22+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "Cpp线程池的实现"
toc: false
# latex support
# katex: true
# markup: mmark
---

在DiRender中有一份 [C++线程池](https://github.com/BlurryLight/DiRender/blob/master/src/utils/thread_pool.hpp) ，主要用于渲染中的图像的分块并行。
这个线程池大概是从 [thread pool](https://github.com/mtrebi/thread-pool) 或者其他的项目中改过来的。

# 为什么需要有线程池
在早期的我的某个版本渲染器中，是没有线程池的，起初为了实现并行渲染我设计的每一行像素一个线程，一张200x200的图片要使用200个线程，按照每个线程2MB的栈内存开销，开销400M。但是当图片到2000x2000的分辨率的时候，内存的开销就相当大了。其实线程池的思想还是比较容易理解的：有一定数量的线程，当消费者角色不断的从一个线程共享的队列取出任务执行。
但是实现起来还是有一定的难度，主要是线程池需要执行的是具有**不同签名的函数**，而我们只有一个容器，所以必须要对**任务**进行装箱，涉及到模板编程。

## 装箱的实现
```cpp
template <typename F, typename... Args>
decltype(auto) ThreadPool::enqueue_task(F &&func, Args &&... args) {
  using res_type = typename std::result_of<F(Args...)>::type;
  auto task = std::make_shared<std::packaged_task<res_type()>>(
      std::bind(std::forward<F>(func), std::forward<Args>(args)...));
  std::future<res_type> res = task->get_future();
  {
    std::unique_lock<std::mutex> lk(queue_mutex_);
    if (!this->stop_) {
      tasks_.emplace([task]() { (*task)(); });
    }
  }
  this->queue_cv_.notify_one();
  return res;
}
```

- 函数签名里由于函数返回的是`std::future<res_type>`类型，而`res_type`类型是从传入的函数指针的返回值决定的，因此我们不可能显式写出返回值类型，只能依靠编译器的类型推断`decltype(auto)`。
- 进入到函数体内，首先我们使用`std::bind(std::forward<F>(func), std::forward<Args>(args)...)`将函数指针和它的参数绑定起来，返回一个`std::function<res_type()>`类型的强类型函数对象。
- 其次我们使用`std::packaged_task<res_type()>`将之前返回的function对象打包，这允许我们将它转到异步操作，因此我们可以将这个异步操作的返回值和一个`std::future`绑定起来，我们可以拿到`future`作为返回值，但是这个返回值只有在异步操作真正被执行以后才有效。这允许我们不用阻塞在这里就可以拿到返回值。
- 然后我们使用`std::make_shared`将`std::packaged_task`再打一次包，因为`std:package_task`是一个禁止了拷贝操作的值类型, 我们不能随意拷贝它，并且我们需要延长它的生命周期到至少`queue`执行完毕，因此用`shared_ptr`管理它是一个合理的操作。
- 最后我们还需要再进行类型擦除一次。因为现在的类型是`std::shared_ptr<std::packaged_task<res_type()>>`，这个类型依赖`res_type`。我们再将其打包一次，令一个匿名函数捕获它，然后执行这个指针,这样我们成功的把类型统一到了`std::function<void()>`，类型擦除以后的函数就可以入队了，并且我们之前已经拿到了返回值`std::future<res_type>`。我们只需要检查future的状态就可以拿到异步执行的返回值了。
```cpp
std::function<void()> wrapperfunc = [task_ptr]() {
  (*task_ptr)(); 
};
```