# TROUBLESHOOTING

AO 初装故障排查记录
环境基线：Windows 10 21H1
记录日期：2026-04-11 至 2026-04-12

本文只记录 2026-04-11 至 2026-04-12 在 Windows 10 21H1 上安装和运行 AO 时真实出现过、并且已经确认修复的问题。
每一节都按“现象、根因、修复、预防”展开。
如果你遇到的错误信息和这里完全一致，优先按本文的修复路径处理，不要同时叠加多个猜测性的改动。

## 目录

- [Issue 1：Win10 21H1 上 `wsl --install` 无法识别](#issue-1win10-21h1-上-wsl---install-无法识别)
- [Issue 2：Ubuntu rootfs 下载链接返回 404](#issue-2ubuntu-rootfs-下载链接返回-404)
- [Issue 3：WSL bash 一改 PATH 就报 `not a valid identifier`](#issue-3wsl-bash-一改-path-就报-not-a-valid-identifier)
- [Issue 4：误用 bun 导致 pnpm 构建失败](#issue-4误用-bun-导致-pnpm-构建失败)
- [Issue 5：`runtime:process` 下 AO orchestrator 会立即死亡](#issue-5runtimeprocess-下-ao-orchestrator-会立即死亡)
- [Issue 6：Clash fake-ip 下 `git push` 卡死但 `curl` 正常](#issue-6clash-fake-ip-下-git-push-卡死但-curl-正常)
- [Issue 7：代理修好后 `git push` 仍然返回 401](#issue-7代理修好后-git-push-仍然返回-401)
- [Issue 8：没有安装 `gh` 时 `ao spawn` 直接拒绝启动](#issue-8没有安装-gh-时-ao-spawn-直接拒绝启动)
- [Issue 9：Codex 直连测试 `/responses` 返回 200 但没有输出内容](#issue-9codex-直连测试-responses-返回-200-但没有输出内容)
- [Issue 10：Codex 提示 `bubblewrap on PATH not found`](#issue-10codex-提示-bubblewrap-on-path-not-found)
- [Issue 11：tmux 3.2a segfault 导致所有 codex TUI session 神秘死亡](#issue-11tmux-32a-segfault-导致所有-codex-tui-session-神秘死亡)
- [Issue 12：ao session kill 不清 worktree，新 worker 因 Git checkout 冲突立刻 exit](#issue-12ao-session-kill-不清-worktree新-worker-因-git-checkout-冲突立刻-exit)
- [Issue 14：AO web/API 假死，实为卡住的 `gh api graphql` 拖住 Next.js 服务端](#issue-14ao-webapi-假死实为卡住的-gh-api-graphql-拖住-nextjs-服务端)
- [误诊链路（历史记录）](#误诊链路历史记录)
- [调试技巧](#调试技巧)
- [已知无害警告](#已知无害警告)

## Issue 1：Win10 21H1 上 `wsl --install` 无法识别

### 现象

在管理员 PowerShell 里直接执行 `wsl --install`，系统返回 `wsl : 无法将wsl项识别为 cmdlet...`。
继续检查时会发现 `C:\Windows\System32\wsl.exe` 根本不存在。
这时很多人的第一反应会是 PATH 配错了，或者 PowerShell 权限不够。
但这次安装里，PowerShell 本身没有问题，管理员权限也没有问题。
真正异常的是当前系统版本并不具备那个“一条命令装 WSL”的入口。

### 根因

`wsl --install` 这个现代单行命令是 Windows 11 的能力。
微软后来把其中一部分体验回迁到了 Windows 10 22H2。
但是 Windows 10 21H1 并没有完整拿到这条路径，所以直接调用时不会自动帮你启用组件，也不会生成 `wsl.exe`。
在这个版本上，只有先启用 `Microsoft-Windows-Subsystem-Linux`，并且完成重启，`wsl.exe` 这个 stub 才会出现在 `System32`。
如果同时还想跑 WSL2，还必须连 `VirtualMachinePlatform` 一起打开。

### 修复

不要继续反复尝试 `wsl --install`。
直接用 DISM 手动启用所需组件，然后重启机器。
在这次安装里，下面这组命令执行后，重启回来 `wsl.exe` 就出现了。

```powershell
DISM /Online /Enable-Feature /FeatureName:Microsoft-Windows-Subsystem-Linux /All /NoRestart
DISM /Online /Enable-Feature /FeatureName:VirtualMachinePlatform /All /NoRestart
shutdown /r /t 0
```

重启后先验证文件是否已经生成。
如果 `C:\Windows\System32\wsl.exe` 存在，再继续走后续发行版导入或内核安装步骤。
此时再执行 `wsl --help` 或 `wsl --status`，就不再是“无法识别命令”的级别错误了。

### 预防

在 Win10 上先确认版本，再决定是不是能用现代 one-liner。
不要把“命令不存在”误判成 PATH 问题，先看 `C:\Windows\System32\wsl.exe` 是否存在。
如果仓库里有 `bootstrap-wsl2.ps1`，优先使用脚本，让脚本自动分流 Win10 21H1 和较新版本的路径。
团队文档里如果写到 `wsl --install`，最好明确标注适用系统版本。
在新机器首装时，把“启用功能并重启”当成单独步骤，不要和发行版安装混成一坨执行。

## Issue 2：Ubuntu rootfs 下载链接返回 404

### 现象

使用 `curl` 或 `Invoke-WebRequest` 下载 Ubuntu Jammy 的 WSL rootfs 时，旧链接直接返回 `404 Not Found`。
失败的链接是：
`https://cloud-images.ubuntu.com/wsl/jammy/current/ubuntu-jammy-wsl-amd64-wsl.rootfs.tar.gz`
命令看起来没有任何语法问题，域名也通，唯独文件不存在。
这会让人误以为是网络代理有问题，或者 Canonical 站点临时故障。

### 根因

这不是网络波动，而是上游文件名在 2026 年初被 Canonical 改掉了。
旧名字里的 `wsl.rootfs` 已经退休，不再保留兼容文件。
新的命名改成了 `ubuntu22.04lts.rootfs`。
如果沿用旧博客、旧 gist、旧安装脚本里的 URL，就一定会拿到 404。
问题出在文件名变化，而不是 `/jammy/current/` 这个目录失效。

### 修复

先不要盲猜下载地址。
最稳妥的做法是先列一下 `/current/` 目录里到底有哪些文件，再选可用的那个。
这次安装最终使用的是下面这个新地址。

```text
https://cloud-images.ubuntu.com/wsl/jammy/current/ubuntu-jammy-wsl-amd64-ubuntu22.04lts.rootfs.tar.gz
```

如果你想在终端里先确认目录内容，可以这样做。

```bash
curl -L https://cloud-images.ubuntu.com/wsl/jammy/current/ | grep rootfs
```

看到 `ubuntu22.04lts.rootfs` 之后，再下载就不会再遇到 404。
后续导入 WSL 发行版时，直接使用新文件名即可。

### 预防

不要把历史教程里的 cloud-images 文件名当成永远稳定。
凡是指向 `/current/` 的下载链接，先列目录，再落地脚本。
如果仓库里有自动下载脚本，保持它跟着上游文件名更新。
做人工安装时，把“验证目录中当前可用文件名”作为固定动作，而不是失败后才去排查。
当下载返回 404 时，先检查文件名是否改版，别先怀疑代理或 TLS。

## Issue 3：WSL bash 一改 PATH 就报 `not a valid identifier`

### 现象

在 Windows 侧通过 `wsl -d Ubuntu-22.04 bash -c 'export PATH=/foo:$PATH; do_stuff'` 调脚本时，bash 立刻报错。
典型错误长这样：`bash: export: 'Files/Git/usr/bin/core_perl:...': not a valid identifier`。
如果脚本里还会循环 `$PATH`，通常会在第一步就炸开。
从错误字面上看，很像某个 Linux 路径变量被拼坏了。
但这次真正的污染源并不在 Linux，而是在 Windows 继承进来的 PATH。

### 根因

WSL 默认会把 Windows 的 PATH 注入到 Linux 会话里。
Windows PATH 里经常带有 `C:\Program Files\...` 这类包含空格的路径。
当你在 `bash -c` 这一层再次 `export PATH=...:$PATH` 时，那些未被正确 shell quoting 的内容会被 bash 按空格拆成多个参数。
结果就是 `Program`、`Files/Git/usr/bin/core_perl` 这类碎片被误当作独立标识符。
所以报错并不是 Linux PATH 本身非法，而是 Windows PATH 注入后在 bash 里被错误重新解释了。

### 修复

这类一行命令或脚本的第一行，不要基于继承下来的 PATH 做增量修改。
先把 PATH 重置成干净的 Linux 默认值，再继续执行后面的逻辑。
本次安装里可工作的最小写法如下。

```bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
do_stuff
```

如果是 `wsl ... bash -c '...'` 形式，也要把这两行塞在最前面。
一旦先清洗 PATH，后续的 `apt-get`、`curl`、`git`、`node` 等命令就能按 Linux 侧预期运行。
这比在错误 PATH 上做转义、替换、切分都更稳定。

### 预防

所有通过 `wsl bash -c` 执行的脚本，都把重置 PATH 当成第一行模板。
不要在脚本里直接拼接继承自 Windows 的 `$PATH`。
如果要新增自定义目录，也是在干净的 Linux PATH 基础上追加。
代码评审时，只要看到 `wsl ... bash -c`，就顺手检查有没有先清 PATH。
新增 bash 脚本时，最好把这个约定写进注释或项目模板里，避免后来的人重复踩坑。

## Issue 4：误用 bun 导致 pnpm 构建失败

### 现象

用户看到项目是 JavaScript/TypeScript，就直接跑了 `bun install`。
随后要么出现对 `package.json` 字段的报错，要么虽然命令勉强结束，但生成了不可用的 `node_modules`。
接着再执行 AO 的安装或构建命令，就会遇到更难读的连锁错误。
从表面看像是某个依赖包版本不兼容。
实际上问题在于一开始就选错了包管理器。

### 根因

AO 的 `package.json` 明确写了 `"packageManager": "pnpm@9.15.4"`。
同时项目使用的是 pnpm workspace 布局，也就是依赖解析和链接方式都按 pnpm 设计。
`bun install` 并不能正确理解 pnpm workspaces 的全部语义。
结果是依赖树、软链接结构、锁文件假设都会被破坏。
一旦 `node_modules` 已经被 bun 生成过，后续就算切回 pnpm，也可能继续受到脏状态影响。

### 修复

先把 bun 留下的安装结果清干净。
至少要删除 `node_modules`，如果生成了 bun 自己的锁文件，也一起清掉。
然后安装项目要求的 pnpm 版本，并重新执行依赖安装和构建。

```bash
rm -rf node_modules
npm i -g pnpm@9.15.4
pnpm install
pnpm build
```

如果你已经在错误依赖树上继续开发了一段时间，最好额外确认 workspace 下各子包都没有残留异常软链接。
本次安装里，删掉 bun 生成的产物后重新走 pnpm，构建立即恢复正常。

### 预防

每次接手一个新 Node 项目，先看 `package.json` 里的 `packageManager` 字段。
只要出现 `pnpm-workspace.yaml`，就默认按 pnpm 项目处理，不要自作主张换成 bun 或 npm。
团队 bootstrap 文档里，第一条就应该明确写出被支持的包管理器和版本。
CI 如果依赖 pnpm，开发机也必须保持同一套工具链，不要混用。
发现有人已经跑过错误的包管理器时，不要试图“在现有 node_modules 上补救”，直接重装更省时间。

## Issue 5：`runtime:process` 下 AO orchestrator 会立即死亡

### 现象

执行 `ao start` 时，终端先提示 `Orchestrator session created`，看起来一切正常。
但过一会儿再执行 `ao session ls -a`，会发现 orchestrator 会话状态已经变成 `[killed]`。
这时继续发送消息，例如 `ao send demo-orchestrator-1 "..."`，会收到 `Session does not exist`。
如果只看启动瞬间的成功提示，很容易误判成偶发崩溃或机器资源不足。
实际上它是稳定复现的生命周期配置错误。

### 根因

在 `agent-orchestrator.yaml` 里把 runtime 设成 `process` 时，AO 会把 orchestrator 当普通子进程拉起来。
问题是 Codex CLI 的非交互模式在完成一次响应后就会自然退出。
对子进程模型来说，这个退出就是“进程结束”，AO 只能把它标记成 killed。
而 orchestrator 的职责恰恰是跨多轮长期存活，所以 plain subprocess 模式与它的生命周期需求不匹配。
换句话说，不是 AO 不会拉起进程，而是 runtime 选型和会话模型冲突。

### 修复

把 `agent-orchestrator.yaml` 中的 runtime 改成 `tmux`。
tmux 会持续托管这个终端会话，不会因为单次响应结束就让整个 orchestrator 消失。
配置示例如下。

```yaml
runtime: tmux
```

修改后重新执行 `ao stop` 与 `ao start`，再用下面两条命令交叉确认。

```bash
ao session ls -a
tmux ls
```

本次安装里切到 `runtime: tmux` 后，orchestrator 能稳定跨多轮保活，`ao send` 也恢复正常。

### 预防

orchestrator 这类多轮代理默认用 `tmux`，不要图省事改成 `process`。
仓库模板里的 `templates/agent-orchestrator.yaml` 应该把 `runtime: tmux` 作为默认值。
如果你新建了自定义配置，改完 runtime 后第一时间跑 `ao session ls -a` 验证存活状态。
把“能启动”和“能跨多轮存活”分开验证，不要看到 created 就算通过。
需要排查异常退出时，先看 runtime 类型，再看模型或网络日志，顺序不要反了。

## Issue 6：Clash fake-ip 下 `git push` 卡死但 `curl` 正常

### 现象

在 WSL 里执行 `curl https://api.github.com`，不到 1 秒就能返回 `200 OK`。
但同一台机器上执行 `git push origin main` 却会无限挂起，没有报错，也没有进度。
`ps` 看得到 Git 进程还活着，可 CPU 占用接近 0%，明显是在等一个不会回来的 socket。
这会误导人以为 GitHub 端限流，或者 Git 本身坏了。
事实上网络栈只对短请求看起来正常，对长连接上传并不正常。

### 根因

Windows 侧的 Clash Verge 使用了 fake-ip 模式，也就是把命中的域名解析到 `198.18.0.0/15` 这段测试网段。
GitHub 域名在 Clash 视角下会得到 fake IP。
`curl` 的短 GET 请求恰好能被 Clash 的 TUN 抓走，看起来像是网络没问题。
但从 WSL 发起的 `git push` 是长时间存在的 HTTP/2 上传流，这条流在当前环境里并没有被 Clash 的 TUN 正确接管。
于是 WSL 实际上把数据发往了一个无人路由的 fake IP，表现出来就是“进程活着但永远没有响应”。

### 修复

这次修复分成 Windows 和 WSL 两段。
第一段是在 Windows 管理员 PowerShell 中，运行仓库里的自愈脚本，让它自动探测当前 WSL 面向 Windows 的主机 IP、修复 `portproxy`，并补齐防火墙规则。命令如下。

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\scripts\repair-wsl2-localhost-forwarding.ps1 -DistroName Ubuntu-22.04 -ListenPort 7897 -ConnectPort 7897
```

第二段是在 WSL 里先动态取当前 Windows host IP，再同时配置 Git 代理，并在实际 push 命令前显式导出环境变量。
单写 `git config` 对大推送并不总是可靠，这次真正稳定的是“配置加环境变量”一起用。

```bash
WSL_HOST_IP=$(ip route show default | awk '/default/ {print $3; exit}')
git config --global http.proxy "http://${WSL_HOST_IP}:7897"
git config --global https.proxy "http://${WSL_HOST_IP}:7897"
HTTPS_PROXY="http://${WSL_HOST_IP}:7897" git push -u origin main
```

修完之后，`git push` 不再挂死，而是能正常与 GitHub 完成认证和上传阶段交互。

### 预防

如果仓库中提供了 `scripts/repair-wsl2-localhost-forwarding.ps1`，优先跑脚本，不要手敲 `netsh interface portproxy`。
在 WSL 里看到目标地址解析到 `198.18.x.x` 时，先怀疑 fake-ip 路由，而不是先怀疑 GitHub。
测试代理时不要只跑 `curl`，还要跑一次真实的 `git ls-remote` 或小型 `git push`。
长期上传流量如果必须穿过 Windows 代理，最好显式指定 `HTTPS_PROXY`，不要完全依赖自动发现。
换网段、重装 WSL 或 WSL 网关变化后，直接重跑 `repair-wsl2-localhost-forwarding.ps1`，不要复用旧的静态 IP。

## Issue 7：代理修好后 `git push` 仍然返回 401

### 现象

在 Issue 6 的网络问题修完后，`git push` 已经不再挂死。
但请求一到 GitHub 就马上返回 `HTTP/2 401`，响应头里还有 `www-authenticate: Basic realm="GitHub"`。
这说明链路已经通了，问题从“网络不通”切换成了“认证失败”。
由于之前已经执行过 `gh auth login --with-token`，这一步最容易让人误以为是 token 权限不足。
其实这次失败不是 token 无效，而是 Git 根本没有用到它。

### 根因

`gh auth login --with-token` 只是在配置 GitHub CLI 自己的认证状态。
它不会自动把 Git 的 credential helper 改成 `gh`。
所以 `gh auth status` 看起来可能一切正常，但 `git push` 仍然会发匿名请求。
GitHub 收到匿名写入请求后，自然返回 401。
换句话说，`gh` 已登录并不等于 `git` 已有可用凭据。

### 修复

执行一次 `gh auth setup-git`，让 Git 把 `gh` 注册为凭据辅助程序。
这一步会写入 `~/.gitconfig`，之后 Git 就知道该去问 `gh` 拿 token 了。
本次安装里实际执行的是下面这组命令。

```bash
gh auth setup-git
gh auth status
git config --global --get-all credential.helper
```

只要 `credential.helper` 里已经挂上 `gh`，后续再跑 `git push`，就不会再走匿名认证。
如果你前面还配置了代理，保留代理设置即可，不需要回退。

### 预防

把 `gh auth setup-git` 当成 `gh auth login` 之后的必做步骤，而不是可选项。
新机器装完 gh 后，先验证 `git config --global --get-all credential.helper`，再开始 push。
Bootstrap 脚本里必须把登录和 setup-git 放在同一个流程里。
排查 401 时先区分“没走到 GitHub”和“走到了但没带凭据”，这两类问题不要混在一起。
如果 `gh auth status` 正常但 `git push` 401，第一时间检查 credential helper，而不是先重发 token。

## Issue 8：没有安装 `gh` 时 `ao spawn` 直接拒绝启动

### 现象

执行 `ao spawn 1` 时，命令不是卡住，也不是静默失败，而是直接报错退出。
提示内容很明确：`✗ GitHub CLI (gh) is not installed. Install it: https://cli.github.com/`。
对于第一次接触 AO 的人，这条信息容易被误解成“只是少了一个可选工具”。
但在当前工作流里，`gh` 不是锦上添花，而是硬依赖。
没有它，AO 根本拿不到 issue 元数据，也就无法生成 worker 的初始提示词。

### 根因

AO 的 `spawn` 和 `batch-spawn` 会主动去 GitHub 读取 issue 标题、正文和上下文。
这些数据不是从本地 Git 仓库里推出来的，而是通过 GitHub CLI 获取。
如果系统里没有 `gh`，AO 就缺少访问 GitHub issue 的入口。
因此它不能安全地构造 worker session 的首条任务说明。
这不是一个“体验降级”，而是启动条件不满足。

### 修复

按安装文档在 Linux 侧装好 GitHub CLI，然后完成认证。
如果使用 apt 安装，最短路径可以是下面这样。

```bash
sudo apt-get update
sudo apt-get install -y gh
gh auth login
```

装完后先执行 `gh --version` 和 `gh auth status`，再重新跑 `ao spawn 1`。
本次安装里，`gh` 就绪后，spawn 立刻恢复可用。

### 预防

把 `gh` 视为 AO 的基础依赖，而不是“以后再装也行”的开发辅助工具。
如果仓库提供了 `bootstrap-ao.sh`，脚本里应默认安装 `gh`。
新环境首装时，先跑 `ao doctor` 或至少手动检查 `gh --version`。
任何依赖 issue 元数据的自动化流程，都应该在开头显式校验 `gh` 是否存在。
不要等到第一次 `ao spawn` 失败后才发现缺依赖，那时上下文切换成本已经高了。

## Issue 9：Codex 直连测试 `/responses` 返回 200 但没有输出内容

### 现象

为了验证 Codex 代理是否可用，手工执行了一个 `curl -X POST http://proxy:port/responses ...`。
HTTP 状态码返回 `200`，而且 JSON 里的 `status` 已经是 `completed`。
但是 `output` 数组却是空的，只剩一个像这样的结果：`{"status":"completed","output":[],"usage":{"output_tokens":7}}`。
这时最容易得出的错误结论是“模型明明生成了 7 个输出 token，但代理把正文吃掉了”。
如果继续按“代理丢包”方向排查，会白白浪费很多时间。

### 根因

这次现象来自代理的非流式响应行为，而不是模型真的没有生成内容。
非 streaming 模式返回的 JSON 只是一个初始响应外壳。
真正的内容会通过 Server-Sent Events 在流里陆续到达。
因此你会看到 `usage` 里已经统计了输出 token，但同步返回体的 `output` 仍然为空。
普通 `codex exec` 默认用的是流式模式，所以日常命令行使用不会暴露这个坑，只有手写 `curl` 时容易撞上。

### 修复

手测代理时明确要求流式返回。
最直接的做法是在请求体里加 `"stream": true`，或者在 `curl` 层使用 `-N` 并接受 `text/event-stream`。
下面是一个可工作的示例。

```bash
curl -N \
  -H "Content-Type: application/json" \
  -H "Accept: text/event-stream" \
  -d '{"model":"gpt-5.4","input":"hi","stream":true}' \
  http://proxy:port/responses
```

只要保持连接不断开，就能看到后续 SSE 事件把真正的输出内容送出来。
所以这类“200 但 output 为空”的结果，不要立刻判定成模型故障。

### 预防

凡是手工测试 Codex 代理，默认都加 `"stream": true`。
不要用一次非流式 `curl` 的空 `output` 去否定整个代理链路。
如果要做自动化健康检查，优先检查 SSE 流里是否有内容事件，而不是只看初始 JSON。
把“Codex CLI 正常”和“手工 curl 非流式表现正常”看成两件不同的事。
团队内部如果要写调试脚本，建议直接提供流式模板，避免后来者重复误判。

## Issue 10：Codex 提示 `bubblewrap on PATH not found`

### 现象

每次执行 `codex exec`，终端都会先打印一条 warning。
内容大意是：`warning: Codex could not find bubblewrap on PATH. Install bubblewrap with your OS package manager. ... Codex will use the vendored bubblewrap in the meantime.`。
看到这条消息时，很容易怀疑 Codex 的 sandbox 已经坏了，或者本次运行并不安全。
但这次安装里，命令本身是能继续工作的。
真正的问题不是“功能不可用”，而是“系统包缺失导致出现提示”。

### 根因

Codex 的沙箱能力依赖 bubblewrap。
在 Linux 上，它同时携带了一份 vendored bubblewrap 作为兜底。
因此系统 PATH 中没有 `bwrap` 时，Codex 仍然能回退到内置副本继续运行。
warning 的意思是“没有找到系统安装的 bubblewrap”，并不是“当前无法运行”。
所以这条提示是信息性告警，不是阻塞性故障。

### 修复

如果你只关心功能是否可用，可以直接忽略这条 warning。
如果你想把启动输出清爽一点，或者统一依赖来源，再安装系统包即可。
本次安装里可选的消音命令如下。

```bash
sudo apt-get install -y bubblewrap
```

安装完成后，再运行 `codex exec`，这条 warning 通常就不会再出现。
但即使不装，依靠 vendored bubblewrap 也能继续完成日常工作。

### 预防

把这条 warning 归类为“可选优化项”，不要把它和真正的启动失败混淆。
如果仓库的 `bootstrap-ao.sh` 提供可选依赖安装，可以把 bubblewrap 一并装上。
做环境巡检时，优先关注命令是否真正失败，而不是先被 cosmetic warning 带偏。
团队文档里应明确说明：有 vendored bubblewrap 时，这条提示本身不代表坏了。
只有当 sandbox 功能实际报错或命令被拒绝执行时，才需要把它升级为必须处理的问题。

## Issue 11：tmux 3.2a segfault 导致所有 codex TUI session 神秘死亡

### 现象

在 Ubuntu 22.04 WSL2 里，每次 `ao start` 或 `ao batch-spawn` 之后：

- orchestrator 或 worker session 被创建，`ao status` 一开始正常
- tmux 进程和 codex 进程都能用 `ps` 看到
- 过 17 秒到 60 秒不等，所有 codex 进程消失
- `ao session ls -a` 把对应 session 标记成 `[killed]` 或 `[exited]`
- 没有任何应用层错误信息，lifecycle-worker.log 干净，codex session log 里最后一条只是普通的 `reasoning` 或 `function_call_output`，然后就截断
- 反复 `ao stop && ao start` 无效，换 orchestrator 类型也无效
- 这不是一次性现象：单次会话里至少出现 7 次，每次都和前一次表现一致

多次错误的猜测都会把人带偏到配置层面（tmux 尺寸、codex alt screen、AGENTS.md、WSL 网络），但真正的线索藏在 `dmesg` 里。

### 根因

**Ubuntu 22.04 自带的 tmux 3.2a (`3.2a-4ubuntu0.2`) 有一个 NULL 指针 segfault bug**。只要在 detached 会话里运行 codex TUI 并让它调用 shell tool 处理一些文件操作，tmux server 就会在大约 17 秒后收到一个 SIGSEGV 并整体崩溃。一旦 tmux server 崩溃，它上面挂着的所有 pane（包括 codex TUI）都会被一起回收。

真正的证据只有一条：在 WSL 里运行 `dmesg`，会看到 tmux server 的 segfault 记录：

```
[  120.327861] tmux: server[232]: segfault at 0 ip 000055b4552b2d80 sp 00007ffc06584030 error 4 in tmux[55b455280000+97000]
[  209.926840] tmux: server[739]: segfault at 0 ip 0000556416bb0d80 sp 00007ffc4a88f230 error 4 in tmux[556416b7e000+97000]
```

两次 `ip` 地址都指向 tmux 二进制内部的同一个指令区域，偏移是 `mov [rax]` 指令，也就是经典的 NULL 解引用。

同一条 bug 在 tmux 3.3 之后的版本里已经修复。Ubuntu 22.04 的 `jammy-updates` 和 `jammy-backports` 都不提供更新的 tmux，所以 apt 这条路是死路，只能从源码构建，或用新系统版本。

### 修复

**从源码构建 tmux 3.5a 并替换系统二进制**：

```bash
sudo apt-get update
sudo apt-get install -y libevent-dev libncurses5-dev pkg-config automake autoconf bison

cd /tmp
curl -sSL -o tmux-3.5a.tar.gz https://github.com/tmux/tmux/releases/download/3.5a/tmux-3.5a.tar.gz
tar xf tmux-3.5a.tar.gz
cd tmux-3.5a
./configure --prefix=/usr/local
make -j"$(nproc)"
sudo make install

# 备份旧的，然后 symlink 替换
sudo mv /usr/bin/tmux /usr/bin/tmux.3.2a.backup
sudo ln -sf /usr/local/bin/tmux /usr/bin/tmux

tmux -V   # 必须显示 "tmux 3.5a"
```

执行完之后，所有已经死掉的 orchestrator 和 worker session 都要清理一次再重建：

```bash
cd /root/projects/<your-project>
ao stop 2>/dev/null
rm -rf /root/.worktrees/<project-slug>/*
git worktree prune
rm -f /root/.agent-orchestrator/*/lifecycle-worker.pid
ao start
```

然后再 `ao spawn` 或 `ao batch-spawn` 出来的 session 就会长时间稳定运行。

### 预防

1. `scripts/bootstrap-ao.sh` 应该在安装完 apt 的 tmux 之后，立刻执行上面的源码升级步骤，而不是依赖 apt 版本。
2. 任何 `ao doctor` 或启动脚本都应该在启动前检查 `tmux -V` 是否大于 3.3，不够就拒绝启动并提示升级。
3. 在 readme 里显式写明："Ubuntu 22.04 的 apt tmux 不可用"。
4. 任何 "session 无故 exit/killed" 的诊断流程，第一步都要先 `dmesg 2>&1 | grep -i "tmux\|segfault\|oom"`，不要先看应用层日志。

## Issue 12：ao session kill 不清 worktree，新 worker 因 Git checkout 冲突立刻 exit

### 现象

在解决 Issue 11 之前，我们曾经把 worker 的频繁死亡误判成"worker 完成任务后 exited"。但实际上 `ao session kill` 之后再尝试 `ao spawn <same-issue>` 会瞬间 exit，没有任何输出。用 `ao spawn --no-wait` 加 verbose 才捕获到真实错误：

```
✗ Failed to create or initialize session
✗ Failed to checkout branch "feat/issue-4" in worktree: Command failed: git checkout feat/issue-4
fatal: 'feat/issue-4' is already checked out at '/root/.worktrees/ao-kit/kit-7'
```

### 根因

这是 AO 的开放 issue [#1129 "ao stop doesn't kill child agent sessions spawned by orchestrator"](https://github.com/ComposioHQ/agent-orchestrator/issues/1129) 的变种。`ao session kill <name>` 虽然把 AO 数据库里的 session 记录删掉了，但：

- 不调用 `git worktree remove` 清理磁盘上的 worktree
- 不调用 `git branch -D` 删除对应的 feature 分支
- 不清理 `/root/.agent-orchestrator/<project>/sessions/<session>` 里的日志和状态

于是下一次尝试 `ao spawn` 到同一个 issue（分支自动派生自 issue 编号）时，Git 看到这个分支已经被一个 worktree 占用了，就拒绝再次 checkout，worker 立刻以错误退出。

这在一次尝试里可能只影响一个 session，但如果你连续 `ao session kill` 很多次再重试，磁盘上会留下多个"看得见但占坑"的 worktree，让后续 spawn 全部失败。

### 修复

清理前一次的 worktree，再让 Git 清理自己的记账：

```bash
cd /root/projects/<your-project>

# 1. 物理清理 worktree 目录（注意别在路径里犯变量为空的错）
rm -rf /root/.worktrees/<project-slug>/kit-*

# 2. 让 git 同步它的 worktree 索引
git worktree prune
git worktree list      # 应该只剩主 worktree

# 3. 删除残留的 feature 分支（可选但推荐）
git branch --list 'feat/*' | xargs -r git branch -D
```

完成之后再 `ao spawn` 或 `ao batch-spawn` 就不会再因为重复 checkout 失败。

如果冲突发生在 slot lifecycle 恢复阶段，处理方式要更保守一些。不要再手工执行“按模式删光 `kitN-orchestrator-*`”这类命令。优先在仓库根目录运行 helper，让它先检查 AO/tmux 里的健康 session，只清理确认陈旧的 orchestrator worktree，再做 `Git worktree prune`：

```bash
cd /root/projects/ao-conductor-kit

# 先看 helper 将要做什么
./tools/start-slot-lifecycle-workers.sh --dry-run

# 确认后再执行真实清理/恢复
./tools/start-slot-lifecycle-workers.sh
```

如果 helper 不可用，至少先验证目标 slot 的 orchestrator session 已经不健康，再只删那一个确定陈旧的目录，不要按通配符整片删除：

```bash
tmux list-sessions -F '#S' | grep 'kit1-orchestrator-1$'
rm -rf /root/.worktrees/ao-kit-slot-1/kit1-orchestrator-stale-<suffix>
git worktree prune
```

仓库里的 `tools/start-slot-lifecycle-workers.sh` 现在会在尝试恢复 slot lifecycle 之前先做这一步，并且把所有 `ao status` / `ao start` 调用固定绑定到仓库根的 `agent-orchestrator.yaml`。这样即使脚本从别的 cwd 运行，也不会误用错误配置；同时即使之前的 `ao session kill` 留下了占坑的 orchestrator worktree，slot 恢复也不会再因为 `already exists` / `already checked out` 直接失败。

### 预防

1. 不要连续 `ao session kill` 之后立即 `ao spawn` 同一个 issue，至少先跑一次上面的清理流程。
2. 在母盘里提供一个 `tools/prune-worktrees.sh` 脚本，把清理步骤固化下来。
3. 如果一个 session `exited` 但没有产出 PR，第一反应是"检查 worktree 是否冲突"，不要立刻怀疑 codex。
4. 长期方案是等 AO 上游把 #1129 修掉。这之前要一直自己维护清理脚本。

## Issue 14：AO web/API 假死，实为卡住的 `gh api graphql` 拖住 Next.js 服务端

### 现象

AO dashboard 或本地 API 明明还在监听 `http://localhost:3000`，但页面一直转圈，某些请求长时间不返回，`ao status` 看起来也像是"web 挂了"。这时最容易做错的一步，是直接把 `next-server` 或整个 Next.js 进程杀掉重启。

但这次故障里，Next.js 服务本身其实还活着。真正卡住的是它拉起的一个 `gh api graphql` 子进程。只要那个子进程不退出，表面上 AO 的 web/API 面就会一直像假死一样，让人误判成 next-server 坏了。

### 根因

AO 的某条 web/API 路径会调用 `gh api graphql`。当这个子进程卡死或永久阻塞时，相关的 Next.js server handler 也会一直挂住，表现上等同于 Node.js 事件循环被这条调用拖住。结果是：**AO web/API 表面不可用，但 next-server 进程本身未必已经损坏。**

所以这类故障的根因不是"Next.js 服务自己死了"，而是"一个卡住的 `gh api graphql` 子进程把服务端请求链路拖死了"。

### 修复

先确认 Next.js 服务进程还在，然后只处理卡住的 `gh api graphql`，不要先杀 next-server。

```bash
# 1. 先看 Next.js 服务是否仍然活着
ps -eo pid,etime,command | grep -E 'next-server|node .*next' | grep -v grep

# 2. 找出卡住的 gh api graphql 子进程
ps -eo pid,ppid,etime,stat,command | grep 'gh api graphql' | grep -v grep

# 3. 只杀掉那个长时间不退出的 gh 进程
kill -9 <stuck-gh-pid>

# 4. 验证 web/API 是否恢复，而 next-server PID 是否保持不变
curl -I http://localhost:3000
ps -eo pid,etime,command | grep -E 'next-server|node .*next' | grep -v grep
```

如果第 1 步里还能看到 Next.js 进程，就**不要**把它当成首要处置对象。正确顺序是：先清掉卡住的 `gh api graphql`，再回头验证 `http://localhost:3000` 是否恢复响应。本次故障里，这样处理后 AO web/API 就恢复了，不需要重启 Next.js 服务。

如果你同时看到多个 `gh api graphql`，优先处理那个 `etime` 已经明显异常、且与当前卡住请求对应的进程。不要无差别把所有 node/next 相关进程一起杀掉，否则会把原本健康的服务也打断。

### 预防

1. 看到 dashboard 或 API 卡住时，第一步先查 `gh api graphql`，不要条件反射先 `kill` Next.js。
2. 诊断时把"服务进程是否还活着"和"服务内部是否有阻塞子进程"分开看，不要把两者混成一个问题。
3. 运维值守时保留一条现成命令：`ps -eo pid,ppid,etime,stat,command | grep 'gh api graphql' | grep -v grep`，能比盲目重启更快定位真因。
4. 只有在确认 next-server 自己已经退出、崩溃，或杀掉卡住的 `gh api graphql` 后仍然完全无响应时，才继续排查 Next.js 本身。

## 误诊链路（历史记录）

Issue 11 的 tmux segfault 是整个安装过程最难排查的一个坑，最终耗掉了几个小时。以下是在确认真因之前，这次会话曾经认真尝试过、但最终证明并非根因的假设，按时间顺序记录，目的是让下一个遇到同类症状的人**不要重复走这些弯路**。

1. **假设："tmux 出现 `131072x1 screen size is bogus` 警告说明 tmux 分配了错误尺寸，导致 codex TUI 画面崩溃"。** 修复动作：写 `~/.tmux.conf` 加上 `set-option -g default-size 200x50`，同时在启动前 `export COLUMNS=200 LINES=50`。结果：session 存活时间从 5–15 秒延长到 17–40 秒左右，但依然会死。**结论**：symptom 被延后，根因没动。

2. **假设："codex TUI 的 alt screen 模式在 detached tmux 里不兼容"。** 修复动作：在 `/root/.codex/config.toml` 里加 `no_alt_screen = true`，并验证 `codex exec` 也走同一个配置路径。结果：`codex exec` 始终正常，TUI session 依然在同样时间点死。**结论**：alt screen 不是根因，但这条配置本身没坏处，可以保留。

3. **假设："项目根目录下的 `AGENTS.md` 有某段内容触发了 codex 的 startup skills 加载失败，类似 codex 上游 issue #16914"。** 修复动作：`git rm AGENTS.md`，commit，push 到 main，等新的 orchestrator worktree 自然拿到无 AGENTS.md 的版本。结果：新 session 同样死。**结论**：AGENTS.md 不参与根因。

4. **假设："WSL2 init 的 `StartHostListener:356: write failed 32`(EPIPE) 错误累积，导致 PTY 分配损坏"。** 修复动作：`wsl --shutdown` 然后重启整个 WSL 发行版，同时重建 `netsh portproxy`。结果：dmesg 里确实干净了几分钟，但新 tmux 启动后过一会还是会出现 tmux segfault（见 Issue 11 的真正证据）。**结论**：EPIPE 确实存在，但不是根因；它更像是下游症状。

5. **假设："workers 的 `exited` 状态意味着任务完成后正常退出"。** 这个误判让我们一度以为 worker 已经干完活，PR 只是被 `git push` 卡住没上来。真相：完全没有 PR，worktree 里也没有新文件。这条假设最大的代价是**把诊断方向从基础设施层拖回应用层**。**结论**：看到 `exited` 要先验证磁盘上的产出，不要默认它等于"完成"。

6. **假设："CEO 直接 batch-spawn 绕开 orchestrator 就能跑通"。** 结果：绕开 orchestrator 之后，worker 一样在 20 秒内死光。这一步反而证明了问题不在 orchestrator 层，而在更底层的 tmux。这是本次诊断的关键转折点。**结论**：当 worker 和 orchestrator 同时出问题时，**永远先查它们的共同依赖**（tmux / WSL / 内核）。

7. **Issue 12 的 worktree 冲突**。在真因被找到之前，worktree 冲突让一部分 session 快速 exit 出一个 Git 错误。我们把它误认成 Issue 11 的变种，花了一些时间在上面。最后证明它只是同时出现的另一个独立 bug，修掉之后 session 的存活时间指标并没有改善。**结论**：多 bug 共存时，要能把"每一条死因"逐项划勾。

最后定位到 tmux 3.2a segfault 的线索，是一次对 `dmesg` 的例行检查。**这个教训被提炼成 Issue 11 的预防条目**：任何"session 无故死"的诊断流程，第一步都必须先看 dmesg。

## 调试技巧

### 1. 先从 Codex 日志看请求到底走到哪一步

Codex CLI 本机日志可以先看 `/root/.codex/log/codex-tui.log`。
最省事的方式是边复现边跟日志。

```bash
tail -f /root/.codex/log/codex-tui.log
```

如果你想确认某次请求有没有真正打到 `/responses`，可以 grep 关键字。

```bash
grep -n "api.path=\"responses\"" /root/.codex/log/codex-tui.log | tail
grep -n "ToolCall" /root/.codex/log/codex-tui.log | tail
```

除了文本日志，Codex 还会把会话和状态数据放在 `/root/.codex/sessions/`、`/root/.codex/history.jsonl`、`/root/.codex/logs_2.sqlite` 这些位置。
遇到“CLI 有输出但代理表现异常”时，先看日志里是网络失败、认证失败，还是模型流事件没有回来。

### 2. 用 tmux 判断 orchestrator 是真活着还是只是在启动瞬间成功

只看 `ao start` 的一行成功提示不够。
要确认 orchestrator 真的还活着，最简单的组合是：

```bash
ao session ls -a
tmux ls
```

如果 `ao session ls -a` 里会话已经被标成 `[killed]`，同时 `tmux ls` 里也没有对应 session，问题通常就在 runtime 或启动命令。
如果 tmux session 还在，可以进一步 attach 进去看现场。

```bash
tmux attach -t <session-name>
```

排查结束后，用 `Ctrl-b d` 脱离，不要直接把整个 tmux 会话关掉。

### 3. 用 `ao status` 和 `ao session` 看全局状态，不要只看单个命令报错

AO 自带的状态视图比零散日志更适合先做全局判断。
常用入口如下。

```bash
ao status
ao session ls -a
ao doctor
```

`ao status` 适合看所有 session 的分支、活跃度、PR、CI 状态。
`ao session ls -a` 适合看 worker 和 orchestrator 的生死。
`ao doctor` 适合在你怀疑环境缺依赖、代理、终端 runtime 或 GitHub 集成时做一次体检。
先从全局状态确认故障范围，再决定是去看某个 worker 的日志、tmux pane，还是网络链路。

补一个容易误判的点：
如果 `ao status` 里出现 `(unknown)`，不要把它直接解读成 session 健康或故障。
它更像“需要继续核实”的提示，
必须再用 dashboard、session activity、PR/CI 状态，或 `ao session ls -a` / tmux 现场交叉确认。

### 4. GitHub 认证问题优先看 `/root/.config/gh/hosts.yml`

GitHub CLI 的认证落点在 `/root/.config/gh/hosts.yml`。
当你怀疑 `gh auth login` 已经做过，但 `gh auth status` 或 `git push` 仍然异常时，先确认这个文件是否存在。

```bash
ls -lah /root/.config/gh/hosts.yml
sed -n '1,80p' /root/.config/gh/hosts.yml
```

排查时只看 host、user、oauth_token 是否有条目即可，不要把 token 内容复制到聊天、工单或日志系统里。
如果文件存在但 Git 仍然 401，再回头检查是否漏了 `gh auth setup-git`。

### 5. 网络类故障不要只用 `curl`，要复现真实工作负载

这次安装已经证明：`curl` 通，不代表 `git push` 也通。
短请求和长连接上传经过代理、fake-ip、TUN、WSL 边界时，表现可能完全不同。
所以网络排查最好分三层做。

- 先用 `curl https://api.github.com` 验证最基本的出站连通性。
- 再用 `git ls-remote origin` 验证 Git 的 HTTP 路径。
- 最后用一次真实 `git push` 或最小可复现写入请求验证长连接上传。

必要时可以临时打开 Git 的详细日志。

```bash
GIT_TRACE_CURL=1 GIT_CURL_VERBOSE=1 git push
```

这样能更快看出请求到底是卡在 DNS、代理连接、TLS，还是卡在上传体发送阶段。

## 已知无害警告

下面这些告警在本次安装里都真实见过，但它们本身不代表安装失败。
遇到时先判断“功能是否真的不可用”，再决定要不要处理。

### 1. `bubblewrap on PATH not found`

这是 Issue 10 里的那条 warning。
它表示系统 PATH 里没有安装版 `bubblewrap`，但 Codex 仍会回退到自带的 vendored 版本。
如果 `codex exec` 能继续运行，这条告警就是 cosmetic warning。
想消音时再执行 `sudo apt-get install -y bubblewrap` 即可。

### 2. `xdg-open is not installed`

在 WSL 或纯终端环境里启动 AO dashboard 时，常见一类提示是本机没有 `xdg-open`，所以无法自动帮你弹浏览器。
这不影响 dashboard 本身启动，也不影响 orchestrator、worker 或 API 行为。
通常 AO 已经把本地访问地址打印出来了，直接复制那个 URL 到浏览器即可。
如果你希望以后自动打开，再按自己的桌面环境补装 `xdg-open`、`wslview` 或其他 URL opener。

### 3. 日志里的某些插件同步或远程缓存 warning

如果你在 `/root/.codex/log/codex-tui.log` 中看到与远程插件同步、featured plugin cache 相关的 warning，不要第一时间把它们和当前安装故障强行绑定。
这些 warning 经常只是说明某个可选插件市场能力没有完成预热。
只要当前工作流依赖的 `codex exec`、`ao start`、`ao spawn`、`gh auth` 等主路径正常，它们通常不是阻塞项。
处理顺序上，先解决真正挡路的网络、认证、runtime、依赖管理问题，再考虑清理这些外围噪声。
