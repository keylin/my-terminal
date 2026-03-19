# my-terminal

一键部署终端开发环境，基于 [chezmoi](https://chezmoi.io/) 管理 dotfiles，支持 macOS 和 Linux。

## 包含什么

| 组件 | 说明 |
|------|------|
| **Ghostty** | 终端模拟器，Catppuccin Mocha 主题，Quick Terminal 支持（仅 macOS） |
| **ZSH** | 默认 shell，zinit 插件管理，语法高亮 / 自动补全 / fzf-tab |
| **tmux** | 终端复用，TPM 插件管理，Catppuccin 主题 |
| **Starship** | 跨平台 prompt，精简格式 |
| **CLI 工具** | eza, bat, fd, ripgrep, fzf, zoxide, delta, jq, tldr |

## 快速开始

**远程一键安装（推荐）：**

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply keylin
```

**本地安装：**

```bash
git clone https://github.com/keylin/my-terminal.git
cd my-terminal
./terminal-install.sh
```

安装过程会自动：备份已有配置 → 安装 Homebrew（macOS）→ 安装 CLI 工具和字体 → 应用所有配置 → 设置 zsh 为默认 shell。

## 日常更新

```bash
cd my-terminal
./terminal-update.sh
```

或直接：

```bash
git pull && chezmoi apply -v
```

## 项目结构

```
.
├── terminal-install.sh          # 终端一键安装
├── terminal-update.sh          # 终端一键更新
├── rime-install.sh             # Rime 一键安装
├── rime-update.sh              # Rime 一键更新
├── rime-sync.sh                # Rime 词频同步
├── rime/                       # Rime 个人定制配置
│   ├── default.custom.yaml
│   ├── squirrel.custom.yaml
│   ├── rime_ice.custom.yaml
│   └── sync/                   # 词频同步数据（Rime 导出的纯文本）
├── .chezmoiroot                # chezmoi 源目录指向 home/
└── home/                       # chezmoi 源文件
    ├── .chezmoi.toml.tmpl      # chezmoi 配置（交互式填写 GitHub 用户名、代理端口）
    ├── .chezmoiexternal.toml   # 外部依赖（zinit、tpm）
    ├── .chezmoiignore          # 忽略规则
    ├── .chezmoiscripts/        # 自动化脚本（备份、Homebrew、包安装、默认 shell）
    ├── modify_dot_zshrc.tmpl   # ZSH 配置（managed block 模式，保留用户自定义）
    ├── dot_zprofile.tmpl       # 登录 shell 环境变量
    ├── dot_tmux.conf           # tmux 配置
    └── dot_config/
        ├── ghostty/config.tmpl # Ghostty 终端配置
        └── starship.toml       # Starship prompt 配置
```

## Rime (鼠须管)

基于 [rime-ice (雾凇拼音)](https://github.com/iDvel/rime-ice) 的个人输入法配置，仅支持 macOS。

**安装：**

```bash
./rime-install.sh
```

安装过程：预检环境 → 备份 `~/Library/Rime/` → clone rime-ice → 覆盖个人定制。

**更新：**

```bash
./rime-update.sh
```

更新过程：拉取最新配置 → 保留运行时文件 → 重装 rime-ice → 重新覆盖定制。

**个人定制文件（`rime/` 目录）：**

| 文件 | 说明 |
|------|------|
| `default.custom.yaml` | 只保留全拼方案、候选词数量 |
| `squirrel.custom.yaml` | 鼠须管外观（仿 macOS 原生、亮暗色自适应） |
| `rime_ice.custom.yaml` | 模糊音（前后鼻音） |

安装/更新后需**重新部署**：菜单栏鼠须管图标 → 重新部署，或 `Control+Option+`` `。

**词频同步：**

```bash
./rime-sync.sh
```

词频数据（输入习惯、自造词）通过 Rime 内置同步机制导出为纯文本，存入 `rime/sync/` 目录并 git 提交。新机器恢复流程：`./rime-install.sh` → 重新部署 → 菜单栏「同步用户数据」→ 自动导入历史词频。

## 个性化

- **`~/.zshrc.local`** — ZSH 个人配置，不受 chezmoi 管理
- **`~/.zprofile.local`** — 登录 shell 个人环境变量
- chezmoi 首次 init 时会交互式配置 GitHub 用户名和代理端口
