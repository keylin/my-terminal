# CLAUDE.md

## 项目操作规范

- 除了删除等危险操作外，所有常规操作（编辑、提交、推送等）无需确认，直接执行。
- 变更完成后立即提交并推送，不要等用户要求。

## 项目概览

基于 chezmoi 管理的 dotfiles 项目，一键部署终端开发环境，支持 macOS 和 Linux。

## 关键约定

- **chezmoi 源目录**：`.chezmoiroot` 指向 `home/`，所有 dotfile 源文件在 `home/` 下
- **模板文件**（`.tmpl`）使用 Go template 语法，通过 `.chezmoi.os`、`.chezmoi.arch` 等变量实现跨平台
- **ZSH 配置**使用 `modify_` 前缀（`modify_dot_zshrc.tmpl`），managed block 模式保留用户自定义内容
- **Ghostty 配置**仅 macOS 生效（见 `.chezmoiignore`）
- **外部依赖**（zinit、tpm）通过 `.chezmoiexternal.toml` 管理
- **用户数据**（GitHub 用户名、代理端口）存储在 `~/.config/chezmoi/chezmoi.toml`，模板通过 `.data` 引用

## 文件路径映射

| 源文件 | 目标 |
|--------|------|
| `home/modify_dot_zshrc.tmpl` | `~/.zshrc` |
| `home/dot_zprofile.tmpl` | `~/.zprofile` |
| `home/dot_tmux.conf` | `~/.tmux.conf` |
| `home/dot_config/ghostty/config.tmpl` | `~/.config/ghostty/config` |
| `home/dot_config/starship.toml` | `~/.config/starship.toml` |
