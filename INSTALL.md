# AO Conductor Kit 安装总指南

实测安装路径日期：**2026-04-11**

适用对象：第一次在 Windows 10 上从零安装 AO Conductor Kit 的用户。

适用系统：Windows 10 build 19041 或更高版本；Windows 11 也适用，且体验通常更稳定。

本文按 2026-04-11 的实测路径编排。任务说明把流程描述为“8 个阶段”，同时又给出了 `Phase 0` 到 `Phase 8` 的编号。为了避免读者在实际操作时漏掉前置检查，本文保留完整编号：`Phase 0` 是开工前必须通过的前置检查，`Phase 1` 到 `Phase 8` 是正式执行阶段。

如果你的仓库在 Windows 侧位于 `D:\ao-kit`，那么同一路径在 WSL 里通常显示为 `/mnt/d/ao-kit`。本文后续会同时使用 Windows 路径和 WSL 路径示例，你只需要把示例中的路径替换成自己的实际位置即可。

## 安装总览
`Phase 0` 是前置检查，不计入下面这 8 个执行阶段。你应先完成 `Phase 0`，再按顺序执行 `Phase 1` 到 `Phase 8`。

| 阶段 | 名称 | 运行侧 | 结果 |
| --- | --- | --- | --- |
| Phase 1 | 运行 `scripts/bootstrap-wsl2.ps1` | Windows | 打开 WSL2 所需组件，准备 Ubuntu 22.04 |
| Phase 2 | 重启并重新运行 WSL2 引导脚本 | Windows | 完成内核与 rootfs 安装，得到 `Ubuntu-22.04` |
| Phase 3 | 运行 `scripts/bootstrap-ao.sh` | WSL | 安装 git、Node 20、pnpm、Codex、Claude、gh、AO |
| Phase 4 | 配置 Codex 代理 | WSL | 让 Codex 通过你的 LLM 代理正常调用模型 |
| Phase 5 | 配置 Windows 端口转发 | Windows | 让 WSL 能通过 Clash Verge 之类的代理访问外网 |
| Phase 6 | 配置 WSL 内 git 代理 | WSL | 让 `git clone`、`git fetch`、`git push` 更稳定 |
| Phase 7 | 配置 GitHub 认证 | WSL | 让 `gh` 和 `git push` 具备有效身份认证 |
| Phase 8 | 执行第一次 AO 冒烟测试 | WSL | 验证 `ao start` 与浏览器 Dashboard 正常 |

建议预留 20 到 40 分钟的连续时间。网络波动、代理连通性、系统是否已经启用过 WSL，都可能显著影响实际耗时。

## Phase 0 — 前置检查
### 这一阶段要完成什么
这一阶段的目标不是安装任何东西，而是确认你的机器已经满足后续步骤的最低条件。只要这里漏掉一个关键前提，后面的脚本通常不会“半成功”，而是直接在中途失败，或者表面完成但后续无法联网、无法启动虚拟化、无法创建 Ubuntu 发行版。

这一步通过后，你应当能够确认五件事：Windows 版本达标、当前 PowerShell 具备管理员权限、BIOS 虚拟化已打开、系统盘至少有 15 GB 可用空间、并且你具备稳定的互联网访问条件。

### 前提检查
先在 Windows 桌面完成两个图形界面检查：

1. 按 `Ctrl + Shift + Esc` 打开任务管理器。
2. 切到“性能”页，再点“CPU”。
3. 看右下角的 `Virtualization` 字段，必须是 `Enabled`。

如果这里显示 `Disabled`，后面的 WSL2 会失败。你必须先进 BIOS/UEFI 打开 Intel VT-x 或 AMD-V，再回到这里复查。

### 要执行的命令
命令环境：Windows PowerShell（管理员）
```powershell
systeminfo | findstr /B /C:"OS Name" /C:"OS Version"
(Get-CimInstance Win32_OperatingSystem).BuildNumber
whoami /groups | findstr /I "S-1-5-32-544"
Get-PSDrive C | Select-Object Used, Free
```

### 预期输出
你不需要逐字对照，只要满足下面几个判断条件即可：

- `BuildNumber` 应大于或等于 `19041`。
- `whoami /groups` 的输出里应能看到管理员组 SID，也就是 `S-1-5-32-544` 对应的行。
- `Get-PSDrive C` 的 `Free` 值应至少相当于 15 GB。
- 任务管理器的 CPU 面板里，`Virtualization` 必须是 `Enabled`。

如果你准备通过 GitHub 推送代码，建议现在就确认 Windows 侧已经有可用代理，例如 Clash Verge，并记住它提供的 HTTP 代理端口。本文后面的示例使用 `7897`，如果你的端口不同，后面所有涉及代理的命令都要一起改。

### 如何验证
这一阶段的验证标准很简单：只有当下面四项都满足时，才继续往下。

1. Windows 版本号达到 `19041` 或更高。
2. 当前 PowerShell 确实是管理员打开。
3. 虚拟化已在 BIOS 和任务管理器两侧都确认开启。
4. 系统盘可用空间不少于 15 GB。

如果你对“管理员 PowerShell”不确定，最直接的办法是关闭当前窗口，从开始菜单搜索 `PowerShell`，右键选择“以管理员身份运行”，然后重新执行上面的检查命令。

### 排错入口
如果这里失败，不要硬做下一步。请先查看 `TROUBLESHOOTING.md` 中与以下症状对应的条目：

- Windows build 低于 19041
- 虚拟化未启用
- 没有管理员权限
- 磁盘空间不足
- 代理尚未准备好

## Phase 1 — 运行 `scripts/bootstrap-wsl2.ps1`
### 这一阶段要完成什么
这一阶段在 Windows 侧打开 WSL2 所需的系统功能，并开始安装后续阶段需要的组件。脚本的职责包括：通过 DISM 启用 WSL/虚拟机特性、下载并安装 WSL2 kernel MSI、下载 Ubuntu 22.04 rootfs，并导入成可启动的发行版。

第一次在“完全干净”的 Windows 10 机器上执行时，这个脚本通常不会一次跑到最后。最常见的情况是：脚本完成 DISM 相关操作后，检测到需要重启，于是干净退出，等待你进入下一阶段。

### 前提检查
确保你当前所在目录就是包含 `scripts\bootstrap-wsl2.ps1` 的仓库根目录，且 PowerShell 窗口是“管理员身份”。如果你的仓库路径中包含空格，不影响执行，但你必须在输入命令时保持路径正确。

如果你使用的是资源管理器打开仓库目录，建议在地址栏输入 `powershell` 并按回车，再手动“以管理员身份”重新打开 PowerShell 到同一路径，避免当前窗口不是管理员导致脚本中途报权限错误。

### 要执行的命令
命令环境：Windows PowerShell（管理员）
```powershell
powershell -ExecutionPolicy Bypass -File scripts\bootstrap-wsl2.ps1
```

### 预期输出
在一台全新的 Windows 10 机器上，最典型的正常输出路径是下面两种之一：

- 情况 A：脚本完成 DISM 相关步骤后提示需要重启，然后自行退出。
- 情况 B：如果机器之前已经启用过相关功能，脚本可能继续往下执行，直到导入 Ubuntu 并在最后通过 `wsl -l -v` 显示 `Ubuntu-22.04`。

你需要特别记住一件事：**第一次执行后要求重启，不是失败，而是正常状态。**

如果脚本已经完整执行到结束，那么最后应能看到类似下面的目标状态：

```text
Ubuntu-22.04    Stopped    2
```

不过在多数全新机器上，这个结果会出现在下一阶段，也就是重启后重新执行脚本之后。

### 如何验证
如果脚本明确告诉你“需要重启”或者提示系统功能已启用但需要重新启动，直接进入 `Phase 2`，不要在此阶段反复重跑。

如果脚本似乎已经跑完，可以手动检查一次：

命令环境：Windows PowerShell（管理员）
```powershell
wsl -l -v
```

只要你能看到 `Ubuntu-22.04` 这一项，且版本号为 `2`，这个阶段就算通过。

### 排错入口
如果这一阶段失败，请优先看 `TROUBLESHOOTING.md` 中这些症状：

- DISM 启用组件失败
- PowerShell 提示执行策略或权限不足
- 下载 kernel MSI 失败
- 第一次运行后脚本直接退出但没有说明原因
- `wsl -l -v` 为空或命令不存在

## Phase 2 — 重启电脑并重新运行 WSL2 引导脚本
### 这一阶段要完成什么
这一阶段负责承接 `Phase 1` 里“需要重启才能继续”的那部分工作。对于全新环境，只有在 Windows 完成一次重启后，`C:\Windows\System32\wsl.exe` 这个桩程序才会稳定可用，后续的 kernel 安装、Ubuntu rootfs 导入和发行版注册才会真正完成。

简短地说：`Phase 1` 主要是“把系统改成支持 WSL2 的状态”，`Phase 2` 才是“在已经支持 WSL2 的系统上把 Ubuntu 22.04 落下来”。

### 前提检查
在点击重启之前，你不需要先卸载任何东西，也不需要手动点开“启用或关闭 Windows 功能”面板。只要 `Phase 1` 的脚本是正常退出并告诉你需要重启，就说明该走这一步了。

重启完成后，重新登录 Windows，再次打开管理员 PowerShell，并切回你的仓库根目录。

### 要执行的命令
命令环境：Windows PowerShell（管理员）
```powershell
Restart-Computer -Force
```

登录回系统后，再执行：

命令环境：Windows PowerShell（管理员）
```powershell
Get-Command wsl.exe
powershell -ExecutionPolicy Bypass -File scripts\bootstrap-wsl2.ps1
wsl -l -v
```

### 预期输出
这一阶段完成后，应看到下面两个关键结果：

- `Get-Command wsl.exe` 能返回 `wsl.exe` 的路径，通常在 `C:\Windows\System32\wsl.exe`。
- `wsl -l -v` 能看到 `Ubuntu-22.04`，状态通常是 `Stopped`，版本是 `2`。

典型的目标结果如下：

```text
NAME            STATE      VERSION
Ubuntu-22.04    Stopped    2
```

如果你看到的是 `Running`，通常也没有问题，说明发行版已经被唤起过一次。

### 如何验证
这一步的验证条件只有一个：在 Windows 侧执行 `wsl -l -v` 时，`Ubuntu-22.04` 必须已经存在，且 `VERSION` 为 `2`。

如果存在同名旧发行版，先不要在没有确认数据价值的情况下删除它。你应先查看 `TROUBLESHOOTING.md` 中“已有旧版 Ubuntu-22.04”相关条目，再决定是否备份和重装。

### 排错入口
以下问题都应该先到 `TROUBLESHOOTING.md` 找对应症状，不要盲目重复重启：

- 重启后 `wsl.exe` 仍不存在
- `bootstrap-wsl2.ps1` 第二次运行时下载失败
- `wsl -l -v` 看不到 `Ubuntu-22.04`
- `Ubuntu-22.04` 被创建成 WSL1 而不是 WSL2
- 系统弹出 MSI 安装错误

## Phase 3 — 运行 `scripts/bootstrap-ao.sh`
### 这一阶段要完成什么
这一阶段切到 WSL 侧，进入真正的 AO 开发环境安装。脚本会安装一整套后续必需组件，包括 `git`、`tmux`、`build-essential`、Node 20、`pnpm 9.15.4`、Codex CLI、Claude CLI、GitHub CLI，以及 agent-orchestrator 本体，并最终把 `ao` 命令链接到 `/usr/local/bin/ao`。

这是第一次“时间明显变长”的阶段。网络正常时，通常需要 5 到 10 分钟；如果代理、镜像或 npm 下载较慢，耗时可能更长。

### 前提检查
先确认两件事：

1. `Ubuntu-22.04` 已经在 `wsl -l -v` 中出现，并且版本是 `2`。
2. 你知道 Windows 仓库路径在 WSL 中对应到哪里。

例如，如果你的仓库位于 Windows 的 `D:\ao-test`，那么在 WSL 里通常应写成 `/mnt/d/ao-test`。如果你不确定路径，可以先在 WSL 里执行 `ls /mnt/d`、`ls /mnt/c` 逐层确认。

### 要执行的命令
主命令如下。

命令环境：WSL bash（root）
```bash
wsl -d Ubuntu-22.04 -- bash /mnt/d/your/path/to/scripts/bootstrap-ao.sh
```

如果你是从 Windows 侧直接发起，也可以在 Windows 终端里运行等价命令。

命令环境：Windows PowerShell
```powershell
wsl -d Ubuntu-22.04 bash /mnt/d/your/path/to/scripts/bootstrap-ao.sh
```

脚本完成后，建议立刻在 WSL 里检查关键命令。

命令环境：WSL bash（root）
```bash
wsl -d Ubuntu-22.04 -- bash -lc 'whoami && command -v git tmux node pnpm codex claude gh ao'
```

### 预期输出
这一阶段的最终目标不是某一条单独日志，而是脚本结尾出现一个包含 9 个项目的版本汇总块。不同机器上的文本细节可能不同，但你应该能看到类似下面这些内容：

- `git` 版本
- `tmux` 版本
- `gcc` 或 `build-essential` 相关可用性
- `node` 版本，且为 20 系列
- `pnpm` 版本，且为 `9.15.4`
- `codex` 版本
- `claude` 版本
- `gh` 版本
- `ao` 可执行路径或版本

如果脚本在安装 Node、pnpm 或 CLI 工具时卡住很久，优先怀疑网络问题，不要第一时间假设脚本逻辑出错。

### 如何验证
这一阶段的推荐验证方式是分别确认“命令是否存在”和“`ao` 链接是否成立”。

命令环境：WSL bash（root）
```bash
whoami
command -v ao
ls -l /usr/local/bin/ao
ao --help | head -n 20
```

通过标准如下：

- `whoami` 输出 `root`。
- `command -v ao` 返回 `/usr/local/bin/ao`。
- `ls -l /usr/local/bin/ao` 能看到它是一个符号链接。
- `ao --help` 能正常打印帮助信息，而不是“command not found”。

### 排错入口
如果这一步失败，请到 `TROUBLESHOOTING.md` 找对应症状：

- `/mnt/d/.../bootstrap-ao.sh` 路径找不到
- apt 安装失败
- Node 20 没装上
- `pnpm` 版本不对
- `codex`、`claude`、`gh`、`ao` 任一命令不存在
- `/usr/local/bin/ao` 没有正确指向可执行文件

## Phase 4 — 配置 Codex 使用你的 LLM 代理
### 这一阶段要完成什么
从这一步开始，你要把 Codex 连接到自己的模型代理。这个代理可以是你自建的 OpenAI 兼容网关，也可以是公司内网代理，核心要求只有一个：它需要能让 Codex 以 `responses` 风格 API 与 `gpt-5.4` 这类模型通信。

这里需要配置两个文件：一个是 `/root/.codex/config.toml`，负责告诉 Codex “去哪里请求模型”；另一个是 `/root/.codex/auth.json`，负责告诉 Codex “用什么 API Key 去请求模型”。

### 前提检查
先确认你当前在 WSL 里，并且具备 root 权限。还要确认你已经知道代理地址与端口，例如 `http://your-proxy-host:port`。如果你连代理地址都还没确定，不要继续写配置文件，先把代理服务本身准备好。

这一步不要把真实密钥写进教程、截图、聊天记录或公共仓库。下面所有示例都必须保持占位符形式。

### 要执行的命令
先创建配置目录和 `config.toml`。

命令环境：WSL bash（root）
```bash
mkdir -p /root/.codex
cat >/root/.codex/config.toml <<'EOF'
model_provider = "my-proxy"
model = "gpt-5.4"
model_reasoning_effort = "xhigh"
model_context_window = 1000000

[model_providers.my-proxy]
name = "my-proxy"
base_url = "http://your-proxy-host:port"
wire_api = "responses"
requires_openai_auth = true
EOF
```

再写入认证文件，并严格收紧权限。

命令环境：WSL bash（root）
```bash
cat >/root/.codex/auth.json <<'EOF'
{
  "OPENAI_API_KEY": "sk-your-key-here"
}
EOF
chmod 600 /root/.codex/auth.json
```

然后执行一次最小冒烟测试。

命令环境：WSL bash（root）
```bash
cd /tmp
codex exec --sandbox read-only --skip-git-repo-check "say hi in 3 words"
```

### 预期输出
正常情况下，Codex 会在 10 到 30 秒内返回一句只有三个英文单词的回复。具体内容可以不同，例如类似 `Hi from Codex` 这样长度正确的回答都算通过。

另外，文件权限也应满足下面两个条件：

- `/root/.codex/config.toml` 已存在，并包含正确的 `base_url`。
- `/root/.codex/auth.json` 的权限是 `600`，也就是只有 root 自己能读写。

### 如何验证
建议从“文件存在”“权限正确”“网络打通”“模型可答复”四个角度同时验证。

命令环境：WSL bash（root）
```bash
ls -l /root/.codex/config.toml /root/.codex/auth.json
sed -n '1,120p' /root/.codex/config.toml
timeout 40 codex exec --sandbox read-only --skip-git-repo-check "say hi in 3 words"
```

判断标准如下：

- `auth.json` 权限应显示为 `-rw-------`。
- `config.toml` 里的 `base_url` 必须是你真实可达的代理地址。
- `codex exec` 需要在合理时间内返回结果，而不是卡死或报 401、403、连接拒绝。

### 排错入口
这一阶段失败时，最常见的是配置问题，不是 Codex 本身的问题。请到 `TROUBLESHOOTING.md` 查这些症状：

- `base_url` 填错
- 代理不支持 `responses` API
- `OPENAI_API_KEY` 无效
- `auth.json` 权限过宽
- `codex exec` 超时或返回认证错误

## Phase 5 — 修复 Windows 代理端口转发
### 这一阶段要完成什么
这一步的目标是让 WSL 能通过 Windows 上已经运行的代理软件访问外网。最常见的场景是：你在 Windows 上打开了 Clash Verge，它在本机 `127.0.0.1:7897` 监听 HTTP 代理；但 WSL2 的 `localhostForwarding=true` 偶尔会失效，所以仓库现在提供了一个**自愈脚本**来自动探测当前 WSL 面向 Windows 的主机 IP，并修复 `portproxy` 漂移。

如果你在运行 `scripts/bootstrap-wsl2.ps1` 时，Windows 代理已经在 `127.0.0.1:7897` 监听，bootstrap 脚本会自动尝试做同样的修复。`Phase 5` 仍然是推荐的显式入口，因为它可以在换网段、重装 WSL 或代理重启后单独重复执行，而且同一条命令可以安全重跑。

### 前提检查
先确保你的代理软件已经在 Windows 上运行，并确认它的 HTTP 代理端口。默认示例端口仍然使用 `7897`，如果你的代理软件用的是别的端口，下面命令里的 `-ListenPort` 和 `-ConnectPort` 都要一起改。

另外，PowerShell 必须是“管理员身份”，而且 `Ubuntu-22.04` 已经通过前面的 WSL2 引导步骤导入为 WSL2 发行版。

### 要执行的命令
命令环境：Windows PowerShell（管理员）
```powershell
powershell -ExecutionPolicy Bypass -File scripts\repair-wsl2-localhost-forwarding.ps1 -DistroName Ubuntu-22.04 -ListenPort 7897 -ConnectPort 7897
```

### 预期输出
你需要看到下面这几类结果：

- 脚本会打印当前探测到的 WSL 面向 Windows 的主机 IP，例如 `172.x.x.x`。
- 如果旧的 `portproxy` 规则还绑在旧 IP 上，脚本会删除旧规则并重建。
- 如果规则本来就是最新状态，脚本会明确告诉你“already up to date”之类的结果。
- 脚本会确保对应的 Windows 防火墙规则存在，并在最后从 WSL 侧做一次连通性验证。

如果你使用的不是 `7897` 端口，那么输出里的目标端口也应与你的实际端口一致。端口号只要前后一致即可，不要求一定是 `7897`。

### 如何验证
最好的验证办法是在 WSL 里动态取当前 Windows host IP，再通过这个地址访问外网。

命令环境：WSL bash（root）
```bash
WSL_HOST_IP=$(ip route show default | awk '/default/ {print $3; exit}')
HTTPS_PROXY="http://${WSL_HOST_IP}:7897" curl -I https://github.com
```

如果代理链路正确，你通常会看到来自 GitHub 的 HTTP 响应头，例如 `HTTP/2 200` 或 `HTTP/2 302`。只要不是连接超时、连接被拒绝或 DNS 失败，就说明这一步基本通了。

### 排错入口
这一阶段排错时，请重点看 `TROUBLESHOOTING.md` 中这些症状：

- 自愈脚本无法探测当前 WSL host IP
- 端口转发规则修复失败
- 防火墙规则未生效
- WSL 中 `curl` 走代理仍超时
- Clash Verge 端口不是 7897

## Phase 6 — 在 WSL 中设置 git 代理
### 这一阶段要完成什么
这一步把 Git 在 WSL 里的 HTTP/HTTPS 访问强制走刚才设置好的 Windows 代理。这样做的目标不是为了“让所有网络都走代理”，而是专门解决 `git clone`、`git fetch`、`git push` 在 WSL 中与 GitHub 通信时经常遇到的超时、握手失败或推送中断问题。

这一步非常重要，但还不够。根据 2026-04-11 的实测经验，**仅靠全局 git 代理配置并不总是足够稳定**。在大推送或特殊网络情况下，`git push` 仍建议显式附带 `HTTPS_PROXY=...` 环境变量作为双保险。

### 前提检查
开始之前，先确保 `Phase 5` 已经通过。最稳妥的做法是先取一次当前 Windows host IP，然后确认 `curl` 能通过这个地址访问 GitHub。

命令环境：WSL bash（root）
```bash
WSL_HOST_IP=$(ip route show default | awk '/default/ {print $3; exit}')
HTTPS_PROXY="http://${WSL_HOST_IP}:7897" curl -I https://github.com
```

如果你此时连 `curl -I https://github.com` 都还不通，不要继续设置 git 代理。因为 Git 本身只会把网络问题暴露得更隐蔽，不会自动帮你修好它。

### 要执行的命令
命令环境：WSL bash（root）
```bash
WSL_HOST_IP=$(ip route show default | awk '/default/ {print $3; exit}')
git config --global http.proxy "http://${WSL_HOST_IP}:7897"
git config --global https.proxy "http://${WSL_HOST_IP}:7897"
git config --global --get http.proxy
git config --global --get https.proxy
```

以后真正执行推送时，请优先使用下面这种写法：

命令环境：WSL bash（root）
```bash
WSL_HOST_IP=$(ip route show default | awk '/default/ {print $3; exit}')
HTTPS_PROXY="http://${WSL_HOST_IP}:7897" git push origin main
```

### 预期输出
前四条 `git config` 命令通常不会返回很多文字，但两条 `--get` 命令应分别打印形如下面这种值：

```text
http://172.x.x.x:7897
```

最后那条 `git push` 示例命令在这一步不要求立刻真的推送你的主仓库；它的作用是告诉你，后面凡是需要推送，都建议保留这个环境变量前缀。

### 如何验证
先验证配置值是否写进 Git。

命令环境：WSL bash（root）
```bash
git config --global --list | grep -E 'http\.proxy|https\.proxy'
```

如果你已经在某个测试仓库里配置了远程地址，还可以做一次轻量检查：

命令环境：WSL bash（root）
```bash
WSL_HOST_IP=$(ip route show default | awk '/default/ {print $3; exit}')
HTTPS_PROXY="http://${WSL_HOST_IP}:7897" git ls-remote https://github.com/git/git HEAD
```

只要能返回一个提交哈希和 `HEAD`，就说明 Git 经由该代理访问外网基本正常。

### 排错入口
这一阶段失败时，请查看 `TROUBLESHOOTING.md` 中这些症状：

- git 代理配置写入失败
- `git ls-remote` 仍超时
- 只配了 `http.proxy` 没配 `https.proxy`
- 大推送时不加 `HTTPS_PROXY` 会断流
- 代理地址应更新为新的 WSL 网关 IP

## Phase 7 — 配置 GitHub 身份认证
### 这一阶段要完成什么
到这一步，你的机器通常已经“能联网”。但“能联网”不等于“能推送”。如果你没有给 `gh` 和 `git` 配好 GitHub 身份认证，`git push` 最终会在网络完全正常的情况下返回 `401 Unauthorized`。

因此，这一步是**关键步骤**。它负责把你的 GitHub Personal Access Token 写入 `gh` 的认证存储，并让 Git 通过 `gh auth setup-git` 接管凭据。

### 前提检查
开始之前，请先准备一个 GitHub Personal Access Token。任务要求的最小 scope 是：

- `repo`
- `workflow`
- `read:org`

你可以在下面这个地址生成：

`https://github.com/settings/tokens/new`

不要把真实 token 贴进任何文档、截图或仓库历史中。下面命令中的 `ghp_your_token_here` 只是占位符。

### 要执行的命令
命令环境：WSL bash（root）
```bash
echo "ghp_your_token_here" | gh auth login --with-token
gh auth setup-git
gh auth status
```

如果 `gh auth status` 仍不能让你放心，再做一次额外读取测试。

命令环境：WSL bash（root）
```bash
gh repo view hahyihao/ao-test
```

### 预期输出
正常情况下：

- `gh auth login --with-token` 会完成登录，不应返回认证失败。
- `gh auth setup-git` 会提示 Git 已被配置为使用 GitHub CLI 作为凭据辅助程序。
- `gh auth status` 会显示你已登录到 `github.com`。

如果你看到的是 `not logged into any GitHub hosts`、`HTTP 401`、`token invalid` 之类的信息，这一步就没有通过。

### 如何验证
推荐至少做两层验证。

第一层，确认 `gh` 自己已经登录：

命令环境：WSL bash（root）
```bash
gh auth status -h github.com
```

第二层，确认 Git 会走 `gh` 凭据：

命令环境：WSL bash（root）
```bash
git config --global --get-all credential.helper
```

只要 `gh auth status` 正常，且 Git 的凭据辅助设置已经接上 `gh`，这一步就算完成。后面如果 `git push` 仍报 401，优先回来看这里，而不是先怀疑代理。

### 排错入口
请在 `TROUBLESHOOTING.md` 中查阅这些症状：

- token scope 不够
- token 已过期或输错
- `gh auth setup-git` 没生效
- `git push` 返回 401 Unauthorized
- 企业或组织策略阻止 PAT 使用

## Phase 8 — 第一次 AO 冒烟测试
### 这一阶段要完成什么
这是整份安装指南的收尾阶段，目标是验证你前面做的所有事情能够串起来形成一个最小但完整的工作流：在 WSL 中创建一个玩具 Git 仓库，推送到 GitHub，放入 AO 模板配置，然后启动 `ao`，并在 Windows 浏览器里打开 Dashboard。

如果你走完这一步，说明 WSL2、代理、git、GitHub 认证、Codex 相关配置以及 AO 本体都已经至少具备“可以开始工作”的最低状态。

### 前提检查
在正式创建测试仓库前，请先确认下面四点：

1. `ao --help` 能运行。
2. `gh auth status` 正常。
3. 先取当前 `WSL_HOST_IP`，再执行 `HTTPS_PROXY="http://${WSL_HOST_IP}:7897" git ls-remote https://github.com/git/git HEAD`，并确认它能返回结果。
4. 你已经设置过 Git 身份信息；如果没有，需要先补。

如果 Git 用户名和邮箱还没设，先执行下面两条。已经设过的用户可以跳过。

命令环境：WSL bash（root）
```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

### 要执行的命令
先创建玩具仓库并提交。

命令环境：WSL bash（root）
```bash
mkdir -p /root/projects/ao-hello
cd /root/projects/ao-hello
git init -b main
echo "# AO Hello" > README.md
git add .
git commit -m "init"
```

然后创建 GitHub 仓库并首推。

命令环境：WSL bash（root）
```bash
WSL_HOST_IP=$(ip route show default | awk '/default/ {print $3; exit}')
HTTPS_PROXY="http://${WSL_HOST_IP}:7897" gh repo create ao-hello --public --source=. --remote=origin --push
```

接着复制 AO 模板并修改 `repo`、`path` 字段。下面示例假设 `bootstrap-ao.sh` 默认把 agent-orchestrator 克隆到了 `/root/agent-orchestrator`；如果你的实际克隆路径不同，只替换左侧源文件路径即可。

命令环境：WSL bash（root）
```bash
mkdir -p .ao
cp /root/agent-orchestrator/templates/agent-orchestrator.yaml .ao/agent-orchestrator.yaml
vi .ao/agent-orchestrator.yaml
grep -nE 'repo:|path:' .ao/agent-orchestrator.yaml
```

最后启动 AO。

命令环境：WSL bash（root）
```bash
cd /root/projects/ao-hello
ao start
```

### 预期输出
这个阶段依次应出现下面这些结果：

- `git commit -m "init"` 成功生成第一次提交。
- `gh repo create ... --push` 成功创建远程仓库并推送到 GitHub。
- `grep -nE 'repo:|path:' .ao/agent-orchestrator.yaml` 能看到你刚刚改好的 `repo` 和 `path`。
- `ao start` 输出中包含下面两段关键信息：

```text
Dashboard: http://localhost:3000
Orchestrator: http://localhost:3000/sessions/hello-orchestrator-1
```

实际 session 名称可能与你的项目名有关，不一定逐字相同，但应当是 `http://localhost:3000/sessions/...` 这种形式。

### 如何验证
先在 WSL 里确认 `ao start` 没有立即退出。然后直接回到 Windows 浏览器，打开：

`http://localhost:3000`

WSL2 默认会把 `localhost` 从 Linux 自动转发到 Windows，所以你通常不需要额外配端口映射。只要浏览器能打开 Dashboard 页面，这一步就通过了。

如果你想在终端里再做一层检查，可以新开一个 WSL 终端窗口执行：

命令环境：WSL bash（root）
```bash
curl -I http://localhost:3000
```

只要能返回本地服务响应，而不是连接被拒绝，这个 AO 冒烟测试就成立。

### 排错入口
如果最终没有看到 Dashboard，请到 `TROUBLESHOOTING.md` 查这些症状：

- `git commit` 因未配置用户信息失败
- `gh repo create --push` 因认证或代理失败
- 模板路径 `/root/agent-orchestrator/templates/agent-orchestrator.yaml` 不存在
- `repo` 或 `path` 字段填写错误
- `ao start` 启动后立即退出
- Windows 浏览器打不开 `http://localhost:3000`

## 常见问题
### 什么时候必须重启，什么时候不要反复重跑脚本
只要 `scripts/bootstrap-wsl2.ps1` 明确提示你“需要重启后继续”，就先重启，不要在同一轮 Windows 会话里反复多次执行同一个脚本。对于全新 Windows 10 环境，这是正常路径，不是异常。

### 为什么代理已经通了，`git push` 还是会失败
最常见的原因不是网络，而是认证。请先回到 `Phase 7` 检查 `gh auth status` 和 `gh auth setup-git` 是否成功。其次，再确认你推送时是否像文档那样先取了当前 `WSL_HOST_IP`，并保留了 `HTTPS_PROXY="http://${WSL_HOST_IP}:7897"` 这个前缀。

### `codex exec` 有时能跑，有时超时，优先查哪一层
优先顺序通常是：`base_url` 是否正确、代理是否稳定、API key 是否可用、代理是否支持 `responses` API。不要先把问题归因到 Codex CLI 本身。

### `Ubuntu-22.04` 已经存在，还要不要删掉重装
不要先删。先确认现有实例是不是你之前的工作环境，是否有数据需要保留，以及它是不是已经是 WSL2。具体处理方法请查 `TROUBLESHOOTING.md` 中关于“已有旧版 Ubuntu-22.04”的条目。

### `ao start` 成功了，但浏览器打不开 Dashboard
先在 WSL 里用 `curl -I http://localhost:3000` 看本地服务是否在监听。如果 WSL 内有响应、Windows 浏览器没有响应，再看是否有本地防火墙、端口占用或浏览器代理干扰。

### 出现具体报错时去哪里看
这份 `INSTALL.md` 负责给出从零安装的主路径，不会把所有分支故障都展开到很细。只要你遇到下面这些更具体的症状，请直接去看 `TROUBLESHOOTING.md`：

- Windows 组件启用失败
- WSL 导入 Ubuntu 失败
- `bootstrap-ao.sh` 安装中断
- Codex 代理认证失败
- GitHub 401 或代理超时
- AO Dashboard 无法打开

如果你严格按本文顺序执行，并且每个阶段都先做“验证”再进入下一阶段，那么排查范围通常会被压缩得很小，问题也更容易定位。
