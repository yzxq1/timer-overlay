# TimerOverlay 倒计时悬浮窗

macOS「时钟」App 的计时器运行时，在屏幕上显示一个置顶的悬浮倒计时窗口。

- 每秒以只读方式读取 `~/Library/Group Containers/group.com.apple.mobiletimerd/local.sqlite` 的 `ZMTCDTIMER` 表，不修改、不注入「时钟」App
- 剩余时间按 `响铃时刻 − 当前时间` 在本地计算，每 0.25 秒刷新
- 悬浮窗盖在所有窗口之上，全屏 App 里也能看到，可拖动；最后 10 秒变红，暂停时变灰
- 同时有多个计时器时显示最先结束的那个

## 要求

macOS 13 Ventura 及以上，需要 Xcode 命令行工具（`xcode-select --install`）。

## 获取

```bash
gh repo clone yzxq1/timer-overlay ~/倒计时悬浮窗
cd ~/倒计时悬浮窗
```

## 编译与运行

```bash
./build.sh
./倒计时悬浮窗 &
```

退出：`pkill -f 倒计时悬浮窗`

## 开机自启（可选）

在项目目录下执行：

```bash
cat > ~/Library/LaunchAgents/com.timeroverlay.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.timeroverlay</string>
  <key>ProgramArguments</key><array><string>$(pwd)/倒计时悬浮窗</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict></plist>
PLIST
launchctl load ~/Library/LaunchAgents/com.timeroverlay.plist
```

取消：`launchctl unload ~/Library/LaunchAgents/com.timeroverlay.plist && rm ~/Library/LaunchAgents/com.timeroverlay.plist`

## 已知限制

- `ZSTATE`：1 停止 / 2 暂停已确认；3 = 运行中，以及运行时 `ZFIRETIME` 的格式是推断的，待实测
- 依赖系统私有数据库格式，系统更新后可能失效（失效时只是不弹窗）
- GitHub 库名只支持英文，所以仓库仍叫 `timer-overlay`
