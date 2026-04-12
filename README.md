# AO Conductor Kit — 母盘

> **目标**：让任何一台 Windows 10+ 电脑都能在 1 小时内从零搭起"Claude 总经理 + Codex 员工并行干活"的完整流水线。
>
> **版本**：0.1.0（初版）
> **创建日期**：2026-04-11
> **作者**：hahyihao（使用 AO 自编排 6 路并行 Codex worker 写成）
> **许可**：MIT

---

## 这是什么

这个目录是一个**可移植初始化套件**，包含：

1. **文档**：安装流程、工作流原则、故障排查
2. **脚本**：Windows 和 WSL 两端的一键安装脚本
3. **模板**：新项目即开即用的 `agent-orchestrator.yaml` 和 `CLAUDE.md`
4. **技能**：让 Claude Code 自动变身"总经理"的 skill 源文件
5. **CI 配置**：企业级 GitHub Actions workflows（super-linter / CodeQL / gitleaks / dependency-review）
6. **Brief**：本次 6 路并行派活时用的任务说明书，可作为新任务的写作参考

**核心理念**：Claude（总经理）只编排和审核，不直接动手写代码；所有实际工作派给 Codex（员工）并行执行；GitHub Actions 和 AO 的 reaction engine 负责自动闭环质量检查。

---

## 快速开始

### 场景 A：新电脑从零搭

```powershell
# 1. 把整个 agent-orchestrator/ 目录拷到新电脑
#    假设放在 D:\脚本程序\agent-orchestrator\

# 2. 管理员 PowerShell
cd D:\脚本程序\agent-orchestrator
.\scripts\bootstrap-wsl2.ps1

# 3. 按提示重启电脑

# 4. 重启后再跑一次（会继续到下载 Ubuntu + import）
.\scripts\bootstrap-wsl2.ps1
```

然后 WSL 里：

```bash
# 5. 安装 AO 工具链
wsl -d Ubuntu-22.04 bash /mnt/d/脚本程序/agent-orchestrator/scripts/bootstrap-ao.sh

# 6. 按 INSTALL.md 的 Phase 4-8 配 codex / 代理 / gh auth
```

详细步骤见 **[INSTALL.md](INSTALL.md)**。

### 场景 B：为现有项目启用 AO

```bash
# WSL 里
cd /root/projects/your-project

# 1. 复制配置模板
cp /mnt/d/脚本程序/agent-orchestrator/templates/agent-orchestrator.yaml .
# 编辑 repo / path / branch 字段

# 2. 复制项目级 Claude 上下文
cp /mnt/d/脚本程序/agent-orchestrator/templates/project-CLAUDE.md ./CLAUDE.md
# 按你项目实际情况填

# 3. （可选）拷贝 CI workflows
cp -r /mnt/d/脚本程序/agent-orchestrator/.github .

# 4. 启动
ao start
```

### 场景 C：激活 Claude 总经理技能

```bash
# WSL 或 Git Bash
mkdir -p ~/.claude/skills/ao-conductor/references
cp /mnt/d/脚本程序/agent-orchestrator/skills/ao-conductor.md \
   ~/.claude/skills/ao-conductor/SKILL.md
cp /mnt/d/脚本程序/agent-orchestrator/skills/references/silent-failure-detection.md \
   ~/.claude/skills/ao-conductor/references/silent-failure-detection.md
```

之后任何 Claude Code 会话里，当你说"派活"、"并行开发"、"ao batch"等关键词，Claude 会自动切换到总经理模式。

---

## 目录结构

```
agent-orchestrator/
│
├── README.md                       ← 你在这里
├── INSTALL.md                      ← 总安装文档（8 阶段）
├── FLOW.md                         ← CEO→PM→Worker 原则 + SOP
├── TROUBLESHOOTING.md              ← 10 个真实踩坑清单
│
├── scripts/
│   ├── bootstrap-wsl2.ps1          ← Windows 端 WSL2 一键装
│   └── bootstrap-ao.sh             ← WSL 内 AO 工具链一键装
│
├── skills/
│   ├── ao-conductor.md             ← Claude 总经理技能源（拷到 ~/.claude/skills/ao-conductor/SKILL.md）
│   └── references/
│       └── silent-failure-detection.md
│                                  ← state-check protocol，安装时与 SKILL.md 一起分发
│
├── templates/
│   ├── agent-orchestrator.yaml     ← 新项目 AO 配置模板
│   └── project-CLAUDE.md           ← 新项目 Claude 上下文模板
│
├── .github/
│   ├── dependabot.yml              ← 每周自动升级 GitHub Actions
│   └── workflows/
│       ├── super-linter.yml        ← 50+ 语言 lint
│       ├── codeql.yml              ← 语义级代码扫描
│       ├── gitleaks.yml            ← 秘密泄漏扫描
│       └── dependency-review.yml   ← 依赖漏洞审查
│
├── .gitleaks.toml                  ← 白名单（忽略文档占位符）
│
├── briefs/                         ← 本次派活的 6 份任务说明书
│   ├── issue-bootstrap-wsl2.md
│   ├── issue-bootstrap-ao.md
│   ├── issue-install-md.md
│   ├── issue-flow-md.md
│   ├── issue-troubleshooting-md.md
│   └── issue-skill-md.md
│
└── ci-staging/                     ← 中间工件 + 辅助脚本
    ├── build-mother.sh             ← 从 PR 提取文件到母盘
    ├── review-prs.sh               ← 批量看 PR 质量
    └── *.yml / *.toml              ← CI workflow 源（已 cp 到 .github/）
```

---

## 核心文档索引

| 你想做什么                 | 看哪个文档                                                             |
| -------------------------- | ---------------------------------------------------------------------- |
| 从零装一遍                 | [INSTALL.md](INSTALL.md)                                               |
| 理解 Claude/Codex 分工逻辑 | [FLOW.md](FLOW.md)                                                     |
| 遇到报错                   | [TROUBLESHOOTING.md](TROUBLESHOOTING.md)                               |
| 让 Claude 自动变总经理     | [skills/ao-conductor.md](skills/ao-conductor.md)                       |
| 写新任务的 brief           | [briefs/](briefs/) 目录里任选一份参考                                  |
| 新项目 AO 配置             | [templates/agent-orchestrator.yaml](templates/agent-orchestrator.yaml) |

---

## 产出说明：这份母盘是怎么生成的

这个 kit 本身**就是用 AO 自己写出来的**——除了 `README.md` 和 `templates/` 两个文件，其它所有文档和脚本都由 6 路并行的 Codex worker 写成，作为 AO 能力的一次自证。

完整过程（2026-04-11 会话）：

1. 用户提出"把今天的流程整理成可移植 init kit"
2. 作为 CEO 的 Claude 把需求拆成 6 个独立子任务
3. 为每个子任务写 brief（存于 `briefs/`）
4. 创建 6 个 GitHub issue（`#9`-`#14`，在 repo `hahyihao/ao-test`）
5. `ao batch-spawn 9 10 11 12 13 14` 派 6 路并行 worker
6. 每个 worker 在独立 Git worktree 里用 Codex (gpt-5.4) 写文件
7. 每个 worker commit + push + 自动开 PR
8. CEO 把 6 个 PR 的文件提取到母盘（`ci-staging/build-mother.sh`）
9. CEO 补上 `README.md`（本文件）和 `templates/`

**总产出**：2,543 行，6 个文件，6 路并行，~8 分钟完成。

---

## 下一步

- **想跑通第一个任务**：从 [INSTALL.md](INSTALL.md) 的 Phase 0 开始
- **想理解这个工作流为什么值得**：先读 [FLOW.md](FLOW.md)
- **想知道能不能把我现有的项目接进去**：看 [场景 B](#场景-b为现有项目启用-ao)
- **装到一半卡住了**：查 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

---

## 反馈和迭代

这个 kit 是活的：每次跑完新任务踩的坑、写的 brief、优化的流程，都可以沉淀回这里。建议的迭代路径：

1. 每遇到一个新坑 → 加到 `TROUBLESHOOTING.md`
2. 每写一份好的 brief → 保留到 `briefs/` 作为模板
3. 每发现新的最佳实践 → 更新 `FLOW.md` 对应章节
4. 每找到新的 CI 改进 → 加到 `.github/workflows/`

当母盘积累到一定程度，建议 `git init` 一份，push 到 GitHub 做版本控制，后续所有电脑直接 `git clone` 即可。
