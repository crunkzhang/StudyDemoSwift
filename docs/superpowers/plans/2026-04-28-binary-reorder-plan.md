# 二进制重排 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 通过 Clang SanitizerCoverage 插桩采集启动阶段函数调用顺序，生成 order file 写入沙盒，后续配置链接器重排二进制以减少冷启动 Page Fault。

**Architecture:** C 层原子数组记录 PC 地址 → Swift 层 dladdr 解析 → firstFrame 时写 .order 到沙盒。插桩 flag 通过 project.yml + Podfile post_install 全量配置。

**Tech Stack:** C (stdatomic), Swift, Clang SanitizerCoverage, dladdr, XcodeGen, CocoaPods

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `WeChatSwift/ClangTraceCollector.c` | Create | SanitizerCoverage 回调，原子数组记录 PC |
| `WeChatSwift/ClangTraceCollector.h` | Create | 暴露 CollectedPCs / CollectedCount 给 Swift |
| `WeChatSwift/WeChatSwift-Bridging-Header.h` | Create | 引入 ClangTraceCollector.h |
| `WeChatSwift/OrderFileGenerator.swift` | Create | dladdr 解析 → 去重保序 → 写 .order 到沙盒 |
| `WeChatSwift/LaunchMetrics.swift` | Modify | firstFrame 回调中触发 OrderFileGenerator |
| `project.yml` | Modify | 加 Bridging Header + 插桩 flag |
| `Podfile` | Modify | post_install 加 Pod 插桩 flag |

---

### Task 0: 测量基线 Page Fault（无编码，纯真机操作）

**Files:** 无文件变更

> ⚠️ 此步骤不需要编码，是纯手动操作。必须在开始插桩之前完成，作为优化前的基线数据。

- [ ] **Step 1: 准备测量环境**

1. 确保使用 **真机**（模拟器的虚拟内存行为与真机完全不同，数据无参考价值）
2. 用数据线连接 iPhone 到 Mac
3. Xcode 中选择真机作为 Run Destination
4. 先正常 Run 一次 App，确保安装成功

- [ ] **Step 2: 打开 Instruments System Trace**

1. Xcode 菜单 → **Product → Profile**（快捷键 **Cmd+I**）
2. 弹出 Instruments 模板选择窗口
3. 在模板列表中找到并选择 **System Trace**（图标是一个带齿轮的心跳线）
4. 点击 **Choose** 按钮

- [ ] **Step 3: 冷启动录制**

1. **先彻底杀掉 App**：在 iPhone 上上滑移除 WeChatSwift（确保不在后台）
2. 回到 Instruments 界面，点击左上角红色 **Record** 按钮（⏺）
3. App 会自动在真机上启动
4. **等待首屏完全渲染完成**（看到 TabBar 和内容页面出现，大约 2-3 秒）
5. 点击左上角 **Stop** 按钮（⏹）停止录制

- [ ] **Step 4: 查看 Page Fault 数据**

1. 录制停止后，Instruments 会显示时间线数据
2. 在底部的进程列表中，找到并**点击选中** `WeChatSwift` 进程
3. 在时间线区域中，展开 `WeChatSwift` 进程行
4. 找到 **Virtual Memory** 子行并展开
5. 查看 **File Backed Page In** 这一行
6. 关注 **Count** 列的数值 — **这就是冷启动的 Page Fault 次数**

如果底部看不到进程列表：
- 点击 Instruments 窗口底部的 **process filter** 下拉框
- 输入 `WeChatSwift` 筛选

- [ ] **Step 5: 多次测量取平均**

重复 Step 3-4 共 **3 次**，记录每次的 File Backed Page In Count：

| 次数 | File Backed Page In |
|------|-------------------|
| 第 1 次 | _____ |
| 第 2 次 | _____ |
| 第 3 次 | _____ |
| **平均值** | _____ |

注意事项：
- **每次测量前必须杀掉 App**，否则页面缓存在内存中，不会触发 Page Fault
- 如果第 1 次数值明显偏高（设备刚重启/内存紧张），可丢弃该次作为预热
- 练习项目预期范围：**100-500 次**

- [ ] **Step 6: 记录基线**

将平均值记录下来，后续 Task 8 将用同样方法测量优化后数值进行对比。

---

### Task 1: C 层插桩采集

**Files:**
- Create: `WeChatSwift/ClangTraceCollector.h`
- Create: `WeChatSwift/ClangTraceCollector.c`

- [ ] **Step 1: 创建 ClangTraceCollector.h**

```c
#ifndef ClangTraceCollector_h
#define ClangTraceCollector_h

#include <stdint.h>
#include <stdatomic.h>

#define MAX_PCS 8192

extern uintptr_t CollectedPCs[MAX_PCS];
extern atomic_int CollectedCount;

#endif
```

- [ ] **Step 2: 创建 ClangTraceCollector.c**

```c
#include "ClangTraceCollector.h"
#include <stdatomic.h>

uintptr_t CollectedPCs[MAX_PCS];
atomic_int CollectedCount = 0;

void __sanitizer_cov_trace_pc_guard_init(uint32_t *start, uint32_t *stop) {
    for (uint32_t *p = start; p < stop; p++) {
        *p = 1;
    }
}

void __sanitizer_cov_trace_pc_guard(uint32_t *guard) {
    if (!*guard) return;
    *guard = 0;
    int idx = atomic_fetch_add(&CollectedCount, 1);
    if (idx < MAX_PCS) {
        CollectedPCs[idx] = (uintptr_t)__builtin_return_address(0);
    }
}
```

---

### Task 2: Bridging Header

**Files:**
- Create: `WeChatSwift/WeChatSwift-Bridging-Header.h`
- Modify: `project.yml`

- [ ] **Step 1: 创建 Bridging Header**

```c
#ifndef WeChatSwift_Bridging_Header_h
#define WeChatSwift_Bridging_Header_h

#include "ClangTraceCollector.h"

#endif
```

- [ ] **Step 2: 在 project.yml 中配置 Bridging Header**

在 `targets.WeChatSwift.settings.base` 中添加：

```yaml
SWIFT_OBJC_BRIDGING_HEADER: WeChatSwift/WeChatSwift-Bridging-Header.h
```

- [ ] **Step 3: 重新生成 Xcode 项目**

Run: `cd /Users/a1021500055/Study/HelloRN/WeChatSwift && xcodegen generate && pod install`
Expected: 无报错，新文件出现在 Xcode 项目中

- [ ] **Step 4: 编译验证**

Run: `xcodebuild -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'generic/platform=iOS' build 2>&1 | grep -E "error:|BUILD" | tail -5`
Expected: BUILD SUCCEEDED

---

### Task 3: 插桩编译配置

**Files:**
- Modify: `project.yml`
- Modify: `Podfile`

- [ ] **Step 1: project.yml 添加主 target 插桩 flag**

在 `targets.WeChatSwift.settings.base` 中添加：

```yaml
OTHER_CFLAGS: ["-fsanitize-coverage=func,trace-pc-guard"]
OTHER_SWIFT_FLAGS: ["-sanitize-coverage=func", "-sanitize=undefined"]
```

- [ ] **Step 2: Podfile 添加 Pod 插桩 flag**

在 `post_install` block 中，`react_native_post_install` 之后、现有 `installer.generated_projects.each` 之前添加：

```ruby
  # ── 二进制重排：SanitizerCoverage 插桩（采集完成后移除）──
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      c_flags = config.build_settings['OTHER_CFLAGS'] || '$(inherited)'
      unless c_flags.include?('-fsanitize-coverage')
        config.build_settings['OTHER_CFLAGS'] = "#{c_flags} -fsanitize-coverage=func,trace-pc-guard"
      end
    end
  end
```

- [ ] **Step 3: 重新生成项目并安装**

Run: `cd /Users/a1021500055/Study/HelloRN/WeChatSwift && xcodegen generate && pod install`

- [ ] **Step 4: 编译验证**

Run: `xcodebuild -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'generic/platform=iOS' build 2>&1 | grep -E "error:|BUILD" | tail -5`
Expected: BUILD SUCCEEDED

---

### Task 4: OrderFileGenerator

**Files:**
- Create: `WeChatSwift/OrderFileGenerator.swift`

- [ ] **Step 1: 创建 OrderFileGenerator.swift**

```swift
import Foundation
import MachO

final class OrderFileGenerator {
    static func generate() {
        let count = min(Int(CollectedCount), Int(MAX_PCS))
        guard count > 0 else {
            print("[OrderFile] ⚠️ No PCs collected")
            return
        }

        var symbols: [String] = []
        var seen = Set<String>()

        for i in 0..<count {
            let pc = CollectedPCs[i]
            var info = dl_info()
            guard dladdr(UnsafeRawPointer(bitPattern: pc), &info) != 0,
                  let cName = info.dli_sname else { continue }
            let name = String(cString: cName)
            if seen.insert(name).inserted {
                symbols.append(name)
            }
        }

        let content = symbols.joined(separator: "\n")
        let dir = NSHomeDirectory() + "/Documents"
        let path = dir + "/app.order"
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            print("[OrderFile] ✅ \(symbols.count) symbols written to: \(path)")
        } catch {
            print("[OrderFile] ❌ Write failed: \(error)")
        }
    }
}
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'generic/platform=iOS' build 2>&1 | grep -E "error:|BUILD" | tail -5`
Expected: BUILD SUCCEEDED

---

### Task 5: 集成到 LaunchMetrics

**Files:**
- Modify: `WeChatSwift/LaunchMetrics.swift`

- [ ] **Step 1: 在 observeFirstFrame 回调中触发生成**

在 `LaunchMetrics.swift` 的 `observeFirstFrame()` 方法中，`LaunchScheduler.shared.startAfterFirstFrame()` 之后、`report()` 之前添加一行：

```swift
// 现有代码：
mark("firstFrame")
LaunchScheduler.shared.startAfterFirstFrame()
// 新增：
OrderFileGenerator.generate()
// 现有代码：
report()
```

- [ ] **Step 2: 重新生成项目（确保新文件纳入）**

Run: `cd /Users/a1021500055/Study/HelloRN/WeChatSwift && xcodegen generate && pod install`

- [ ] **Step 3: 编译验证**

Run: `xcodebuild -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'generic/platform=iOS' build 2>&1 | grep -E "error:|BUILD" | tail -5`
Expected: BUILD SUCCEEDED

---

### Task 6: 真机运行验证

**Files:** 无文件变更，纯验证

- [ ] **Step 1: 真机运行**

在 Xcode 中选择真机设备，Run（Cmd+R）。

- [ ] **Step 2: 检查控制台输出**

在 Xcode Console 中搜索 `[OrderFile]`，验证：

1. 应看到 `[OrderFile] ✅ N symbols written to: /path/to/Documents/app.order`
2. N 应该 > 0（预期几十到几百个符号）
3. 如果看到 `⚠️ No PCs collected` 说明插桩未生效，检查编译 flag

- [ ] **Step 3: 取出 order file**

通过 Xcode → Window → Devices and Simulators → 选设备 → 选 App → 齿轮图标 → Download Container，在 `AppData/Documents/app.order` 中找到文件。

或者直接复制控制台输出的路径，用 Finder 导航到沙盒目录。

- [ ] **Step 4: 检查 order file 内容**

打开 app.order，验证：
- 每行一个符号名（C 函数带下划线前缀，Swift 函数是 mangled name）
- 应包含 `_main`、AppDelegate 相关方法、SDK setup 方法等
- 顺序应大致反映启动调用顺序

---

### Task 7: 应用 Order File + 关闭插桩

**Files:**
- Modify: `project.yml`
- Modify: `Podfile`

- [ ] **Step 1: 将 app.order 复制到项目根目录**

将从真机取出的 app.order 放到 `/Users/a1021500055/Study/HelloRN/WeChatSwift/app.order`

- [ ] **Step 2: project.yml 关闭插桩 + 配置 ORDER_FILE**

将 `targets.WeChatSwift.settings.base` 中的插桩 flag 移除，添加 ORDER_FILE：

移除：
```yaml
OTHER_CFLAGS: ["-fsanitize-coverage=func,trace-pc-guard"]
OTHER_SWIFT_FLAGS: ["-sanitize-coverage=func", "-sanitize=undefined"]
```

添加：
```yaml
ORDER_FILE: $(SRCROOT)/app.order
```

- [ ] **Step 3: Podfile 移除 Pod 插桩 flag**

移除 post_install 中之前添加的 SanitizerCoverage 插桩代码块。

- [ ] **Step 4: 重新生成项目并安装**

Run: `cd /Users/a1021500055/Study/HelloRN/WeChatSwift && xcodegen generate && pod install`

- [ ] **Step 5: 编译验证**

Run: `xcodebuild -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'generic/platform=iOS' build 2>&1 | grep -E "error:|BUILD" | tail -5`
Expected: BUILD SUCCEEDED

---

### Task 8: 验证优化效果

**Files:** 无文件变更，纯验证

- [ ] **Step 1: System Trace 测量优化后 Page Fault**

1. 彻底杀掉 App
2. Xcode → Product → Profile（Cmd+I）→ System Trace
3. 录制冷启动，首屏出现后停止
4. 筛选进程 WeChatSwift → Virtual Memory → File Backed Page In
5. 记录 Count 值
6. 重复 3 次取平均

- [ ] **Step 2: 对比基线**

| 指标 | 优化前 | 优化后 | 变化 |
|------|--------|--------|------|
| File Backed Page In | (Task 0 测量值) | (本步测量值) | -N% |

预期：Page Fault 减少 30-80%（取决于项目体量）

- [ ] **Step 3: 可选 — 移除采集代码**

如果 order file 已确认有效，可以移除插桩采集相关代码：
- 删除 `ClangTraceCollector.c` / `.h`
- 删除 `OrderFileGenerator.swift`
- 删除 Bridging Header 中的 `#include`
- 移除 `LaunchMetrics.swift` 中的 `OrderFileGenerator.generate()` 调用

保留 `app.order` 和 `ORDER_FILE` 配置即可。
