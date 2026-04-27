# VBox 日志系统架构文档

本文档对 VirtualBox (IPRT) 日志系统进行架构拆解，采用 4+1 架构视图模型，从三个结构维度展开：

| 结构维度 | 采用视图 | 关注点 |
|----------|----------|--------|
| **静态结构** | Logical View + Development View | 类/结构体关系、宏层级、模块组织 |
| **动态结构** | Process View | 运行时调用流程、并发与线程交互 |
| **分配结构** | Allocation View (Physical/Deployment) | 组件在 Ring-0/Ring-3 中的分布与映射 |

---

# 1. 静态结构

## 1.1 Logical View — 核心类图

以下类图展示日志系统的核心数据结构及其关系。

```plantuml
@startuml VBox-LogSystem-ClassDiagram
skinparam classAttributeIconSize 0
skinparam linetype ortho
hide empty methods

' ==================== Enumerations ====================
enum RTLOGGROUP {
    RTLOGGROUP_DEFAULT = 0
    RTLOGGROUP_ACPI
    RTLOGGROUP_CRYPTO
    RTLOGGROUP_DBG
    ...
    RTLOGGROUP_ZIP = 31
    RTLOGGROUP_FIRST_USER = 32
}
note right of RTLOGGROUP
  IPRT 内置日志组 (0~31)
  用户自定义组从 32 开始
  VBox 各子系统在
  include/VBox/log.h 中扩展
  (如 LOG_GROUP_EM, LOG_GROUP_VMM 等)
end note

enum RTLOGGRPFLAGS <<uint32>> {
    ENABLED    = 0x0001
    FLOW       = 0x0002
    WARN       = 0x0004
    LEVEL_1    = 0x0010
    LEVEL_2    = 0x0020
    LEVEL_3    = 0x0040
    ...
    LEVEL_12   = 0x8000
    RESTRICT   = 0x40000000
}

enum RTLOGFLAGS <<uint64>> {
    DISABLED           = 0x00000001
    BUFFERED           = 0x00000002
    USECRLF            = 0x00000010
    APPEND             = 0x00000020
    WRITE_THROUGH      = 0x00000100
    FLUSH              = 0x00000200
    RESTRICT_GROUPS    = 0x00000400
    PREFIX_CPUID       = 0x00010000
    PREFIX_PID         = 0x00020000
    PREFIX_GROUP       = 0x00200000
    PREFIX_THREAD      = 0x00800000
    PREFIX_TIME        = 0x08000000
    PREFIX_TSC         = 0x20000000
    ...
}

enum RTLOGDEST <<uint32>> {
    FILE       = 0x00000001
    STDOUT     = 0x00000002
    STDERR     = 0x00000004
    DEBUGGER   = 0x00000008
    COM        = 0x00000010
    RINGBUF    = 0x00000020
    VMM        = 0x00000040
    VMM_REL    = 0x00000080
    USER       = 0x40000000
}

enum RTLOGPHASE {
    BEGIN
    END
    PREROTATE
    POSTROTATE
}

' ==================== Core Structures ====================
class RTLOGGER <<public>> {
    +u32Magic : uint32_t
    +u32UserValue1 : uint32_t
    +u64UserValue2 : uint64_t
    +u64UserValue3 : uint64_t
    +uUsedToBeNonC99Logger : uintptr_t
}
note top of RTLOGGER
  公开的 Logger 结构体
  所有外部代码通过
  PRTLOGGER 访问
end note

class RTLOGGERINTERNAL <<private, log.cpp>> {
    +Core : RTLOGGER
    --
    +uRevision : uint32_t
    +cbSelf : uint32_t
    +fFlags : uint64_t  <<RTLOGFLAGS>>
    +fDestFlags : uint32_t  <<RTLOGDEST>>
    -- Buffer 管理 --
    +cBufDescs : uint8_t
    +idxBufDesc : uint8_t
    +paBufDescs : PRTLOGBUFFERDESC
    +pBufDesc : PRTLOGBUFFERDESC
    -- 同步 --
    +hSpinMtx : RTSEMSPINMUTEX
    +pfnFlush : PFNRTLOGFLUSH
    -- 前缀回调 --
    +pfnPrefix : PFNRTLOGPREFIX
    +pvPrefixUserArg : void*
    +fPendingPrefix : bool
    -- Group 管理 --
    +cMaxGroups : uint32_t
    +papszGroups : const char* const*
    +cGroups : uint32_t
    +afGroups[] : uint32_t  <<RTLOGGRPFLAGS>>
    -- 限流 --
    +pacEntriesPerGroup : uint32_t*
    +cMaxEntriesPerGroup : uint32_t
    -- Ring Buffer --
    +cbRingBuf : uint32_t
    +cbRingBufUnflushed : uint64_t
    +pszRingBuf : char*
    +pchRingBufCur : char*
    -- R3 文件日志 --
    +pfnPhase : PFNRTLOGPHASE
    +pOutputIf : PCRTLOGOUTPUTIF
    +hFile : RTFILE
    +cbHistoryFileMax : uint64_t
    +cbHistoryFileWritten : uint64_t
    +cHistory : uint32_t
    +szFilename[RTPATH_MAX] : char
    +fLogOpened : bool
}

class RTLOGBUFFERDESC {
    +u32Magic : uint32_t
    +cbBuf : uint32_t
    +offBuf : uint32_t
    +pchBuf : char*
    +pAux : PRTLOGBUFFERAUXDESC
}

class RTLOGBUFFERAUXDESC {
    +fFlushedIndicator : bool volatile
    +offBuf : uint32_t
}
note right of RTLOGBUFFERAUXDESC
  R0/R3 共享的辅助描述符
  用于 EMT Logger 跨 Ring 刷新
end note

interface RTLOGOUTPUTIF <<vtable>> {
    +pfnDirCtxOpen()
    +pfnDirCtxClose()
    +pfnDelete()
    +pfnRename()
    +pfnOpen()
    +pfnClose()
    +pfnQuerySize()
    +pfnWrite()
    +pfnFlush()
}
note left of RTLOGOUTPUTIF
  可替换的 I/O 后端接口
  默认实现使用 RTFILE
end note

class RTLOGOUTPUTPREFIXEDARGS {
    +pLoggerInt : PRTLOGGERINTERNAL
    +fFlags : unsigned
    +iGroup : unsigned
    +pszInfix : const char*
}

' ==================== Callback Types ====================
class "<<callback>>\nFNRTLOGFLUSH" as FNRTLOGFLUSH {
    (pLogger, pBufDesc) → bool
}

class "<<callback>>\nFNRTLOGPHASE" as FNRTLOGPHASE {
    (pLogger, enmLogPhase, pfnLogPhaseMsg)
}

class "<<callback>>\nFNRTLOGPREFIX" as FNRTLOGPREFIX {
    (pLogger, pchBuf, cchBuf, pvUser) → size_t
}

' ==================== Relationships ====================
RTLOGGERINTERNAL *-- RTLOGGER : Core (首成员)
RTLOGGERINTERNAL "1" *-- "1..*" RTLOGBUFFERDESC : paBufDescs
RTLOGBUFFERDESC "1" o-- "0..1" RTLOGBUFFERAUXDESC : pAux
RTLOGGERINTERNAL --> RTLOGOUTPUTIF : pOutputIf
RTLOGGERINTERNAL --> FNRTLOGFLUSH : pfnFlush
RTLOGGERINTERNAL --> FNRTLOGPHASE : pfnPhase
RTLOGGERINTERNAL --> FNRTLOGPREFIX : pfnPrefix
RTLOGGERINTERNAL ..> RTLOGFLAGS : fFlags
RTLOGGERINTERNAL ..> RTLOGDEST : fDestFlags
RTLOGGERINTERNAL ..> RTLOGGRPFLAGS : afGroups[]
RTLOGOUTPUTPREFIXEDARGS --> RTLOGGERINTERNAL

@enduml
```

## 1.2 Logical View — 宏层级结构图

以下展示用户可见的日志宏如何逐层展开到底层 API。

```plantuml
@startuml VBox-LogSystem-MacroLayers
skinparam packageStyle rectangle
skinparam componentStyle rectangle
left to right direction

package "用户层宏 (User-Facing Macros)" as UserMacros {
    [Log(a) / Log2(a) / ... / Log12(a)] as DebugLog
    [LogFlow(a) / LogWarn(a)] as DebugFlowWarn
    [LogFunc(a) / Log2Func(a) / ...] as DebugFuncLog
    [LogRel(a) / LogRel2(a) / ...] as RelLog
    [LogRelFunc(a) / LogRelFlowFunc(a)] as RelFuncLog
    [LogRelMax(cMax, a)] as RelMaxLog
}

package "分派层宏 (Dispatch Macros)" as DispatchMacros {
    [LogIt(fFlags, iGroup, fmtargs)] as LogIt
    [LogItAlways(fFlags, iGroup, fmtargs)] as LogItAlways
    [_LogRelIt(...)] as _LogRelIt
    [_LogRelItLikely(...)] as _LogRelItLikely
    [_LogRelMaxIt(cMax, ...)] as _LogRelMaxIt
}

package "Logger 实例获取" as InstanceGet {
    [RTLogDefaultInstanceEx()\n<Debug Logger>] as DebugInst
    [RTLogRelGetDefaultInstanceEx()\n<Release Logger>] as RelInst
    note bottom of DebugInst
        LOGASLOGREL 宏可将此
        替换为 RTLogRelGetDefaultInstanceEx
    end note
}

package "格式化输出" as Output {
    [RTLogLoggerEx() / RTLogLoggerExV()] as LoggerEx
}

DebugLog --> LogIt
DebugFlowWarn --> LogIt
DebugFuncLog --> LogIt
RelLog --> _LogRelItLikely
RelFuncLog --> _LogRelIt
RelMaxLog --> _LogRelMaxIt

LogIt --> DebugInst
LogItAlways --> DebugInst
_LogRelIt --> RelInst
_LogRelItLikely --> RelInst
_LogRelMaxIt --> RelInst

DebugInst --> LoggerEx
RelInst --> LoggerEx

@enduml
```

## 1.3 Development View — 模块组织与源文件依赖

从源文件组织角度展示日志系统的模块划分、全局单例关系以及各子系统的引用方式。

```plantuml
@startuml VBox-LogSystem-PackageDiagram
skinparam packageStyle frame

package "include/iprt/log.h" as LogH {
    [RTLOGGER (public struct)]
    [RTLOGBUFFERDESC]
    [RTLOGBUFFERAUXDESC]
    [RTLOGOUTPUTIF]
    [RTLOGFLAGS / RTLOGDEST / RTLOGGRPFLAGS (enums)]
    [RTLOGGROUP (IPRT groups 0~31)]
    [Log() / LogRel() 宏族]
}

package "include/VBox/log.h" as VBoxLogH {
    [LOG_GROUP_* (VBox groups 32+)\ne.g. LOG_GROUP_EM,\nLOG_GROUP_VMM,\nLOG_GROUP_PGM ...] as VBoxGroups
    [VBOX_LOGGROUP_NAMES] as VBoxGrpNames
}
note bottom of VBoxLogH
  扩展 RTLOGGROUP，
  定义 VBox 特有的日志组
  (~200+ 个组)
end note

package "src/VBox/Runtime/common/log/log.cpp" as LogCpp {
    [RTLOGGERINTERNAL (private struct)]
    [g_pLogger : PRTLOGGER\n(Debug Logger 单例)]
    [g_pRelLogger : PRTLOGGER\n(Release Logger 单例)]
    [RTLogCreate() / RTLogCreateEx()]
    [RTLogSetDefaultInstance()]
    [RTLogRelSetDefaultInstance()]
    [RTLogDefaultInstanceEx()]
    [RTLogRelGetDefaultInstanceEx()]
    [RTLogLoggerEx() / RTLogLoggerExV()]
    [rtlogGroupFlags() - 解析 group settings 字符串]
}

package "各 VBox 子系统源文件" as Subsystem {
    [#define LOG_GROUP LOG_GROUP_EM\n#include <iprt/log.h>\n...\nLog(("msg"));\nLogRel(("msg"));] as Usage
}

package "Main/src-client/ConsoleImpl.cpp" as Console {
    [VBoxLogRelCreate()\n配置 pcszGroupSettings\n创建 Release Logger] as LogCreate
}

LogH <-- VBoxLogH : 扩展 groups
LogH <-- LogCpp : 实现
VBoxLogH <-- Subsystem : #define LOG_GROUP
LogH <-- Subsystem : #include
LogCpp <-- Console : 调用 RTLogCreate
LogCpp <-- Subsystem : 宏展开调用

@enduml
```

---

# 2. 动态结构

## 2.1 Process View — 日志调用时序

展示一次典型的 `Log()` 宏调用的完整执行路径，包含 Group/Level 门控检查、缓冲区写入和条件刷新。

```plantuml
@startuml VBox-LogSystem-SequenceDiagram
skinparam sequenceArrowThickness 1.5
skinparam maxMessageSize 200
autonumber

participant "调用方代码\n(e.g. EMR3.cpp)" as Caller
participant "Log() 宏\n(log.h)" as Macro
participant "RTLogDefaultInstanceEx()\n(log.cpp)" as InstGet
participant "RTLOGGERINTERNAL\n(g_pLogger)" as Logger
participant "RTLogLoggerEx()\n(log.cpp)" as LoggerEx
participant "RTLOGBUFFERDESC\n(pBufDesc)" as Buffer
participant "PFNRTLOGFLUSH\n(pfnFlush)" as Flush
participant "RTLOGOUTPUTIF\n(pfnWrite)" as OutputIF
participant "Log File" as File

Caller -> Macro : Log(("EM: state=%d", st))
activate Macro
Macro -> InstGet : RTLogDefaultInstanceEx(\n  RT_MAKE_U32(\n    RTLOGGRPFLAGS_LEVEL_1,\n    LOG_GROUP_EM))
activate InstGet

InstGet -> Logger : 检查 afGroups[LOG_GROUP_EM]\n& RTLOGGRPFLAGS_LEVEL_1
alt Group + Level 已启用
    InstGet --> Macro : return pLogger (非NULL)
else Group 或 Level 未启用
    InstGet --> Macro : return NULL
    Macro --> Caller : (不输出任何内容)
end
deactivate InstGet

Macro -> LoggerEx : RTLogLoggerEx(pLogger,\n  RTLOGGRPFLAGS_LEVEL_1,\n  LOG_GROUP_EM, fmt, ...)
activate LoggerEx

LoggerEx -> Logger : 加锁 hSpinMtx
LoggerEx -> Buffer : 写入前缀 (时间戳/线程/Group名等)\n+ 格式化日志内容到 pchBuf
LoggerEx -> Buffer : offBuf += written

alt 缓冲区满 或 需要立即刷新
    LoggerEx -> Flush : pfnFlush(pLogger, pBufDesc)
    activate Flush
    Flush -> OutputIF : pfnWrite(pvBuf, cbWrite)
    OutputIF -> File : 写入磁盘
    File --> OutputIF : OK
    OutputIF --> Flush : OK
    Flush -> Buffer : offBuf = 0 (重置)
    Flush --> LoggerEx : true (可复用)
    deactivate Flush
end

LoggerEx -> Logger : 释放锁 hSpinMtx
LoggerEx --> Macro : return
deactivate LoggerEx

Macro --> Caller : (完成)
deactivate Macro

@enduml
```

## 2.2 Process View — LOGASLOGREL 重定向机制

展示 NetEase 自定义的 `LOGASLOGREL` 宏如何在编译期改变日志流向。

```plantuml
@startuml VBox-LogSystem-LOGASLOGREL
skinparam activityBackgroundColor #f8f8f8

start

:源码中调用 **Log(("msg"))**;

if (编译时是否定义了 **LOGASLOGREL**?) then (是)
    :宏展开使用\n**RTLogRelGetDefaultInstanceEx()**;
    :获取 **g_pRelLogger**\n(Release Logger 实例);
    :日志输出到 **VBox.log**\n(Release 日志文件);
    note right
        Release 构建中也能
        获得 Group Log 输出
        通过 pcszGroupSettings 控制
    end note
else (否 - 默认行为)
    if (编译时定义了 **DEBUG** 或 **LOG_ENABLED**?) then (是)
        :宏展开使用\n**RTLogDefaultInstanceEx()**;
        :获取 **g_pLogger**\n(Debug Logger 实例);
        :日志输出到 **Debug 日志文件**;
    else (否)
        :宏展开为 **do {} while(0)**\n(空操作，零开销);
    endif
endif

stop

@enduml
```

## 2.3 Process View — Logger 创建与初始化时序

展示 VBox 启动时 Release Logger 的创建和全局注册过程。

```plantuml
@startuml VBox-LogSystem-Init
skinparam sequenceArrowThickness 1.5
autonumber

participant "ConsoleImpl.cpp\nVBoxLogRelCreate()" as Console
participant "RTLogCreateEx()\n(log.cpp)" as Create
participant "RTLOGGERINTERNAL" as Internal
participant "rtlogGroupFlags()" as GrpParse
participant "RTLogRelSetDefaultInstance()" as SetInst

Console -> Create : RTLogCreateEx(&pLogger, envVar,\n  fFlags, **pcszGroupSettings**,\n  cGroups, papszGroups, fDestFlags,\n  pfnPhase, szLogFile, ...)
activate Create

Create -> Internal : 分配 RTLOGGERINTERNAL\n(含 cGroups 个 afGroups[] 槽位)
Create -> Internal : 初始化 fFlags, fDestFlags
Create -> Internal : 分配 RTLOGBUFFERDESC + 缓冲区

loop 解析 pcszGroupSettings (e.g. "em.e.l.f")
    Create -> GrpParse : rtlogGroupFlags("e.l.f")
    GrpParse --> Create : ENABLED | LEVEL_1 | WARN | LEVEL_2 | FLOW
    Create -> Internal : afGroups[LOG_GROUP_EM] |= flags
end

Create -> Internal : 打开日志文件 (如 RTLOGDEST_FILE)
Create --> Console : return pLogger

Console -> SetInst : RTLogRelSetDefaultInstance(pLogger)
SetInst -> SetInst : g_pRelLogger = pLogger

@enduml
```

---

# 3. 分配结构

## 3.1 Allocation View — Ring-0 / Ring-3 组件部署

展示日志系统组件在 VBox 进程和内核驱动中的物理分布，以及跨 Ring 的日志缓冲区共享机制。

```plantuml
@startuml VBox-LogSystem-AllocationView
skinparam componentStyle rectangle

node "Ring-3 用户态进程" as R3 {
    component "VBoxSVC / VBoxHeadless\n(Main API)" as MainProc
    component "ConsoleImpl\nVBoxLogRelCreate()" as ConsoleComp

    database "Release Log File\nVBox.log" as RelLogFile
    database "Debug Log File\n(optional)" as DbgLogFile

    component "IPRT Log Engine (log.cpp)\n---\ng_pRelLogger\ng_pLogger" as LogEngine

    component "RTLOGOUTPUTIF\n(File I/O Backend)" as OutputBackend

    ConsoleComp --> LogEngine : RTLogCreate()
    LogEngine --> OutputBackend : pfnWrite / pfnFlush
    OutputBackend --> RelLogFile
    OutputBackend --> DbgLogFile
    MainProc --> LogEngine : LogRel() / Log()
}

node "Ring-0 内核 (VBoxDrv.sys)" as R0 {
    component "VMM / HM\n(Ring-0 部分)" as VMMR0
    component "R0 Logger Instance\n(per-VCPU)" as R0Logger

    VMMR0 --> R0Logger : Log()
}

R0Logger ..> LogEngine : "RTLOGDEST_VMM / VMM_REL\n返回 R3 时通过\nRTLOGBUFFERAUXDESC 刷新"

note bottom of R0
  Ring-0 中每个 VCPU 拥有独立的
  Logger 实例，缓冲区通过
  AuxDesc 共享给 Ring-3 刷新
end note

@enduml
```

---

# 附录

## A. 关键源文件索引

| 文件 | 说明 |
|------|------|
| `include/iprt/log.h` | 日志系统公共头文件：宏定义、公共结构体、API 声明 |
| `include/VBox/log.h` | VBox 扩展日志组定义 (LOG_GROUP_*) |
| `src/VBox/Runtime/common/log/log.cpp` | 日志系统核心实现：RTLOGGERINTERNAL、RTLogCreate、RTLogLoggerEx 等 |
| `Main/src-client/ConsoleImpl.cpp` | Release Logger 创建入口 (VBoxLogRelCreate) |

## B. NetEase 定制说明 — LOGASLOGREL 宏

### B.1 背景与动机

VBox 原生的日志架构中，`Log()` / `Log2()` / `LogFlow()` 等 Debug 日志宏在 Release 构建中被预处理为空操作（`do {} while(0)`），完全不产生任何代码。要获取这些详细日志，必须切换到 Debug 构建（`KBUILD_TYPE=debug`），但 Debug 构建带来 `-O0` 优化级别和额外断言开销，性能大幅下降，不适合在接近生产的环境中排查问题。

`LOGASLOGREL` 是 NetEase 内部添加的一个 **编译期 hack 宏**（来源 patch: `vBox-Res/d0551b58a66250002c3564465eb2dd71c98896d1.patch`），目的是：**在保持 Release 构建优化级别的前提下，让 `Log()` 系列宏也能输出日志**。

### B.2 原理详解

`LOGASLOGREL` 宏对 `include/iprt/log.h` 做了两处关键改动：

#### 改动 1：编译门控条件扩展

```c
/* 原始代码 */
#if (defined(DEBUG) || defined(LOG_ENABLED)) && !defined(LOG_DISABLED)
# define LOG_ENABLED
#else
# define LOG_DISABLED
#endif

/* LOGASLOGREL 改动后 */
#if (defined(DEBUG) || defined(LOG_ENABLED) || defined(LOGASLOGREL)) && !defined(LOG_DISABLED)
# define LOG_ENABLED
#else
# define LOG_DISABLED
#endif
```

**效果**：即使是 Release 构建（没有 `DEBUG` 或 `LOG_ENABLED`），只要定义了 `LOGASLOGREL`，`LOG_ENABLED` 就会被定义。这使得 `Log()` / `LogFlow()` 等宏不再被编译为空操作，而是展开为实际的日志调用代码。

#### 改动 2：Logger 实例获取函数替换

```c
/* 原始代码 — Log() 走 Debug Logger */
PRTLOGGER LogIt_pLogger = RTLogDefaultInstanceEx(RT_MAKE_U32(a_fFlags, a_iGroup));
                          ^^^^^^^^^^^^^^^^^^^^^^^^
                          获取 g_pLogger (Debug Logger 单例)

/* LOGASLOGREL 启用后 — Log() 走 Release Logger */
PRTLOGGER LogIt_pLogger = RTLogRelGetDefaultInstanceEx(RT_MAKE_U32(a_fFlags, a_iGroup));
                          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                          获取 g_pRelLogger (Release Logger 单例)
```

**效果**：`Log()` 系列宏虽然在语法上是 "Debug 日志"，但实际获取的 Logger 实例是 Release Logger。这意味着：

- 日志输出到 **VBox.log**（Release Logger 的默认日志文件）
- 日志组的启用/禁用由 `VBoxLogRelCreate()` 的 `pcszGroupSettings` 参数控制
- 无需配置 `VBOX_LOG` 等 Debug Logger 环境变量

### B.3 数据流对比

| 维度 | 正常 Debug 构建 | LOGASLOGREL Release 构建 |
|------|-----------------|--------------------------|
| `Log()` 编译状态 | ✅ 编译为日志调用 | ✅ 编译为日志调用 |
| 底层 Logger | `g_pLogger` (Debug Logger) | `g_pRelLogger` (Release Logger) |
| 日志组控制入口 | `VBOX_LOG` 环境变量 | `ConsoleImpl.cpp` 中 `pcszGroupSettings` 参数 |
| 日志输出文件 | Debug 日志文件 | **VBox.log** (Release 日志文件) |
| 优化级别 | `-O0` (R3) | **`-O2`** (保持 Release 优化) |
| 断言开销 | 全部启用 (`RT_STRICT` / `VBOX_STRICT`) | **不启用** |
| `LogRel()` 行为 | 不受影响 | 不受影响 |

### B.4 启用方式

1. **反注释宏定义** — 编辑 `include/iprt/log.h`，找到以下行并取消注释：
   ```c
   // #define LOGASLOGREL
   ```
   改为：
   ```c
   #define LOGASLOGREL
   ```

2. **配置日志组** — 编辑 `Main/src-client/ConsoleImpl.cpp`，修改 `com::VBoxLogRelCreate` 调用中的 `pcszGroupSettings` 参数：
   ```c
   /* 示例：启用 EM 模块的 Level-1 日志和执行流日志 */
   pcszGroupSettings = "em.e.l.f";
   
   /* 示例：启用所有模块，排除噪音模块 */
   pcszGroupSettings = "all -drv_nat -pgm_phys";
   ```

3. **重新编译**：
   ```cmd
   cd vBox-Src
   out\env.bat
   kmk    # Release 编译即可
   ```

### B.5 注意事项

- **全局影响**：`LOGASLOGREL` 是在公共头文件 `log.h` 中定义的，启用后会影响 **所有** 包含该头文件的编译单元。整个 VBox 代码树中所有 `Log()` 调用都会被激活。
- **性能影响**：虽然保持了 `-O2` 优化，但大量 `Log()` 调用被激活后会产生显著的 I/O 和 CPU 开销。建议通过 `pcszGroupSettings` 精确控制只启用需要调试的模块。
- **不影响 `LogRel()`**：`LogRel()` 系列宏始终走 Release Logger，不受 `LOGASLOGREL` 影响。
- **Patch 管理**：此改动来源于 `vBox-Res/d0551b58a66250002c3564465eb2dd71c98896d1.patch`，如果需要在干净的源码树上应用，使用：
  ```cmd
  cd vBox-Src
  git apply --ignore-whitespace --exclude="README.md" ..\vBox-Res\d0551b58a66250002c3564465eb2dd71c98896d1.patch
  ```

详细的操作步骤和调试场景请参见 [VBox-debug-guide.md](VBox-debug-guide.md) 第 3.5 节。
