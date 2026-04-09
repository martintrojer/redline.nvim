# redline.nvim

A Neovim plugin for capturing code review comments from diff views.

The workflow: navigate diffs, press `cR` to capture lines of interest with a
comment, then open the review buffer with `gR`. The buffer is a structured
markdown document — edit it if needed, then copy and paste the whole thing
into your AI agent of choice for review feedback.

Works as a shared engine across multiple VCS plugins — one plugin, multiple
providers.

## Features

- **Review buffer** — shared scratch buffer with AI-ready preamble and numbered review items
- **Unified diff capture** — extract file, revision, hunk, and selected line from `diff --git` output
- **Inline diff capture** — extract review entries from status inline diffs
- **Per-provider configs** — each provider gets its own buffer and context, no conflicts
- **Built-in providers:**
  - **minigit** — integrates with [mini.git](https://github.com/echasnovski/mini.nvim) command splits (`:Git diff`, `:Git show`)
  - **fugitive** — integrates with [vim-fugitive](https://github.com/tpope/vim-fugitive) pager buffers (`:Git diff`, `:Git show`, `:Git log`)
  - **difftool** — integrates with Neovim 0.12+ `:DiffTool` side-by-side diffs, with VCS-backed metadata for git, jj, and hg
- **Plugin integration** — used as an optional dependency by [jj-fugitive](https://github.com/martintrojer/jj-fugitive) and [sl-fugitive](https://github.com/martintrojer/sl-fugitive)

## Requirements

- Neovim 0.12+

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "martintrojer/redline.nvim",
  config = function()
    require("redline").setup({
      providers = { difftool = true, minigit = true, fugitive = true },
    })
  end,
}
```

### vim.pack (Neovim 0.12+)

```lua
vim.pack.add("https://github.com/martintrojer/redline.nvim")
```

Then in your init:

```lua
require("redline").setup({
  providers = { difftool = true, minigit = true, fugitive = true },
})
```

### As a dependency only

When used purely as a dependency of jj-fugitive or sl-fugitive, you don't
need to call `setup()` — just add redline to your plugins. The parent plugin
creates its own config via `redline.make_config()`.

### Combined

If you want jj-fugitive review support AND the built-in providers (e.g.
`:DiffTool`, mini.git), call `setup()` for the providers. jj-fugitive
creates its own config separately. Each gets its own review buffer — they
don't conflict.

```lua
-- redline setup enables built-in providers
require("redline").setup({
  providers = { difftool = true, minigit = true, fugitive = true },
})

-- jj-fugitive creates its own "jj-review" buffer automatically
require("jj-fugitive").setup({ ... })
```

## Configuration

```lua
require("redline").setup({
  open_mode = "split",       -- "split" or "tab"
  prompt_lines = nil,        -- nil = default AI prompt, false = none, table = custom
  providers = {
    minigit = true,          -- auto-attach to mini.git command splits
    fugitive = true,         -- auto-attach to vim-fugitive pager buffers
    difftool = true,         -- auto-attach to :DiffTool windows
  },
})
```

## Usage

### Built-in providers

When providers are enabled, `cR` and `gR` keymaps are automatically mapped
on relevant buffers:

| Keymap | Action |
|--------|--------|
| `cR` | Add a review comment for the current line |
| `gR` | Open the review buffer |

**minigit provider:** attaches to `MiniGitCommandSplit` events and
`MiniGit.show_at_cursor()` buffers. Works with `:Git diff`, `:Git show`,
`:Git log`, `:Git blame`, and cursor-based commit inspection.

**fugitive provider:** attaches to `FugitivePager` events from
[vim-fugitive](https://github.com/tpope/vim-fugitive). Works with `:Git diff`,
`:Git show`, `:Git log`, and `:Git blame`. Shares the same review buffer as
the minigit provider (both are git-backed).

**difftool provider:** attaches to `:DiffTool` side-by-side diff windows.
Detects git, jj, and hg repos automatically and resolves revision metadata.

### `:Redline` command

Jumps to an existing review buffer. If multiple review buffers exist (e.g.
from different providers), presents a picker. If none exist, shows a message.

### As a library

Plugins can use redline as a review engine — either as a built-in provider or
as an optional dependency baked into your VCS plugin. See
[INTEGRATING.md](INTEGRATING.md) for the full guide, entry field reference,
and comparison of both approaches.

## API

| Function | Description |
|----------|-------------|
| `setup(opts)` | Set defaults and enable providers |
| `make_config(opts)` | Create a per-provider config table |
| `show(config)` | Show the review buffer for a specific config |
| `show_any()` | Find and show existing review buffers (picker if multiple) |
| `append(config, entry)` | Append a formatted review item |
| `comment(config, bufnr, entry_fn)` | Extract entry + prompt for comment + append |
| `comment_unified_diff(config, bufnr, ctx)` | Convenience wrapper for unified diff capture |
| `extract_unified_diff_entry(bufnr, ctx)` | Parse entry from a unified diff buffer |
| `extract_inline_diff_entry(bufnr, ranges)` | Parse entry from status inline diffs |

## License

MIT
