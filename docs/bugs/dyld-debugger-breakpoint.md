# Bug: dyld 镜像通知断点导致真机启动时暂停

## 现象

在真机（iPhone）上通过 Xcode Debug 模式启动 App 时，lldb 停在以下位置之一：

```
// 形式 1
dyld`lldb_image_notifier:
->  0x19d7da8f8 <+0>: ret

// 形式 2（同问题，调用链更深一层）
#0  0x000000019d7daa08 in dyld4::ExternallyViewableState::triggerNotifications ()
```

点击继续后 App 正常运行，没有崩溃。每次冷启动必断一次。

## 原因

这是 dyld 向 lldb 发送镜像加载通知的断点。
触发来源有 3 种可能，按概率从高到低排查：

### 原因 A（最常见）：Xcode 断点导航栏中有 "All Exceptions" 或符号断点

Xcode 的断点导航栏（⌘8）中，如果存在以下断点类型，就会拦截 dyld 通知：

- **All Exceptions** 断点：拦截所有 objc_exception_throw，连带着也触发 dyld 通知器
- **Debugger 断点**（Xcode 自动添加）：显示为小箭头图标
- **Dynamic Linker API Usage 断点**：Xcode 15+ 新增的自动断点

### 原因 B（常见）：Xcode Scheme 的 Dynamic Linker API Usage 勾选了

Product → Scheme → Edit Scheme → Run → Diagnostics → **Log Runtime Issues > Dynamic Linker API Usage**
这个在 Debug 模式下默认开启。

### 原因 C（较少见）：全局 .lldbinit 或符号断点文件

~/.lldbinit 或项目中存在断点配置文件。

## 修复步骤（按顺序操作）

### 第一步：检查断点导航栏（⌘8）

这是最有可能是原因的地方。
1. 在 Xcode 中按 **⌘8** 打开断点导航栏
2. 看有没有高亮（蓝色）的断点
3. **如果有 "All Exceptions" 断点**，右键 → **Delete Breakpoint**
4. **如果有名字带 "dyld"、"debugger"、"image_notifier" 的符号断点**，全部删掉
5. **如果有你不确定来源的断点**，截图给我看

> 注意：即使你没手动添加过断点，Xcode 有时也会自动生成一个
> "Debugger 断点"（显示为一个蓝色小箭头），这就是元凶。

### 第二步：检查 Scheme 的 Diagnostics 设置

1. **Product → Scheme → Edit Scheme（⌘<）**
2. 左侧选 **Run**，顶部选 **Diagnostics**
3. 找到 **Log Runtime Issues** 右边的下拉菜单
4. **取消勾选 "Dynamic Linker API Usage"**
5. 关闭，Clean Build（⌘⇧K → ⌘R）

### 第三步：检查全局 lldb 配置

在终端里看有没有全局配置文件：

```bash
cat ~/.lldbinit
```

如果有内容，执行过 `command source ~/.lldbinit` 可能会引入断点。

## 已验证无效的方案（不用再试了）

1. ~~仅关闭 Scheme 的 Dynamic Linker API Usage~~（可能还需要配合断点导航栏清理）
2. ~~在 lldb 里输入 process handle SIGSTOP~~（治标不治本，下次编译又回来）

## 应急处理

如果在调试中断住，在 lldb 控制台输入以下命令**直接跳过**：

```
thread step-over
continue
```

或者直接点击 Xcode 左上角的 **继续执行按钮**（▶️ 在暂停按钮旁边）。

## 如果以上三步都试过还不行

大概率是你在 Xcode 的断点导航栏里有一个**蓝色的隐藏断点**。
请在 Xcode 中按 **⌘8**，把当前所有断点都截图给我看。
或者在断点导航栏左下角点 **+ → Delete All Breakpoints**（但这会删掉你手动加的所有断点，谨慎操作）。

## 首次发现

2026-05-31, iPhone 真机 Debug 启动时触发。
