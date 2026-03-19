#!/usr/bin/env bash
# 首次 apply 前：自动备份已有配置
set -euo pipefail

BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"
MANAGED_FILES=(
    "$HOME/.zshrc"
    "$HOME/.zprofile"
    "$HOME/.tmux.conf"
    "$HOME/.config/starship.toml"
    "$HOME/.config/ghostty/config"
)

# ─── 备份所有已有配置 ─────────────────────────────────────
has_backup=false
for f in "${MANAGED_FILES[@]}"; do
    if [[ -f "$f" && ! -L "$f" ]]; then
        if [[ "$has_backup" == false ]]; then
            mkdir -p "$BACKUP_DIR"
            echo "── 备份已有配置 → $BACKUP_DIR ──"
            has_backup=true
        fi
        rel="${f#$HOME/}"
        mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
        cp "$f" "$BACKUP_DIR/$rel"
        echo "  已备份: ~/$rel"
    fi
done

if [[ "$has_backup" == true ]]; then
    echo "✓ 原有配置已备份至 $BACKUP_DIR"
else
    echo "✓ 无需备份（未发现已有配置）"
fi
