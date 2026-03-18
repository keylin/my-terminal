#!/usr/bin/env bash
# Rime (鼠须管) 一键安装：rime-ice 词库 + 个人定制
# Usage: ./rime-install.sh
set -euo pipefail

# ─── Colors ──────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

info()  { printf "${BLUE}[INFO]${NC}  %s\n" "$*"; }
ok()    { printf "${GREEN}[OK]${NC}    %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
fail()  { printf "${RED}[FAIL]${NC}  %s\n" "$*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RIME_DIR="$HOME/Library/Rime"
RIME_ICE_REPO="https://github.com/iDvel/rime-ice.git"

# ─── Preflight Check ────────────────────────────────────
preflight_check() {
    info "开始环境预检..."
    echo ""
    local has_fail=false

    # 1. macOS only
    if [[ "$(uname -s)" != "Darwin" ]]; then
        fail "仅支持 macOS（鼠须管是 macOS 专属输入法）"
    fi
    ok "操作系统: macOS"

    # 2. Git
    if command -v git &>/dev/null; then
        ok "Git: 已安装 ($(git --version))"
    else
        fail "Git: 未安装（请先安装 Xcode CLT: xcode-select --install）"
    fi

    # 3. 网络连通
    if curl -fsS --connect-timeout 5 https://github.com > /dev/null 2>&1; then
        ok "网络连通: github.com 可达"
    else
        fail "网络连通: 无法访问 github.com"
        has_fail=true
    fi

    # 4. 鼠须管
    if [[ -d "/Library/Input Methods/Squirrel.app" ]]; then
        ok "鼠须管: 已安装"
    else
        fail "鼠须管: 未安装（请先安装: brew install --cask squirrel）"
        has_fail=true
    fi

    echo ""
    if [[ "$has_fail" == true ]]; then
        fail "预检发现问题，请修复后重试"
    else
        ok "所有预检通过！"
    fi
    echo ""
}

# ─── Backup ──────────────────────────────────────────────
backup_rime() {
    if [[ ! -d "$RIME_DIR" ]]; then
        ok "无需备份（$RIME_DIR 不存在）"
        return
    fi

    local backup_dir="${RIME_DIR}.bak.$(date +%Y%m%d_%H%M%S)"
    info "备份 $RIME_DIR → $backup_dir ..."
    cp -a "$RIME_DIR" "$backup_dir"
    ok "备份完成: $backup_dir"
}

# ─── Install rime-ice ────────────────────────────────────
install_rime_ice() {
    info "安装 rime-ice 词库..."

    if [[ -d "$RIME_DIR" ]]; then
        rm -rf "$RIME_DIR"
    fi

    git clone --depth 1 "$RIME_ICE_REPO" "$RIME_DIR"
    ok "rime-ice 安装完成"
}

# ─── Apply custom configs ───────────────────────────────
apply_custom() {
    info "应用个人定制配置..."

    local custom_dir="$SCRIPT_DIR/rime"
    if [[ ! -d "$custom_dir" ]]; then
        warn "未找到 rime/ 目录，跳过自定义配置"
        return
    fi

    local count=0
    for f in "$custom_dir"/*.custom.yaml; do
        [[ -f "$f" ]] || continue
        cp "$f" "$RIME_DIR/"
        ok "已覆盖: $(basename "$f")"
        ((count++))
    done

    if [[ $count -eq 0 ]]; then
        warn "rime/ 目录中未找到 .custom.yaml 文件"
    fi
}

# ─── Cleanup ─────────────────────────────────────────────
cleanup_rime() {
    # 删除 rime-ice clone 带来的不需要的文件
    rm -rf "$RIME_DIR/.git" "$RIME_DIR/.github" "$RIME_DIR/.gitignore"
    rm -f "$RIME_DIR/README.md" "$RIME_DIR/LICENSE"
    ok "已清理 rime-ice 仓库文件"
}

# ─── Main ────────────────────────────────────────────────
main() {
    echo ""
    printf "${BOLD}╔══════════════════════════════════════╗${NC}\n"
    printf "${BOLD}║   Rime (鼠须管) 一键安装             ║${NC}\n"
    printf "${BOLD}╚══════════════════════════════════════╝${NC}\n"
    echo ""

    preflight_check
    backup_rime
    install_rime_ice
    apply_custom
    cleanup_rime

    echo ""
    printf "${GREEN}${BOLD}✓ 安装完成！${NC}\n"
    echo ""
    info "请在系统中切换到鼠须管，然后点击菜单栏图标 → 重新部署"
    info "或按快捷键 Control+Option+\` 重新部署"
    echo ""
}

main "$@"
