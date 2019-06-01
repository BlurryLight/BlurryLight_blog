---
layout: post
cid: 351
title: "Python利用Qtcreator和Pyqt快速创建GUI"
slug: python-利用qtcreator和pyqt快速创建gui
date: 2016-02-28
updated: 2019-03-07
status: publish
author: panda
categories: 
  - Python
tags: 
---


利用qtcreator创建简单的界面很容易，生成一个xml格式化的ui文件，再在python里面载入这个ui文件即可快速编写GUI。关于按钮点击等编写qtcreator同样可以完成。


<!--more-->


输入以下代码:
```python
#!/usr/bin/env python3
# encoding: utf-8

from PyQt5 import uic,QtWidgets
import sys
#Enter file path
qtCreatorFile = "dialog.ui" 
Ui_MainWindow, QtBaseClass = uic.loadUiType(qtCreatorFile)

class build(Ui_MainWindow,QtWidgets.QMainWindow):
    def __init__(self,parent = None):
        QtWidgets.QMainWindow.__init__(self)
        Ui_MainWindow.__init__(self)
        self.setupUi(self)

def start():
    app = QtWidgets.QApplication(sys.argv)
    bld = build()
    bld.show()
    sys.exit(app.exec_())
if __name__ == '__main__':
    start()
```


这样就成功载入ui了，而且修改界面只需要在qtcreator内部修改，不需要再对代码进行大修特修
