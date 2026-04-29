# 二进制重排设计

## 目标

通过 Clang SanitizerCoverage 插桩采集冷启动阶段函数调用顺序，生成 order file，配置链接器重排二进制符号布局，减少冷启动 Page Fault 数量。

## 背景

### 为什么冷启动有 Page Fault

iOS 使用虚拟内存 + 懒加载机制。App 的 Mach-O 二进制 `__TEXT` 段按 **16KB 页**（arm64）映射到虚拟内存，但物理页只在首次访问时才从磁盘加载——触发一次 **Page Fault**（也叫 Page In）。

默认情况下，函数在二进制中的排列顺序由**编译单元的链接顺序**决定，和启动时的调用顺序无关。启动阶段调用的函数散落在大量不同的页中，导致大量 Page Fault。每次 Page Fault 耗时约 0.1-0.8ms（取决于设备和存储状态），累积起来可达几十甚至上百毫秒。

### 解决思路

给链接器提供一个 order file（符号排列顺序文件），把启动阶段调用的函数集中排列到连续的几页内。原本需要加载 N 页散落的函数，重排后只需加载少量连续页，Page Fault 数量大幅减少。

## 第一步：测量基线 Page Fault

**在优化之前，必须先获取当前冷启动的 Page Fault 数量作为基线。**

### 方法：Instruments System Trace

1. 确保使用**真机**（模拟器的虚拟内存行为不准确）
2. 从后台彻底杀掉 App（上滑移除），确保是冷启动
3. Xcode → Product → Profile（Cmd+I）→ 选择 **System Trace**
4. 点击录制按钮，App 自动启动
5. 等首屏完全渲染后（约 2-3 秒），点停止录制
6. 在 System Trace 界面：
   - 底部筛选进程：选择 `WeChatSwift`
   - 展开 **Virtual Memory** 行
   - 查看 **File Backed Page In** 的 **Count** 列
7. 记录该数值，这就是冷启动的 Page Fault 基线

### 注意事项

- 每次测量前**必须杀掉 App**，否则页面已缓存在内存中，不会触发 Page Fault
- 建议测 3 次取平均值，消除波动
- 如果设备刚重启，第一次冷启动的 Page Fault 会偏高（系统缓存为空），可先跑一次预热再开始测量

### 预期基线

练习项目体量小，预期 Page Fault 在 **100-500** 次左右。大型 App（如微信、抖音）通常在 **1000-3000+** 次。

## 架构

```
编译期（插桩）:
  Clang -fsanitize-coverage=func,trace-pc-guard
  → 每个函数入口插入 __sanitizer_cov_trace_pc_guard 调用
  → 作用于主工程 + 所有 Pod 静态库

运行期（采集）:
  App 启动 → 函数被调用 → trace_pc_guard 记录地址到原子数组
       ↓
  firstFrame 触发（RunLoop beforeWaiting）
       ↓
  OrderFileGenerator:
    1. 读取原子数组中所有 PC 地址
    2. dladdr() 解析每个地址 → 符号名
    3. 去重保序（保留首次出现顺序）
    4. 写入沙盒 Documents/app.order
    5. print 文件路径到控制台

产出应用:
  1. 从真机沙盒取出 app.order
  2. 放入项目根目录
  3. project.yml 配置 ORDER_FILE
  4. 关闭插桩 flag
  5. 重新编译
  6. 再次 System Trace 对比 Page Fault
```

### 文件结构

| 文件 | 动作 | 职责 |
|------|------|------|
| `WeChatSwift/ClangTraceCollector.c` | 新建 | SanitizerCoverage 回调，原子数组记录 PC 地址 |
| `WeChatSwift/ClangTraceCollector.h` | 新建 | 函数接口暴露 PC 数据给 Swift（不直接 extern atomic 变量） |
| `WeChatSwift/WeChatSwift-Bridging-Header.h` | 新建 | 引入 ClangTraceCollector.h |
| `WeChatSwift/OrderFileGenerator.swift` | 新建 | dladdr 解析 → 去重保序 → 写 .order 到沙盒 |
| `WeChatSwift/LaunchMetrics.swift` | 微调 | firstFrame 回调中触发 generate |
| `Podfile` | 微调 | post_install 给所有 target 加插桩 flag |
| `project.yml` | 微调 | Other C/Swift Flags 加插桩；后续加 ORDER_FILE |

## 取出 Order File

有两种方式从真机获取 app.order：

1. **Xcode Devices 下载容器**：Window → Devices and Simulators → 选 App → 齿轮 → Download Container → 在 `AppData/Documents/app.order` 中找到文件。注意：部分场景下此方式会报 "The specified file could not be transferred" 错误。

2. **控制台复制（备用）**：代码中同时将符号列表 print 到控制台（`[OrderFile:BEGIN]` 和 `[OrderFile:END]` 之间），直接从 Xcode Console 复制内容保存为 .order 文件。

### 实测数据

本项目实测采集到 **194 个启动阶段符号**，包括 `main`、`AppDelegate.didFinishLaunching`、`LaunchScheduler` 调度流程、`LaunchMetrics` 打点、`SceneDelegate`、`MainTabBarController` 等，符合预期。

## 插桩实现

### ClangTraceCollector.c

```c
#include "ClangTraceCollector.h"
#include <stdatomic.h>

#define MAX_PCS 8192

uintptr_t CollectedPCs[MAX_PCS];
atomic_int CollectedCount = 0;

void __sanitizer_cov_trace_pc_guard_init(uint32_t *start, uint32_t *stop) {
    for (uint32_t *p = start; p < stop; p++) {
        *p = 1;
    }
}

void __sanitizer_cov_trace_pc_guard(uint32_t *guard) {
    if (!*guard) return;
    *guard = 0;  // 每个函数只记录一次（函数级去重）
    int idx = atomic_fetch_add(&CollectedCount, 1);
    if (idx < MAX_PCS) {
        CollectedPCs[idx] = (uintptr_t)__builtin_return_address(0);
    }
}
```

### 关键设计决策

| 决策 | 选择 | 理由 |
|------|------|------|
| 数组大小 | 8192 | 练习项目函数数量远小于此；大型项目可调到 65536 |
| 去重方式 | `*guard = 0` 单次触发 | 编译器为每个函数分配独立 guard，置零后不再触发，零运行时开销 |
| 线程安全 | `atomic_fetch_add` | 无锁原子递增，比 mutex 开销低一个数量级 |
| 地址获取 | `__builtin_return_address(0)` | 获取调用者的 PC，即被插桩函数的地址 |

### ClangTraceCollector.h

> ⚠️ Swift 无法导入 C 的 `atomic_int` 类型和 `#define` 宏常量，因此 header 必须用函数接口暴露给 Swift，而非直接 extern 变量。

```c
#ifndef ClangTraceCollector_h
#define ClangTraceCollector_h

#include <stdint.h>

int GetCollectedCount(void);
const uintptr_t * GetCollectedPCs(void);
int GetMaxPCs(void);

#endif
```

.c 文件内部用 `static` 变量 + `atomic_int`，通过上述三个函数对外暴露。

## 符号导出

### OrderFileGenerator.swift

```swift
import Foundation
import MachO

final class OrderFileGenerator {
    static func generate() {
        let count = min(Int(GetCollectedCount()), Int(GetMaxPCs()))
        guard count > 0 else {
            print("[OrderFile] ⚠️ No PCs collected")
            return
        }

        guard let pcs = GetCollectedPCs() else {
            print("[OrderFile] ⚠️ PC array is nil")
            return
        }

        var symbols: [String] = []
        var seen = Set<String>()

        for i in 0..<count {
            let pc = pcs[i]
            var info = dl_info()
            guard dladdr(UnsafeRawPointer(bitPattern: pc), &info) != 0,
                  let cName = info.dli_sname else { continue }
            let name = String(cString: cName)
            if seen.insert(name).inserted {
                symbols.append(name)
            }
        }

        let content = symbols.joined(separator: "\n")
        let path = NSHomeDirectory() + "/Documents/app.order"
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            print("[OrderFile] ✅ \(symbols.count) symbols written to: \(path)")
            // 同时输出到控制台，备用取出方式
            print("[OrderFile:BEGIN]")
            print(content)
            print("[OrderFile:END]")
        } catch {
            print("[OrderFile] ❌ Write failed: \(error)")
        }
    }
}
```

### 触发时机

在 `LaunchMetrics.observeFirstFrame()` 的回调中，firstFrame 标记之后、report 之前触发：

```swift
// LaunchMetrics.swift observeFirstFrame 回调内
mark("firstFrame")
LaunchScheduler.shared.startAfterFirstFrame()
OrderFileGenerator.generate()  // ← 新增
report()
```

选择 firstFrame 而非 didFinishLaunching 的原因：firstFrame 是用户感知到启动完成的时刻，这之前调用的所有函数都属于"启动阶段"，应该被重排。

## 构建配置

### 插桩阶段（采集时）

**project.yml — 主 target：**

```yaml
settings:
  base:
    OTHER_CFLAGS: ["$(inherited)", "-fsanitize-coverage=func,trace-pc-guard"]
    OTHER_SWIFT_FLAGS: ["$(inherited)", "-sanitize-coverage=func", "-sanitize=undefined"]
```

> ⚠️ 必须加 `$(inherited)` 前缀，否则会覆盖 CocoaPods xcconfig 中的 flag，导致 Pod 编译参数丢失。

**Podfile — 所有 Pod target：**

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['OTHER_CFLAGS'] ||= '$(inherited)'
      config.build_settings['OTHER_CFLAGS'] += ' -fsanitize-coverage=func,trace-pc-guard'
    end
  end
end
```

### 产出应用阶段（重排后）

1. 移除上述插桩 flag
2. 将 app.order 放到项目根目录
3. project.yml 添加：

```yaml
settings:
  base:
    ORDER_FILE: $(SRCROOT)/app.order
```

链接器遇到 order file 中不存在的符号会自动忽略（不报错），多余符号也无害。

## 验证

### 对比指标

| 指标 | 测量方式 | 预期 |
|------|---------|------|
| File Backed Page In | Instruments System Trace | 减少 30-80% |
| 冷启动耗时 | LaunchMetrics Report | 可能有轻微改善（练习项目体量小） |

### 验证步骤

1. 优化前：System Trace 录制 3 次冷启动，记录 Page Fault 平均值
2. 插桩采集：真机运行带插桩的版本，取出 app.order
3. 验证 order file：检查符号数量、是否包含关键启动函数（如 `main`、`AppDelegate` 方法）
4. 应用重排：配置 ORDER_FILE，关闭插桩，重新编译
5. 优化后：System Trace 再录制 3 次，对比 Page Fault 数量

## 面试要点

- **为什么用 SanitizerCoverage 而不是 hook objc_msgSend？**
  - SanitizerCoverage 覆盖 C / C++ / Swift / ObjC 所有函数，objc_msgSend 只能 hook ObjC 方法调用
  - SanitizerCoverage 是编译器级插桩，准确度更高

- **order file 中符号顺序的意义？**
  - 排在前面的符号被链接器放在 `__TEXT` 段更低的地址
  - 启动时最先调用的函数排最前，确保它们在连续的物理页中

- **为什么练习项目效果不明显？**
  - 二进制体量小，`__TEXT` 段本身只占几十页，Page Fault 基数低
  - 真正受益的是大型 App（几百 MB 二进制），Page Fault 从 2000+ 降到 500 以下
