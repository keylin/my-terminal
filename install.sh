#!/usr/bin/env bash
# my-terminal: 一键部署终端环境（macOS / Linux 自适应）
# Usage: curl -fsSL <raw-url>/install.sh | bash
#   or:  git clone <repo> && cd my-terminal && ./install.sh
set -euo pipefail

# ─── Colors ──────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

info()  { printf "${BLUE}[INFO]${NC}  %s\n" "$*"; }
ok()    { printf "${GREEN}[OK]${NC}    %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
fail()  { printf "${RED}[FAIL]${NC}  %s\n" "$*"; }

OS="$(uname -s)"
ARCH="$(uname -m)"

# ─── Detect Repo URL ──────────────────────────────────
detect_repo_url() {
    if ! REPO_URL="$(git remote get-url origin 2>/dev/null)"; then
        fail "无法检测 git remote URL"
        info "请确保在仓库目录中运行:"
        info "  git clone <repo> && cd my-terminal && ./install.sh"
        exit 1
    fi
    ok "仓库 URL: $REPO_URL"
}

# ─── Preflight Check ────────────────────────────────────
preflight_check() {
    info "开始环境预检..."
    echo ""
    local has_fail=false

    # 1. OS 检测
    if [[ "$OS" == "Darwin" ]]; then
        ok "操作系统: macOS"
    elif [[ "$OS" == "Linux" ]]; then
        ok "操作系统: Linux"
    else
        fail "不支持的操作系统: $OS（仅支持 macOS / Linux）"
        exit 1
    fi

    # 2. 架构检测
    ok "系统架构: $ARCH"

    # 3. 磁盘空间
    local avail_kb
    if [[ "$OS" == "Darwin" ]]; then
        avail_kb=$(df -k "$HOME" | awk 'NR==2 {print $4}')
    else
        avail_kb=$(df -k "$HOME" | awk 'NR==2 {print $4}')
    fi
    local avail_gb=$((avail_kb / 1048576))
    if [[ $avail_kb -ge 2097152 ]]; then
        ok "磁盘空间: ${avail_gb}GB 可用"
    else
        fail "磁盘空间不足: ${avail_gb}GB（至少需要 2GB）"
        has_fail=true
    fi

    # 4. 网络连通
    if curl -fsS --connect-timeout 5 https://github.com > /dev/null 2>&1; then
        ok "网络连通: github.com 可达"
    else
        fail "网络连通: 无法访问 github.com"
        has_fail=true
    fi

    # 5. Shell 检测
    if command -v zsh &>/dev/null; then
        ok "Zsh: 已安装 ($(zsh --version 2>/dev/null | head -1))"
    else
        if [[ "$OS" == "Linux" ]]; then
            warn "Zsh: 未安装（安装阶段会自动安装）"
        else
            fail "Zsh: 未安装"
            has_fail=true
        fi
    fi

    # 6. Git 检测
    if command -v git &>/dev/null; then
        ok "Git: 已安装 ($(git --version))"
    else
        if [[ "$OS" == "Linux" ]]; then
            warn "Git: 未安装（安装阶段会自动安装）"
        else
            fail "Git: 未安装（macOS 请先安装 Xcode CLT: xcode-select --install）"
            has_fail=true
        fi
    fi

    # 7. 冲突检测 - 已有配置文件
    local conflict_files=("$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.tmux.conf" "$HOME/.config/starship.toml" "$HOME/.config/ghostty/config")
    local has_conflict=false
    for f in "${conflict_files[@]}"; do
        if [[ -f "$f" ]]; then
            warn "已存在: $f（chezmoi apply 时会被覆盖）"
            has_conflict=true
        fi
    done
    if [[ "$has_conflict" == true ]]; then
        warn "建议先备份已有配置: cp ~/.zshrc ~/.zshrc.bak 等"
    else
        ok "无配置文件冲突"
    fi

    # 8. 已有 chezmoi
    if [[ -d "$HOME/.local/share/chezmoi" ]]; then
        warn "检测到已有 chezmoi 源目录 (~/.local/share/chezmoi)"
        warn "继续安装将重新初始化 chezmoi"
    else
        ok "chezmoi: 全新安装"
    fi

    # 汇总
    echo ""
    if [[ "$has_fail" == true ]]; then
        fail "预检发现问题，请修复后重试"
        read -rp "仍要继续安装吗？(y/N) " choice
        [[ "$choice" =~ ^[Yy]$ ]] || exit 1
    else
        ok "所有预检通过！"
    fi
    echo ""
}

# ─── macOS: Install Xcode CLT ───────────────────────────
install_xcode_clt() {
    if xcode-select -p &>/dev/null; then
        ok "Xcode CLT 已安装"
        return
    fi
    info "安装 Xcode Command Line Tools..."
    xcode-select --install 2>/dev/null || true
    # 等待用户在 GUI 对话框中确认安装
    until xcode-select -p &>/dev/null; do
        sleep 5
    done
    ok "Xcode CLT 安装完成"
}

# ─── Linux: Install prerequisites ───────────────────────
install_linux_prereqs() {
    info "安装 Linux 前置依赖..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y -qq build-essential curl git zsh
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y gcc gcc-c++ make curl git zsh
    elif command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm base-devel curl git zsh
    else
        fail "无法识别包管理器，请手动安装: build-essential curl git zsh"
        exit 1
    fi
    ok "Linux 前置依赖安装完成"
}

# ─── Install Homebrew ────────────────────────────────────
install_homebrew() {
    if command -v brew &>/dev/null; then
        ok "Homebrew 已安装"
        return
    fi
    info "安装 Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # 激活 brew（当前 session）
    if [[ "$OS" == "Darwin" ]]; then
        if [[ "$ARCH" == "arm64" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    else
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
    ok "Homebrew 安装完成"
}

# ─── Install chezmoi & apply ─────────────────────────────
install_chezmoi() {
    if command -v chezmoi &>/dev/null; then
        ok "chezmoi 已安装"
    else
        info "安装 chezmoi..."
        brew install chezmoi
        ok "chezmoi 安装完成"
    fi

    info "初始化 chezmoi 并应用配置..."
    chezmoi init "$REPO_URL" --apply -v
    ok "配置已应用！"
}

# ─── Set default shell to zsh ────────────────────────────
set_default_shell() {
    if [[ "$SHELL" == *"zsh"* ]]; then
        ok "默认 shell 已是 zsh"
        return
    fi
    info "设置 zsh 为默认 shell..."
    local zsh_path
    zsh_path="$(command -v zsh)"
    if ! grep -q "$zsh_path" /etc/shells 2>/dev/null; then
        echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
    fi
    chsh -s "$zsh_path"
    ok "默认 shell 已设为 zsh"
}

# ─── Main ────────────────────────────────────────────────
main() {
    echo ""
    printf "${BOLD}╔══════════════════════════════════════╗${NC}\n"
    printf "${BOLD}║   my-terminal 一键部署               ║${NC}\n"
    printf "${BOLD}╚══════════════════════════════════════╝${NC}\n"
    echo ""

    detect_repo_url
    preflight_check

    if [[ "$OS" == "Darwin" ]]; then
        install_xcode_clt
    else
        install_linux_prereqs
    fi

    install_homebrew
    install_chezmoi
    set_default_shell

    echo ""
    printf "${GREEN}${BOLD}✓ 部署完成！${NC}\n"
    echo ""
    info "重启终端或执行: exec zsh"
    info "日常同步配置: ./sync.sh"
    echo ""
}

main "$@"
