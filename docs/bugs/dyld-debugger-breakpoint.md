# Bug: dyld `_dyld_debugger_notification` 断点导致真机启动时暂停

## 现象

在真机（iPhone）上通过 Xcode Debug 模式启动 App 时，lldb 停在：

```
dyld`lldb_image_notifier:
->  0x19d7da8f8 <+0>: ret
```

点击继续后 App 正常运行，没有崩溃。每次冷启动都会断一次。

## 原因

Xcode 在 Debug 模式下调试真机时，dyld 会在加载动态库时调用
`_dyld_debugger_notification` 向调试器发 SIGSTOP。
这是 Xcode 的"Dynamic Linker API Usage"检测功能做的，
目的是帮你发现动态库加载相关的问题（非内存泄漏，纯调试辅助）。

## 修复步骤（在 Xcode 中操作）

1. Xcode 菜单栏 → **Product → Scheme → Edit Scheme**（或快捷键 `⌘<`）
2. 左侧选择 **Run** → 顶部分页选 **Diagnostics**
3. 在 **Runtime API Checking** 区域 → **取消勾选 "Log Runtime Issues > Dynamic Linker API Usage"**
4. 关闭窗口，重新 Clean Build（`⌘⇧K` 再 `⌘R`）

搞定。之后真机启动不会再在这个断点停住。

## 没 Xcode 时的现场处理

如果已经在调试中断住，在 lldb 控制台输入：

```
process handle SIGSTOP -n false -p true -s false
continue
```

即可继续，当前会话后续不会再停在这个断点。

## 首次发现

2026-05-31, iPhone 真机 Debug 启动时触发。
