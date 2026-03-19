#!/usr/bin/env bash
# Rime (鼠须管) 一键更新：拉取最新配置 + 更新 rime-ice 词库
# Usage: ./rime-update.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RIME_DIR="$HOME/Library/Rime"
RIME_ICE_REPO="https://github.com/iDvel/rime-ice.git"

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
info()  { printf "${BLUE}[INFO]${NC}  %s\n" "$*"; }
ok()    { printf "${GREEN}[OK]${NC}    %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
fail()  { printf "${RED}[FAIL]${NC}  %s\n" "$*"; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || fail "仅支持 macOS"
[[ -d "$RIME_DIR" ]] || fail "$RIME_DIR 不存在，请先运行 ./rime-install.sh"

echo ""
printf "${BOLD}── Rime (鼠须管) 更新 ───────────────────${NC}\n"
echo ""

# ─── 1. 拉取仓库最新配置 ─────────────────────────────
info "拉取最新配置..."
git -C "$SCRIPT_DIR" pull --rebase
ok "配置已拉取"

# ─── 2. 更新 rime-ice 词库 ───────────────────────────
info "更新 rime-ice 词库..."

# 增量更新 rime-ice（保留 .git 以支持增量拉取）
if [[ -d "$RIME_DIR/.git" ]]; then
    git -C "$RIME_DIR" fetch --depth 1
    git -C "$RIME_DIR" reset --hard origin/main
    ok "rime-ice 词库已增量更新"
else
    # 首次安装或 .git 被清理，备份运行时文件后重新 clone
    PRESERVE_PATTERNS=("build" "*.userdb" "*.userdb.txt" "user.yaml" "installation.yaml" "*.custom.yaml")
    TMPDIR_PRESERVE="$(mktemp -d)"
    trap 'rm -rf "$TMPDIR_PRESERVE"' EXIT

    for pattern in "${PRESERVE_PATTERNS[@]}"; do
        # shellcheck disable=SC2086
        for item in "$RIME_DIR"/$pattern; do
            [[ -e "$item" ]] || continue
            cp -a "$item" "$TMPDIR_PRESERVE/"
        done
    done

    rm -rf "$RIME_DIR"
    git clone --depth 1 "$RIME_ICE_REPO" "$RIME_DIR"

    for item in "$TMPDIR_PRESERVE"/*; do
        [[ -e "$item" ]] || continue
        cp -a "$item" "$RIME_DIR/"
    done
    ok "rime-ice 词库已全量安装"
fi

# 清理仓库无用文件（保留 .git）
rm -rf "$RIME_DIR/.github"
rm -f "$RIME_DIR/.gitignore" "$RIME_DIR/README.md" "$RIME_DIR/LICENSE"

# ─── 3. 重新覆盖自定义配置 ──────────────────────────
info "应用个人定制配置..."
local_count=0
for f in "$SCRIPT_DIR/rime"/*.custom.yaml; do
    [[ -f "$f" ]] || continue
    cp "$f" "$RIME_DIR/"
    ok "已覆盖: $(basename "$f")"
    ((local_count++))
done

if [[ $local_count -eq 0 ]]; then
    warn "rime/ 目录中未找到 .custom.yaml 文件"
fi

# ─── 完成 ────────────────────────────────────────────
echo ""
# ─── 完成 ────────────────────────────────────────────
printf "${GREEN}${BOLD}✓ 更新完成${NC}\n"
warn "请手动部署：切换到鼠须管 → 右上角图标 → 重新部署"
echo ""
