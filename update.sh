#!/usr/bin/env bash
# my-terminal: 一键更新并应用配置
# Usage: ./update.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
info()  { printf "${BLUE}[INFO]${NC}  %s\n" "$*"; }
ok()    { printf "${GREEN}[OK]${NC}    %s\n" "$*"; }
fail()  { printf "${RED}[FAIL]${NC}  %s\n" "$*"; exit 1; }

command -v chezmoi &>/dev/null || fail "chezmoi 未安装，请先运行 install.sh"

info "拉取最新配置..."
git -C "$SCRIPT_DIR" pull --rebase

info "应用配置..."
chezmoi --source="$SCRIPT_DIR" apply --force --no-pager -v
ok "配置已更新！"

exec zsh
