#!/usr/bin/env bash
# my-terminal: 一键更新配置 + 升级软件
# Usage: ./update.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"
UPDATE_RECORD="$HOME/.local/state/my-terminal/last_update"
UPGRADE_INTERVAL=2592000  # 30 days in seconds

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
info()  { printf "${BLUE}[INFO]${NC}  %s\n" "$*"; }
ok()    { printf "${GREEN}[OK]${NC}    %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
fail()  { printf "${RED}[FAIL]${NC}  %s\n" "$*"; exit 1; }

need_package_upgrade() {
    if [[ ! -f "$UPDATE_RECORD" ]]; then
        mkdir -p "$(dirname "$UPDATE_RECORD")"
        return 0
    fi
    local last now elapsed remaining
    last=$(<"$UPDATE_RECORD")
    now=$(date +%s)
    elapsed=$((now - last))
    if (( elapsed >= UPGRADE_INTERVAL )); then
        return 0
    fi
    remaining=$(( (UPGRADE_INTERVAL - elapsed) / 86400 ))
    info "距离上次软件升级不足 30 天，跳过（约 ${remaining} 天后再次升级）"
    return 1
}

command -v chezmoi &>/dev/null || fail "chezmoi 未安装，请先运行 ./install.sh"

echo ""
printf "${BOLD}── my-terminal 更新 ──────────────────────${NC}\n"
echo ""

# ─── 1. 拉取最新配置 ─────────────────────────────────
info "拉取最新配置..."
git -C "$SCRIPT_DIR" pull --rebase
ok "配置已拉取"

# ─── 2. 升级终端相关软件包 ────────────────────────────
if need_package_upgrade; then
    if [[ "$OS" == "Darwin" ]]; then
        if command -v brew &>/dev/null; then
            PACKAGES=(starship zsh fzf zoxide eza bat fd ripgrep delta jq tldr tmux chezmoi)
            CASKS=(ghostty)

            info "更新 Homebrew..."
            brew update

            info "升级终端工具..."
            for pkg in "${PACKAGES[@]}"; do
                brew upgrade "$pkg" 2>/dev/null || true
            done
            ok "终端工具升级完成"

            info "升级 cask 应用..."
            for cask in "${CASKS[@]}"; do
                brew upgrade --cask "$cask" 2>/dev/null || true
            done
            ok "cask 应用升级完成"

            info "清理旧版本缓存..."
            brew cleanup --prune=7 2>/dev/null || true
            ok "Homebrew 清理完成"
        else
            warn "Homebrew 未安装，跳过软件包升级"
        fi
    elif [[ "$OS" == "Linux" ]]; then
        PACKAGES=(zsh fzf bat fd-find ripgrep jq tldr tmux starship zoxide eza git-delta)

        if command -v apt-get &>/dev/null; then
            info "更新 apt 索引..."
            sudo apt-get update -qq
            info "升级终端工具..."
            for pkg in "${PACKAGES[@]}"; do
                sudo apt-get install --only-upgrade -y -qq "$pkg" 2>/dev/null || true
            done
            ok "终端工具升级完成"
        elif command -v dnf &>/dev/null; then
            info "升级终端工具..."
            for pkg in "${PACKAGES[@]}"; do
                sudo dnf upgrade -y -q "$pkg" 2>/dev/null || true
            done
            ok "终端工具升级完成"
        elif command -v pacman &>/dev/null; then
            info "升级终端工具..."
            sudo pacman -S --noconfirm --needed "${PACKAGES[@]}" 2>/dev/null || true
            ok "终端工具升级完成"
        else
            warn "未找到支持的包管理器，跳过软件包升级"
        fi
    fi
    date +%s > "$UPDATE_RECORD"
fi

# ─── 3. 应用 chezmoi 配置并刷新外部依赖（zinit、tpm）──
info "应用配置并刷新外部依赖..."
chezmoi --source="$SCRIPT_DIR" apply --force --no-pager --refresh-externals -v
ok "配置及外部依赖已更新"

# ─── 4. 更新 tmux 插件 ──────────────────────────────
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [[ -x "$TPM_DIR/bin/update_plugins" ]]; then
    info "更新 tmux 插件..."
    "$TPM_DIR/bin/update_plugins" all 2>&1 || warn "tmux 插件更新失败"
    ok "tmux 插件已更新"
else
    warn "tpm 未安装，跳过 tmux 插件更新"
fi

# ─── 5. 重载配置 ─────────────────────────────────────
if command -v tmux &>/dev/null && tmux list-sessions &>/dev/null 2>&1; then
    info "重载 tmux 配置..."
    tmux source-file ~/.tmux.conf 2>/dev/null && ok "tmux 配置已重载" || warn "tmux 配置重载失败"
fi

if [[ "$OS" == "Darwin" && -f "$HOME/.config/ghostty/config" ]]; then
    info "触发 Ghostty 配置重载..."
    touch "$HOME/.config/ghostty/config" && ok "Ghostty 配置已触发重载" || warn "Ghostty 配置重载失败"
fi

# ─── 完成 ────────────────────────────────────────────
echo ""
printf "${GREEN}${BOLD}✓ 更新完成！${NC}\n"
echo ""

exec zsh
