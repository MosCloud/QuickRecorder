# 术语表

这个文件定义项目里反复出现的词。写 issue、PR、代码注释和测试名时用这里的词，不要另造同义词。

目前只有「录制方式」这一组：五种方式在界面上看起来相近，在引擎里是五条不同的捕获路径，差别不写下来就得每次读代码。

## 录制方式

每种方式由 `SCContext.streamType` 标出，由 `RecordEngine.prepRecord(type:screens:windows:applications:)` 建 filter，再由 `record(filter:)` 配置流。

### 录制全屏画面（`.screen`）

一块屏幕上实际显示的东西，减去要藏起来的部分。filter 是 `SCContentFilter(display:excludingApplications:exceptingWindows:)`（`RecordEngine.swift:108`）：屏蔽列表里的 App、控制中心（设置里关掉时）、QuickRecorder 自己的窗口被排除，摄像头浮层和鼠标高亮这些「要录的浮层」反而作为例外窗口留在画面里，桌面文件可以单独隐藏。

成片尺寸是这块屏幕的分辨率（「选项」里选 Retina 就是点数的两倍）。结束条件：显示器断开、合盖或睡眠，ScreenCaptureKit 报 `-3815`。

### 录制屏幕区域（`.screenarea`）

和全屏画面同一条 filter，外加 `conf.sourceRect` 只取选区那一块，成片尺寸是选区大小（同样受 Retina 选项影响）。每块屏幕各自记住自己的选区（`Core/AreaRect.swift`）。

### 录制窗口内容（`.window`）

一个窗口本身。filter 是 `SCContentFilter(desktopIndependentWindow:)`（`RecordEngine.swift:88`），与屏幕无关：窗口被别的窗口挡住也照录，窗口在哪块屏上都行，成片尺寸就是窗口大小。

背景、菜单栏、高亮鼠标对它都不生效——画面里只有那个窗口。鼠标光标和声音生效，见下面的实测记录。

结束条件：窗口关掉，流自己结束，报 `-3815`。

### 录制多个窗口（`.windows`）

窗口选择器里勾了不止一个窗口时的路径：`SCContentFilter(display:including:)`（`RecordEngine.swift:84`）在同一块屏幕上合成这些窗口，另外按设置加上鼠标高亮浮层、摄像头浮层和壁纸窗口。成片尺寸是屏幕分辨率，菜单栏生效。

注意它和「录制应用程序」不完全一样：`Backdrop.applies(to:)` 只认 `.application`，所以多窗口录制没有背景色和透明，但壁纸会被当作一个窗口加进画面。

### 录制应用程序（`.application`）

选中的 App 的窗口，摆在一块屏幕上。filter 是 `SCContentFilter(display:including:exceptingWindows:)`（`RecordEngine.swift:121`）：QuickRecorder 自己作为例外加进去（所以摄像头浮层和鼠标高亮会入镜，胶囊被排除），屏蔽掉的桌面文件和壁纸按设置处理。

这是唯一能加背景的方式：壁纸、纯色，开了「带透明通道录制」之后还有透明（HEVC with Alpha）。成片尺寸是屏幕分辨率，菜单栏生效。

结束条件：录制的 App 全部退出后，流其实还在跑（继续录空白），由 `SCContext.watchRecordedApps()`（`SCContext.swift:748`）主动停止。窗口被关掉不会结束录制。

### 录制系统声音（`.systemaudio`）

只有声音没有画面：filter 仍是一块屏幕，但流只收音频（`conf.width/height = 2`，`capturesAudio` 打开）。

## 对照表

| | 全屏画面 | 屏幕区域 | 窗口内容 | 多个窗口 | 应用程序 | 系统声音 |
|---|---|---|---|---|---|---|
| 捕获路径 | `display` + 排除 | 同上 + `sourceRect` | `desktopIndependentWindow` | `display` + 包含 | `display` + 包含 App | 只有音频 |
| 成片尺寸 | 屏幕分辨率 | 选区大小 | 窗口大小 | 屏幕分辨率 | 屏幕分辨率 | — |
| 画面背景（壁纸 / 纯色 / 透明） | — | — | — | 只有壁纸 | ✅ | — |
| 菜单栏（`includeMenuBar`） | ✅ | ✅ | — | ✅ | ✅ | — |
| 高亮鼠标（`highlightMouse`） | ✅ | ✅ | — | ✅ | ✅ | — |
| 录制光标（`showMouse`） | ✅ | ✅ | ✅（实测） | ✅ | ✅ | — |
| 音频来源 | 系统声音 | 系统声音 | 该窗口所属 App（实测） | 这些窗口所属 App | 所选 App | 系统声音 |
| 结束条件 | 源屏幕消失 | 源屏幕消失 | 窗口关闭 | 窗口关闭 | App 全部退出 | — |

「—」表示这项设置对这种录制不起作用，不是「默认关闭」。

## 实测记录

2026-10-29，macOS 27，内建视网膜显示器：

- **单窗口录制会录鼠标光标。** 一个 420×300 的白窗口，指针停在里面，录 8 秒抽帧：光标在画面里、位置正确。前提是「录制鼠标光标」开着（`showMouse`）。`showMouse` 关掉时同一实验里没有光标。
- **单窗口录制只录这个窗口所属 App 的声音。** 一个自己循环播放 `Glass.aiff` 的窗口录 8 秒，音轨峰值 6819/32767（约 −13.6 dBFS）；作为对照，同一时间录另一个不出声的窗口，音轨全零。
- **高亮鼠标对单窗口录制不生效**，这是设计如此，不是缺陷：设置里那一项写着「Not available for "Single Window Capture"」，`mousePointerReLocation` 里遇到 `.window` 直接跳过（`QuickRecorderApp.swift:87`）。

## 避免的说法

| 不要写 | 用 |
|---|---|
| 窗口录制、单窗口录制（在需要精确的语境里） | 录制窗口内容 |
| 应用录制、App 录制 | 录制应用程序 |
| 全屏录制、录屏 | 录制全屏画面 |
| 区域录制、选区录制 | 录制屏幕区域 |

「录像」「成片」指录出来的文件本身，不算同义词。
