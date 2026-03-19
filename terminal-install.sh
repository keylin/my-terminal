#!/usr/bin/env bash
# my-terminal: 一键部署终端环境（macOS / Linux 自适应）
# Usage:
#   远程: sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply keylin
#   本地: git clone <repo> && cd my-terminal && ./terminal-install.sh
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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_URL="https://github.com/keylin/my-terminal.git"

# ─── Detect Install Mode ──────────────────────────────
detect_install_mode() {
    if [[ -d "$SCRIPT_DIR/.git" ]]; then
        INSTALL_MODE="local"
        REPO_URL="$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null || echo "$REPO_URL")"
        ok "安装模式: 本地仓库 ($SCRIPT_DIR)"
    else
        INSTALL_MODE="remote"
        ok "安装模式: 远程拉取 ($REPO_URL)"
    fi
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
    avail_kb=$(df -k "$HOME" | awk 'NR==2 {print $4}')
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

    # 5. Git 检测
    if command -v git &>/dev/null; then
        ok "Git: 已安装 ($(git --version))"
    else
        if [[ "$OS" == "Darwin" ]]; then
            fail "Git: 未安装（请先安装 Xcode CLT: xcode-select --install）"
            has_fail=true
        else
            warn "Git: 未安装（安装阶段会自动安装）"
        fi
    fi

    # 6. 冲突检测
    local has_conflict=false
    if [[ -f "$HOME/.zshrc" ]]; then
        warn "已存在: ~/.zshrc（受管理部分会更新，个性化配置会保留，原文件将自动备份至 ~/.dotfiles_backup/）"
        has_conflict=true
    fi
    for f in "$HOME/.zprofile" "$HOME/.tmux.conf" "$HOME/.config/starship.toml" "$HOME/.config/ghostty/config"; do
        if [[ -f "$f" ]]; then
            warn "已存在: ${f}（会被覆盖，原文件将自动备份至 ~/.dotfiles_backup/）"
            has_conflict=true
        fi
    done
    if [[ "$has_conflict" == true ]]; then
        info "自定义配置可放入 ~/.zshrc.local 和 ~/.zprofile.local（不受 chezmoi 管理）"
    else
        ok "无配置文件冲突"
    fi

    # 7. 已有 chezmoi
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

# ─── Ensure chezmoi is installed ─────────────────────────
ensure_chezmoi() {
    if command -v chezmoi &>/dev/null; then
        ok "chezmoi 已安装"
        return
    fi
    info "安装 chezmoi..."
    if command -v brew &>/dev/null; then
        brew install chezmoi
    else
        local chezmoi_bin="$HOME/.local/bin"
        mkdir -p "$chezmoi_bin"
        local kernel arch_name
        kernel="$(uname -s | tr '[:upper:]' '[:lower:]')"
        case "$(uname -m)" in
            x86_64)  arch_name="amd64" ;;
            aarch64|arm64) arch_name="arm64" ;;
            *) arch_name="$(uname -m)" ;;
        esac
        local url="https://github.com/twpayne/chezmoi/releases/latest/download/chezmoi-${kernel}-${arch_name}"
        info "下载 chezmoi (${kernel}/${arch_name})..."
        curl --progress-bar -fSL "$url" -o "${chezmoi_bin}/chezmoi"
        chmod +x "${chezmoi_bin}/chezmoi"
        export PATH="${chezmoi_bin}:$PATH"
    fi
    ok "chezmoi 安装完成"
}

# ─── Collect user data ─────────────────────────────────
collect_user_data() {
    local config_file="$HOME/.config/chezmoi/chezmoi.toml"

    # 已有配置则跳过
    if [[ -f "$config_file" ]] && grep -q 'github_user' "$config_file" 2>/dev/null; then
        ok "chezmoi 配置已存在，跳过收集 ($config_file)"
        return
    fi

    info "收集配置信息..."

    # GitHub 用户名：自动检测，失败则提示输入
    local github_user=""
    if command -v gh &>/dev/null && gh auth status &>/dev/null; then
        github_user=$(gh api user --jq .login 2>/dev/null || true)
    fi
    if [[ -z "$github_user" ]]; then
        github_user=$(git config --global user.name 2>/dev/null || true)
    fi
    if [[ -z "$github_user" ]]; then
        read -rp "GitHub 用户名: " github_user
    else
        ok "GitHub 用户名: $github_user"
    fi

    # 代理端口
    local proxy_port=""
    read -rp "代理端口 (如 1080，留空跳过): " proxy_port

    # 写入 chezmoi 配置
    mkdir -p "$(dirname "$config_file")"
    cat > "$config_file" <<EOF
[data]
    github_user = "$github_user"
    proxy_port = "$proxy_port"
EOF
    ok "配置信息已保存"
}

# ─── Backup existing dotfiles ─────────────────────────────
backup_dotfiles() {
    # Files managed by chezmoi (excluding .zshrc which uses modify_ strategy)
    local files=(
        "$HOME/.zshrc"
        "$HOME/.zprofile"
        "$HOME/.tmux.conf"
        "$HOME/.config/starship.toml"
        "$HOME/.config/ghostty/config"
    )

    local need_backup=false
    for f in "${files[@]}"; do
        if [[ -f "$f" ]]; then
            need_backup=true
            break
        fi
    done

    if [[ "$need_backup" == false ]]; then
        ok "无需备份（未发现已有配置文件）"
        return
    fi

    local backup_dir="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    info "备份已有配置文件到 $backup_dir ..."

    for f in "${files[@]}"; do
        if [[ -f "$f" ]]; then
            local rel="${f#$HOME/}"
            mkdir -p "$backup_dir/$(dirname "$rel")"
            cp "$f" "$backup_dir/$rel"
            ok "已备份: $rel"
        fi
    done

    ok "备份完成: $backup_dir"
}

# ─── Init chezmoi & apply ───────────────────────────────
apply_dotfiles() {
    info "初始化 chezmoi 并应用配置..."
    if [[ "$INSTALL_MODE" == "local" ]]; then
        # 直接链接源目录并 apply，跳过 chezmoi init 的配置模板合并（会打开编辑器）
        local chezmoi_source="$HOME/.local/share/chezmoi"
        mkdir -p "$(dirname "$chezmoi_source")"
        rm -rf "$chezmoi_source"
        ln -s "$SCRIPT_DIR" "$chezmoi_source"
        chezmoi apply --force --no-pager -v
    else
        chezmoi init "$REPO_URL" --apply --force --no-pager -v
    fi
    ok "配置已应用！"
}

# ─── Main ────────────────────────────────────────────────
main() {
    echo ""
    printf "${BOLD}╔══════════════════════════════════════╗${NC}\n"
    printf "${BOLD}║   my-terminal 一键部署               ║${NC}\n"
    printf "${BOLD}╚══════════════════════════════════════╝${NC}\n"
    echo ""

    detect_install_mode
    preflight_check

    if [[ "$OS" == "Darwin" ]]; then
        install_xcode_clt
    else
        install_linux_prereqs
    fi

    ensure_chezmoi
    collect_user_data
    backup_dotfiles
    apply_dotfiles

    # chezmoi 的 run_once/run_onchange 脚本会自动完成:
    # - 安装 Homebrew
    # - 安装 CLI 工具和字体
    # - 设置默认 shell 为 zsh

    echo ""
    printf "${GREEN}${BOLD}✓ 部署完成！${NC}\n"
    echo ""
    info "重启终端或执行: exec zsh"
    info "日常更新: git pull && ./terminal-update.sh"
    echo ""
}

main "$@"
