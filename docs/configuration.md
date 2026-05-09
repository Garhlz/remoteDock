# 配置文件

## 配置文件在哪里

RemoteDock 会把主机配置保存在：

```text
~/Library/Application Support/RemoteDock/hosts.json
```

首次启动时，如果这个文件不存在，应用会自动创建一个默认配置。

## 配置文件长什么样

当前配置文件是一个**文档对象**，而不是单纯的主机数组。

也就是说，最外层不是：

```json
[
  { "name": "..." }
]
```

而是：

```json
{
  "groups": [...],
  "hosts": [...]
}
```

示例：

```json
{
  "groups": [
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "name": "Lab"
    }
  ],
  "hosts": [
    {
      "address": "100.117.140.113",
      "autoPingIntervalMinutes": 5,
      "groupID": "11111111-1111-1111-1111-111111111111",
      "id": "00000000-0000-0000-0000-000000000001",
      "name": "Arch T480s",
      "preferredOpenMode": "ghostty",
      "port": 22,
      "remoteDirectory": "/home/elaine",
      "startupCommand": "cd -- {remoteDirectory} && exec zsh -l",
      "username": "elaine"
    }
  ]
}
```

仓库里也放了两份可直接参考的示例文件：

- `Examples/current-config.json`
  - 当前推荐的完整文档格式
- `Examples/legacy-hosts-array.json`
  - 旧版只保存 `[RemoteHost]` 的历史格式，方便理解迁移前后差异

## 字段说明

### `groups`

一个分组数组。每个分组至少有：

- `id`
- `name`

### `hosts`

一个主机数组。常见字段有：

- `id`：主机唯一标识
- `name`：显示名称
- `username`：SSH 用户名
- `address`：主机地址
- `port`：可选端口
- `groupID`：所属分组
- `remoteDirectory`：远程目录
- `startupCommand`：登录后执行的命令
- `preferredOpenMode`：首选打开方式
- `autoPingIntervalMinutes`：主机级自动 Ping 间隔
- `autoPingDisabled`：是否显式关闭自动 Ping

## 兼容旧配置

旧版本如果只保存了 `[RemoteHost]`，应用下次读取时会自动迁移到新格式。

如果 JSON 损坏，RemoteDock 会在界面里报错，并临时回退到默认主机列表；它不会悄悄覆盖坏文件。

## `startupCommand` 是做什么的

这个字段表示：

> SSH 登录成功以后，远端还要再执行什么命令

例如：

### Linux 示例

```text
cd -- {remoteDirectory} && exec zsh -l
```

含义是：

1. 进入远程目录
2. 再启动一个登录态的 zsh

### Windows 示例

```text
call "%USERPROFILE%\bin\remote.cmd" "{remoteDirectory}"
```

含义是：

1. 调用远端 Windows 机器上的包装脚本
2. 包装脚本再负责切目录、打开 PowerShell、加载 profile 等

其中：

```text
{remoteDirectory}
```

会在运行时替换成当前主机配置里的目录。

## Windows 主机的推荐做法

如果目标是 Windows，推荐把复杂启动逻辑放到远端 wrapper 脚本里，而不是直接在 `startupCommand` 里写一大串 PowerShell 命令。

推荐远端脚本位置：

```text
%USERPROFILE%\bin\remote.cmd
```

示例：

```bat
@echo off
set "TARGET=%~1"
if not defined TARGET set "TARGET=%USERPROFILE%"
cd /d "%TARGET%"
"C:\Users\Elaine\scoop\apps\pwsh\7.6.0\pwsh.exe" -NoLogo -NoExit -NoProfile -Command ". '%USERPROFILE%\Documents\PowerShell\RemoteDockProfile.ps1'"
```

然后在 RemoteDock 里配置：

```text
call "%USERPROFILE%\bin\remote.cmd" "{remoteDirectory}"
```
