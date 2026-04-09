# redline.nvim

Neovim plugin for capturing AI review comments from diff views. Provides a shared review buffer engine with provider-based entry extraction across git, jj, sapling, and `:DiffTool`.

## Language & Framework

- Lua (Neovim plugin, targeting Neovim 0.12+)
- No external Lua dependencies

## Formatting & Linting

- **stylua** for formatting: `stylua --check lua/ plugin/` to verify, `stylua lua/ plugin/` to fix
- **luacheck** for linting: `luacheck lua/ plugin/`

## Project Structure

- `lua/redline/` — core modules (init, parse, format, buffer, util)
- `lua/redline/providers/minigit.lua` — mini.git integration
- `lua/redline/providers/fugitive.lua` — vim-fugitive integration
- `lua/redline/providers/difftool/` — `:DiffTool` integration (session, detect, extract, vcs/)
- `plugin/redline.lua` — `:Redline` command registration
