# sm87xx TWRP 云编译仓库

一个最小化的 GitHub 仓库，用来在 GitHub Actions 上编出**一加 Ace 5 Pro (PKR110)** 的 TWRP recovery.img。
不需要本地 Linux、不需要 150GB 磁盘、不占用你电脑任何资源。

## 为什么用云编译

| 本地现状 | 后果 |
|---|---|
| `wsl.exe` 被安全策略列入程序黑名单 | 本地无法起 Linux 环境 |
| 最大剩余空间 119GB（L 盘） | TWRP 源码+产物需 120~150GB，卡线且易爆盘 |

GitHub Actions 的 ubuntu 运行器免费、可跑到 6 小时，配合清盘 + zram + ccache 足够编 TWRP。

## 三步用起来

### 1. 在 GitHub 上建一个空仓库

打开 https://github.com/new ，名字随意（例如 `twrp-sm87xx-build`），**不要**勾选 README/gitignore/license，建空仓库。

### 2. 把本目录推上去

在 PowerShell 或 Git Bash 里（把 URL 换成你自己的仓库）：

```bash
cd "C:/Users/Administrator/WorkBuddy/2026-10-29-11-05-11/twrp-build/ci-repo"
git init
git add -A
git commit -m "ci: TWRP build for sm87xx (PKR110)"
git branch -M main
git remote add origin https://github.com/<你的用户名>/twrp-sm87xx-build.git
git push -u origin main
```

首次 push 会要求登录。用 HTTPS 的话需要 Personal Access Token（Settings → Developer settings → Personal access tokens），
或者干脆用 GitHub Desktop / VS Code 的图形界面点几下推上去。

### 3. 跑 workflow

仓库页面 → **Actions** → 左侧 `Build TWRP (sm87xx / OnePlus Ace 5 Pro PKR110)` → **Run workflow**：

| 输入 | 取值 |
|---|---|
| `variant` | **先选 `baseline`**（上游原样，最可能直接可用） |
| `manifest_branch` | `twrp-16.0`（唯一可用，TWRP 没有 17 分支） |
| `device_tree_url` | 默认值即可（`kmiit/twrp_device_oplus_sm87xx`） |
| `device_tree_branch` | `twrp-16.0` |

约 2~3 小时后，在 run 页面底部 **Artifacts** 下载 `TWRP-sm87xx-baseline-YYYYMMDD.img`。

## 两个 variant 怎么选

```
baseline  上游设备树原样编译
          └─ 依据：实测你的机器 ro.vendor.build.version.sdk=35（vendor 仍是 A15 代），
             设备树 shipping API 也是 35，两者同代；真实 fstab 与树里逐字符一致。
             → 大概率直接能用，解密也可用。

a17       在 baseline 基础上叠加 Android 17 适配补丁
          └─ 只在 baseline 出现「进得去但 /data 解不开」时才用。
             改动：打开 FBE/metadata 解密显式开关、版本号标记 A17、注入诊断脚本。
```

## 编译完成后怎么刷

```bash
adb reboot bootloader
fastboot devices                          # 必须能看到设备
fastboot getvar unlocked                  # 必须是 yes
fastboot flash recovery_a TWRP-sm87xx-baseline-20261029.img
fastboot flash recovery_b TWRP-sm87xx-baseline-20261029.img
fastboot reboot recovery
```

## 如果 workflow 失败

| 报错 | 处理 |
|---|---|
| `No space left on device` | 说明清盘 action 失效，把 `slimhub_actions` 换成手动 `sudo rm -rf` 大目录 |
| `repo sync` 大量 fatal | GitHub 到 googlesource 抖动，重跑一次即可（workflow 可重跑） |
| `Killed` / signal 9 | 内存不足，把 `make recoveryimage -j4` 降成 `-j2` |
| `ninja: unknown target recoveryimage` | lunch 没生效，检查 `device/oplus/sm87xx` 是否克隆成功（日志里有 `ls` 输出） |

诊断用：每次运行都会上传 `build-log-<variant>` artifact，里面有完整 `make` 输出。

## 目录说明

| 路径 | 作用 |
|---|---|
| `.github/workflows/build.yml` | 编译流程：清盘 → 装依赖 → zram → repo sync → 拉设备树 → （可选）叠补丁 → 编译 → 上传 |
| `overlay/` | Android 17 适配补丁文件，仅 `variant=a17` 时被复制进设备树 |
