# 拼豆颜色管理 iOS App

原生 iOS 颜色管理 App，技术栈为 SwiftUI + SwiftData，首版只面向 iPhone 和 iOS 17+。

## 打开工程

```bash
open ios/PindouColors.xcodeproj
```

当前机器只有 Command Line Tools，没有完整 iPhone SDK，所以这里无法用 `xcodebuild` 编译。安装完整 Xcode 后，用 Xcode 打开工程即可运行到 iPhone 模拟器或真机。

## 已实现范围

- SwiftData 本地颜色模型
- 仓库式首页：统计、搜索、系列筛选、排序、网格/列表切换
- 颜色卡片和编辑弹层
- 从 `https://www.pindou.online/colors` 同步解析
- 粘贴 HTML 离线导入
- CSV 和 JSON 备份导出服务
- 导入解析和去重逻辑测试

