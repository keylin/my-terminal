#!/usr/bin/env bash
# my-terminal: 应用本地配置变更
# 请先手动 git pull 更新仓库，再运行此脚本应用配置
# Usage:
#   ./update.sh          # 预览变更 + 确认后应用
#   ./update.sh -y       # 跳过确认，直接应用
#   ./update.sh --diff   # 仅预览差异，不应用
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

info()  { printf "${BLUE}[INFO]${NC}  %s\n" "$*"; }
ok()    { printf "${GREEN}[OK]${NC}    %s\n" "$*"; }
fail()  { printf "${RED}[FAIL]${NC}  %s\n" "$*"; }

AUTO_YES=false
DIFF_ONLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes)   AUTO_YES=true; shift ;;
        --diff)     DIFF_ONLY=true; shift ;;
        -h|--help)
            echo "Usage: update.sh [-y|--yes] [--diff] [-h|--help]"
            echo "  -y, --yes   跳过确认，直接应用"
            echo "  --diff      仅预览差异，不应用"
            echo "  -h, --help  显示帮助"
            exit 0
            ;;
        *) fail "未知参数: $1"; exit 1 ;;
    esac
done

# ─── Check chezmoi ───────────────────────────────────────
if ! command -v chezmoi &>/dev/null; then
    fail "chezmoi 未安装，请先运行 install.sh"
    exit 1
fi

if ! chezmoi source-path &>/dev/null; then
    fail "chezmoi 未初始化，请先运行 install.sh"
    exit 1
fi

# ─── Diff ────────────────────────────────────────────────
DIFF_OUTPUT=$(chezmoi diff 2>/dev/null || true)

if [[ -z "$DIFF_OUTPUT" ]]; then
    ok "无变更，配置已是最新"
    exit 0
fi

echo ""
info "变更预览:"
echo "─────────────────────────────────────"
echo "$DIFF_OUTPUT"
echo "─────────────────────────────────────"

CHANGED_FILES=$(echo "$DIFF_OUTPUT" | grep -E '^diff --git' | sed 's|diff --git a/||;s| b/.*||' | sort -u || true)
if [[ -n "$CHANGED_FILES" ]]; then
    echo ""
    info "将变更的文件:"
    echo "$CHANGED_FILES" | while read -r f; do
        printf "  ${YELLOW}→${NC} %s\n" "$f"
    done
fi

if [[ "$DIFF_ONLY" == true ]]; then
    echo ""
    info "仅预览模式，未应用任何变更"
    exit 0
fi

# ─── Apply ───────────────────────────────────────────────
if [[ "$AUTO_YES" == false ]]; then
    echo ""
    read -rp "$(printf "${BOLD}应用以上变更？(y/N) ${NC}")" choice
    [[ "$choice" =~ ^[Yy]$ ]] || { info "已取消"; exit 0; }
fi

echo ""
info "应用配置..."
chezmoi apply -v
ok "配置已更新！"

echo ""
info "重载 zsh 以生效..."
exec zsh
