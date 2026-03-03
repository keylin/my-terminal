#!/usr/bin/env bash
# my-terminal: 一键更新配置
# 拉取最新 → 应用变更 → 重载 shell
# Usage:
#   ./update.sh          # 拉取 + 预览 + 确认后应用
#   ./update.sh -y       # 跳过确认，直接应用
#   ./update.sh --diff   # 仅预览差异，不应用
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

info()  { printf "${BLUE}[INFO]${NC}  %s\n" "$*"; }
ok()    { printf "${GREEN}[OK]${NC}    %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
fail()  { printf "${RED}[FAIL]${NC}  %s\n" "$*"; }

AUTO_YES=false
DIFF_ONLY=false

# ─── Parse args ──────────────────────────────────────────
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

# ─── Pull latest ─────────────────────────────────────────
# chezmoi source-path 返回的是 .chezmoiroot 指定的子目录,
# 需要找到其上层的 git 仓库根目录来执行 pull
SOURCE_DIR="$(chezmoi source-path)"
REPO_DIR="$(git -C "$SOURCE_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$SOURCE_DIR")"

info "拉取远程最新配置..."
git -C "$REPO_DIR" pull --rebase 2>/dev/null || git -C "$REPO_DIR" pull
ok "拉取完成"

# ─── Show diff ───────────────────────────────────────────
DIFF_OUTPUT=$(chezmoi diff 2>/dev/null || true)

if [[ -z "$DIFF_OUTPUT" ]]; then
    echo ""
    ok "无变更，配置已是最新"
    exit 0
fi

echo ""
info "变更预览:"
echo "─────────────────────────────────────"
echo "$DIFF_OUTPUT"
echo "─────────────────────────────────────"

# 变更文件摘要
CHANGED_FILES=$(echo "$DIFF_OUTPUT" | grep -E '^diff --git' | sed 's|diff --git a/||;s| b/.*||' | sort -u || true)
if [[ -n "$CHANGED_FILES" ]]; then
    echo ""
    info "将变更的文件:"
    echo "$CHANGED_FILES" | while read -r f; do
        printf "  ${YELLOW}→${NC} %s\n" "$f"
    done
fi

# ─── Diff-only mode ─────────────────────────────────────
if [[ "$DIFF_ONLY" == true ]]; then
    echo ""
    info "仅预览模式，未应用任何变更"
    exit 0
fi

# ─── Confirm & apply ────────────────────────────────────
if [[ "$AUTO_YES" == false ]]; then
    echo ""
    read -rp "$(printf "${BOLD}应用以上变更？(y/N) ${NC}")" choice
    [[ "$choice" =~ ^[Yy]$ ]] || { info "已取消"; exit 0; }
fi

echo ""
info "应用配置..."
chezmoi apply -v
ok "配置已更新！"

# ─── Reload shell ────────────────────────────────────────
echo ""
info "重载 zsh 以生效..."
exec zsh
