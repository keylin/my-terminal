#!/usr/bin/env bash
set -euo pipefail

if [[ "$SHELL" == *"zsh"* ]]; then
    echo "✓ 默认 shell 已是 zsh"
    exit 0
fi

echo "设置 zsh 为默认 shell..."
ZSH_PATH="$(command -v zsh)"
if ! grep -q "$ZSH_PATH" /etc/shells 2>/dev/null; then
    echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
fi
chsh -s "$ZSH_PATH"
echo "✓ 默认 shell 已设为 zsh"
