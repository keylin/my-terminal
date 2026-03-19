#!/usr/bin/env bash
# Rime 词频数据同步：导出 → git commit → push
# Usage: ./rime-sync.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_DIR="$SCRIPT_DIR/rime/sync"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

info()  { printf "${BLUE}[INFO]${NC}  %s\n" "$*"; }
ok()    { printf "${GREEN}[OK]${NC}    %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
fail()  { printf "${RED}[FAIL]${NC}  %s\n" "$*"; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || fail "仅支持 macOS"

echo ""
printf "${BOLD}── Rime 词频数据同步 ───────────────────${NC}\n"
echo ""

# ─── 1. 检查 sync_dir 配置 ────────────────────────────
INSTALL_YAML="$HOME/Library/Rime/installation.yaml"
[[ -f "$INSTALL_YAML" ]] || fail "installation.yaml 不存在，请先运行 ./rime-install.sh"

if ! grep -q "sync_dir:" "$INSTALL_YAML" 2>/dev/null; then
    fail "sync_dir 未配置，请先运行 ./rime-install.sh"
fi

# ─── 2. 提示用户触发 Rime 同步 ────────────────────────
info "请先点击菜单栏鼠须管图标 → 同步用户数据"
echo ""
read -rp "已完成同步？(Y/n) " choice
[[ "${choice:-Y}" =~ ^[Yy]$ ]] || { info "已取消"; exit 0; }

# ─── 3. 检查同步数据 ──────────────────────────────────
if [[ ! -d "$SYNC_DIR" ]] || [[ -z "$(ls -A "$SYNC_DIR" 2>/dev/null)" ]]; then
    fail "同步目录为空: $SYNC_DIR"
fi

USERDB_COUNT=$(find "$SYNC_DIR" -name "*.userdb.txt" 2>/dev/null | wc -l | tr -d ' ')
ok "检测到 ${USERDB_COUNT} 个词频文件"

# ─── 4. Git commit & push ─────────────────────────────
info "提交词频数据..."
cd "$SCRIPT_DIR"
git add rime/sync/
if git diff --cached --quiet -- rime/sync/; then
    ok "词频数据无变更，无需提交"
else
    git commit -m "chore: sync rime user data $(date +%Y-%m-%d)"
    ok "已提交"

    if git remote get-url origin &>/dev/null; then
        info "推送到远程..."
        git push
        ok "已推送"
    else
        warn "未配置远程仓库，跳过推送"
    fi
fi

echo ""
printf "${GREEN}${BOLD}✓ 词频同步完成！${NC}\n"
echo ""
