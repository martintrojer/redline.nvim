# Integrating with redline.nvim

This guide covers how to add review comment capture to your plugin or workflow.
There are two approaches: **built-in providers** that live inside redline.nvim
and are enabled via `setup()`, and **external integration** where your VCS
plugin uses redline as an optional dependency.

## Concepts

**Config** — each provider creates its own config table via
`redline.make_config()`. This gives it a separate review buffer (identified by
`buf_name`) with its own preamble context. Multiple providers coexist without
conflicts.

**Entry** — a table describing a single review item. Entries are passed to
`redline.append(config, entry)` and rendered as numbered markdown sections in
the review buffer. Fields are all optional and rendered conditionally.

**Context** — a table passed to `redline.comment_unified_diff()` that describes
what the user is looking at (file, revision, etc.). Redline uses this to
extract the entry from the buffer at cursor position.

## Entry fields

All fields are optional. The formatter renders whichever are present.

```lua
{
  -- Unified diff fields
  file = "src/main.lua",         -- file path
  rev = "@",                     -- revision identifier
  hunk = "@@ -10,3 +10,5 @@",   -- hunk header
  change = "+local x = 1",      -- the selected diff line
  source = "working copy diff", -- where this came from
  node = "abc123",               -- changeset/commit ID
  summary = "fix: ...",          -- commit summary
  author = "user",               -- commit author
  date = "2026-04-07",           -- commit date

  -- DiffTool fields
  path = "src/main.lua",        -- resolved path (alt to file)
  side = "right",                -- "left" or "right"
  peer_path = "src/main.lua",   -- peer side path
  peer_rev = "HEAD abc123",     -- peer side revision
  selected_line = "local x",    -- selected line text (alt to change)
  line_number = 42,              -- cursor line number
  hunk_lines = { ... },          -- full hunk content
  context = { ... },             -- context lines from both sides
  qf_text = "M",                 -- quickfix entry text
  qf_lnum = 10,                  -- quickfix line number

  -- Set by provider, used to update preamble
  vcs = "git",                   -- updates config.repo_type
  repo_root = "/path/to/repo",  -- updates config.repo_root

  -- Set after user input
  comment = "This looks wrong", -- the reviewer's comment
}
```

## Approach 1: Built-in provider

Built-in providers live under `lua/redline/providers/` and are enabled via
`setup({ providers = { name = true } })`. They manage their own autocmds
and keymap attachment.

### Skeleton

```lua
-- lua/redline/providers/myprovider.lua
local M = {}
local initialized = false

function M.setup(_defaults)
  if initialized then
    return
  end
  initialized = true

  -- Create a provider-specific config with its own buffer
  M.config = require("redline").make_config({
    repo_type = "git",
    buf_name = "redline-myprovider",
    source = "myprovider review",
    repo_root = function()
      return M.last_cwd or vim.fn.getcwd()
    end,
  })

  -- Set up autocmds to detect relevant buffers
  local group = vim.api.nvim_create_augroup("RedlineMyProvider", { clear = true })
  vim.api.nvim_create_autocmd("SomeEvent", {
    group = group,
    callback = function(args)
      M.on_event(args)
    end,
  })
end

function M.on_event(args)
  local bufnr = args.buf
  -- Guard: don't set keymaps twice
  if require("redline.util").buf_var(bufnr, "redline_myprovider_set", false) then
    return
  end
  pcall(vim.api.nvim_buf_set_var, bufnr, "redline_myprovider_set", true)

  local redline = require("redline")
  local util = require("redline.util")

  -- Build context for this buffer
  local ctx = {
    file = nil,    -- nil = auto-detect from diff header
    rev = "HEAD",
    source = "myprovider",
  }

  -- Map cR to capture a review comment
  util.map(bufnr, "n", "cR", function()
    redline.comment_unified_diff(M.config, bufnr, ctx)
  end)

  -- Map gR to open the review buffer
  util.map(bufnr, "n", "gR", function()
    redline.show(M.config)
  end)
end

return M
```

### Registering

Add your provider to `setup()` in `lua/redline/init.lua`:

```lua
if M.defaults.providers.myprovider then
  require("redline.providers.myprovider").setup(M.defaults)
end
```

### Key patterns

- **Guard keymaps** with a buffer variable to avoid double-mapping on refresh.
- **Store `M.config`** on the module so all keymap closures reference the same
  config and the same review buffer.
- Use `redline.comment_unified_diff(config, bufnr, ctx)` for the standard
  flow: parse diff at cursor, prompt for comment, append to buffer.
- Use `redline.show(config)` for `gR` — always goes to the right buffer.
- For non-diff buffers (log, blame), only map `gR` since there are no diff
  lines to capture.

### Real example: minigit provider

See `lua/redline/providers/minigit.lua`. It hooks into two event sources:

1. `MiniGitCommandSplit` User event — fired by `:Git` commands
2. `FileType git` — catches `MiniGit.show_at_cursor()` buffers that bypass
   the User event

It parses the revision from the git command array and builds a context table
for each buffer.

## Approach 2: External integration (baked into your VCS plugin)

This is how jj-fugitive and sl-fugitive use redline. Your plugin treats
redline as an **optional dependency** — everything works without it, review
keymaps just don't appear.

### Setup pattern

In your plugin's `setup()`, try to require redline. If available, create a
config and store it on your module:

```lua
function M.setup(opts)
  M.config = vim.tbl_extend("force", M.config, opts or {})

  local has_redline, redline = pcall(require, "redline")
  if has_redline then
    M.review_config = redline.make_config({
      repo_type = "jj",
      repo_root = function()
        return M.repo_root() or vim.fn.getcwd()
      end,
      open_mode = M.config.open_mode,
      buf_name = "jj-review",
      source = "jj-fugitive review",
      on_show = function(bufnr)
        -- Set custom keymaps on the review buffer (navigation, help, etc.)
      end,
    })
  end
end
```

### Keymap pattern

In your diff/log/status modules, check `init.review_config` to guard keymaps:

```lua
local init = require("my-plugin")
if init.review_config then
  ui.map(bufnr, "n", "cR", function()
    require("redline").comment_unified_diff(init.review_config, bufnr, ctx)
  end)
  ui.map(bufnr, "n", "gR", function()
    require("redline").show(init.review_config)
  end)
end
```

### Context table

The context table tells redline what the user is looking at. For unified diffs:

```lua
local ctx = {
  file = filename,        -- nil to auto-detect from diff header
  rev = rev or "@",       -- revision being reviewed
  source = "commit diff", -- label for the entry
  node = commit_hash,     -- optional: changeset ID
  summary = "fix: ...",   -- optional: commit summary
  author = "user",        -- optional: commit author
  date = "2026-04-07",    -- optional: commit date
}
```

For inline diffs (expanded in status views), use `extract_inline_diff_entry`:

```lua
local ranges = get_inline_diff_state(bufnr) -- your range tracking
require("redline").comment(init.review_config, bufnr, function(b)
  return require("redline").extract_inline_diff_entry(b, ranges)
end)
```

Each range in `ranges` should have `{ start_line, end_line, file, rev }` at
minimum.

### Custom entry extraction

If your diff format doesn't match standard `diff --git` output, build the
entry yourself and use `comment()` directly:

```lua
require("redline").comment(config, bufnr, function(b)
  -- Your custom extraction logic
  local entry = {
    file = "foo.lua",
    rev = "abc123",
    change = vim.api.nvim_get_current_line(),
  }
  return entry
end)
```

Or skip the prompt and append directly:

```lua
entry.comment = "already have a comment"
require("redline").append(config, entry)
```

### `on_show` callback

The `on_show` function is called each time the review buffer is shown. Use it
to set navigation keymaps that let users jump back to your plugin's views:

```lua
on_show = function(bufnr)
  -- Guard against double-mapping
  if ui.buf_var(bufnr, "my_review_keymaps_set", false) then
    return
  end
  pcall(vim.api.nvim_buf_set_var, bufnr, "my_review_keymaps_set", true)

  ui.map(bufnr, "n", "gl", function()
    vim.cmd("close")
    require("my-plugin.log").show()
  end)
  -- etc.
end
```

### Advantages of external integration

- **Full context** — your plugin owns the buffers, revisions, and metadata.
  Context tables are precise, not heuristic.
- **Optional dependency** — users who don't want review get zero overhead.
- **Custom review buffer** — `on_show` lets you add navigation keymaps that
  fit your plugin's view structure.
- **Richer entries** — you know the commit summary, author, date, etc. and
  can include them directly.

### Comparison to built-in providers

| | Built-in provider | External integration |
|---|---|---|
| Lives in | `redline.nvim` repo | Your plugin's repo |
| Enabled via | `setup({ providers = { ... } })` | `pcall(require, "redline")` in your setup |
| Context quality | Heuristic (autocmd data, buffer names) | Precise (your plugin owns the data) |
| Dependency | Part of redline | Optional — graceful degradation |
| Review buffer keymaps | Generic (`q` only) | Custom via `on_show` |
| Best for | Generic tools (mini.git, DiffTool) | VCS-specific plugins with rich metadata |
