#!/usr/bin/env bash
# 首次 apply 前：自动备份已有配置 + 提取用户自定义到 .local 文件
set -euo pipefail

BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"
MANAGED_FILES=(
    "$HOME/.zshrc"
    "$HOME/.zprofile"
    "$HOME/.tmux.conf"
    "$HOME/.config/starship.toml"
    "$HOME/.config/ghostty/config"
)

# ─── Step 1: 备份所有已有配置 ─────────────────────────────
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

# ─── Step 2: 从旧 .zshrc 提取用户自定义 → ~/.zshrc.local ──
extract_zshrc_local() {
    local old_zshrc="$HOME/.zshrc"
    local local_file="$HOME/.zshrc.local"

    # 已有 .zshrc.local 或无旧 .zshrc，跳过
    [[ -f "$local_file" ]] && { echo "✓ ~/.zshrc.local 已存在，跳过提取"; return; }
    [[ -f "$old_zshrc" ]] || { return; }

    # 我们的模板已管理的内容（匹配到的行会被过滤掉）
    local managed_patterns=(
        # ── Plugin managers (zinit / oh-my-zsh / antigen) ──
        'ZINIT_HOME='
        'source.*zinit\.zsh'
        'zinit[[:space:]]+(light|load|ice|snippet|cdreplay)'
        'export[[:space:]]+ZSH=.*oh-my-zsh'
        'ZSH_THEME='
        'plugins=\('
        'source.*oh-my-zsh\.sh'
        'source.*antigen\.zsh'
        'antigen[[:space:]]+(bundle|theme|apply)'

        # ── Completions ──
        'autoload.*compinit'
        '^[[:space:]]*compinit'

        # ── History ──
        '^[[:space:]]*(export[[:space:]]+)?HISTSIZE='
        '^[[:space:]]*(export[[:space:]]+)?SAVEHIST='
        '^[[:space:]]*(export[[:space:]]+)?HISTFILE='
        'setopt.*(appendhistory|sharehistory|hist_ignore|hist_save)'

        # ── Completion styling ──
        "zstyle[[:space:]]+':(completion|fzf-tab):"

        # ── Aliases we manage ──
        "alias[[:space:]]+ls='eza"
        "alias[[:space:]]+ll='eza"
        "alias[[:space:]]+lt='eza"
        "alias[[:space:]]+cat='bat"
        "alias[[:space:]]+grep='rg'"
        "alias[[:space:]]+find='fd'"
        'alias[[:space:]]+proxys5='
        'alias[[:space:]]+unproxys5='
        'alias[[:space:]]+proxyhttp='
        'alias[[:space:]]+unproxyhttp='

        # ── PATH entries we manage ──
        'PATH=.*\.local/bin'
        'PATH=.*/opt/homebrew/opt/openjdk'
        'PATH=.*/usr/local/opt/openjdk'
        'PATH=.*\.antigravity'

        # ── Tool inits we manage ──
        'eval.*starship[[:space:]]+init'
        'eval.*fzf[[:space:]]+--zsh'
        'eval.*zoxide[[:space:]]+init'

        # ── Homebrew ──
        'eval.*brew[[:space:]]+shellenv'

        # ── Docker completions ──
        'fpath=.*\.docker/completions'

        # ── Self-reference ──
        'source.*\.zshrc\.local'
        '\[\[.*\.zshrc\.local'
    )

    # 构建 grep -E 组合模式
    local pattern
    pattern=$(printf '%s|' "${managed_patterns[@]}")
    pattern="${pattern%|}"  # 去掉末尾 |

    # 过滤：去掉匹配行和纯注释分隔线（# ───... 这类装饰性注释）
    local extracted
    extracted=$(grep -vE "$pattern" "$old_zshrc" \
        | grep -vE '^[[:space:]]*#[[:space:]]*─' \
        || true)

    # 清理连续空行 + 去掉首尾空行
    extracted=$(echo "$extracted" | cat -s | sed '/./,$!d' | sed -e :a -e '/^[[:space:]]*$/{$d' -e N -e ba -e '}')

    # 无内容则跳过
    if [[ -z "$extracted" ]]; then
        echo "✓ 旧 .zshrc 中无额外自定义内容"
        return
    fi

    cat > "$local_file" <<HEADER
# ─── 从旧 ~/.zshrc 自动提取的用户配置 ──────────────────
# 提取时间: $(date '+%Y-%m-%d %H:%M:%S')
# 原始文件已备份至: $BACKUP_DIR/.zshrc
#
# 此文件由 ~/.zshrc 末尾 source 加载，不受 chezmoi 管理。
# 可安全编辑，chezmoi apply 不会覆盖此文件。
# ─────────────────────────────────────────────────────────

HEADER
    echo "$extracted" >> "$local_file"

    local line_count
    line_count=$(echo "$extracted" | wc -l | tr -d ' ')
    echo "✓ 已提取 ${line_count} 行用户配置 → ~/.zshrc.local"
}

# ─── Step 3: 从旧 .zprofile 提取用户自定义 → ~/.zprofile.local
extract_zprofile_local() {
    local old_zprofile="$HOME/.zprofile"
    local local_file="$HOME/.zprofile.local"

    [[ -f "$local_file" ]] && { echo "✓ ~/.zprofile.local 已存在，跳过提取"; return; }
    [[ -f "$old_zprofile" ]] || { return; }

    # .zprofile 通常很简单，只过滤 brew shellenv 和装饰注释
    local extracted
    extracted=$(grep -vE 'eval.*brew[[:space:]]+shellenv|source.*\.zprofile\.local|\[\[.*\.zprofile\.local' "$old_zprofile" \
        | grep -vE '^[[:space:]]*#[[:space:]]*─' \
        || true)
    extracted=$(echo "$extracted" | cat -s | sed '/./,$!d' | sed -e :a -e '/^[[:space:]]*$/{$d' -e N -e ba -e '}')

    if [[ -z "$extracted" ]]; then
        return
    fi

    cat > "$local_file" <<HEADER
# ─── 从旧 ~/.zprofile 自动提取的用户配置 ────────────────
# 提取时间: $(date '+%Y-%m-%d %H:%M:%S')
# ─────────────────────────────────────────────────────────

HEADER
    echo "$extracted" >> "$local_file"

    local line_count
    line_count=$(echo "$extracted" | wc -l | tr -d ' ')
    echo "✓ 已提取 ${line_count} 行用户配置 → ~/.zprofile.local"
}

echo ""
echo "── 提取用户自定义配置 ─────────────────────"
extract_zshrc_local
extract_zprofile_local
echo "── 备份与迁移完成 ─────────────────────────"
