# redline.nvim Implementation Plan

## Context

Three existing plugins each implement their own AI review comment capture:
- **jj-fugitive** and **sl-fugitive** have nearly identical `review.lua` modules
  (~240 lines each) for capturing comments from unified diff views
- **diff-review.nvim** (~700 lines) captures comments from Neovim 0.12+
  `:DiffTool` side-by-side diffs, with VCS provider-backed metadata for
  git/jj/hg

This plan extracts all three into a single `redline.nvim` plugin with a shared
review buffer engine and provider-based entry extraction. The result: one plugin,
three providers, full coverage across git, jj, sapling, and `:DiffTool`.

After migration:
- jj-fugitive drops `review.lua`, calls redline directly
- sl-fugitive drops `review.lua`, calls redline directly
- diff-review.nvim is retired entirely (absorbed as the `difftool` provider)

## Architecture

```
~/redline.nvim/
├── lua/redline/
│   ├── init.lua                    -- setup(), public API
│   ├── parse.lua                   -- unified diff parsing (find_file, find_hunk)
│   ├── format.lua                  -- entry formatting + preamble generation
│   ├── buffer.lua                  -- review buffer lifecycle
│   ├── util.lua                    -- minimal UI helpers
│   └── providers/
│       ├── minigit.lua             -- MiniGitCommandSplit autocmd
│       └── difftool/
│           ├── init.lua            -- BufWinEnter/WinEnter autocmds, cR/gR setup
│           ├── session.lua         -- DiffTool window detection (left/right, peer)
│           ├── detect.lua          -- VCS root detection (.git/.jj/.hg markers)
│           ├── extract.lua         -- entry extraction with context from both sides
│           └── vcs/
│               ├── init.lua        -- provider dispatch
│               ├── base.lua        -- shared make_meta/make_side helpers
│               ├── util.lua        -- run(), file_hash(), shorten_hash()
│               ├── git.lua         -- git revision resolver + diff_for_path
│               ├── jj.lua          -- jj revision resolver + diff_for_path
│               ├── hg.lua          -- hg revision resolver + diff_for_path
│               └── unknown.lua     -- fallback LEFT/RIGHT labels
├── plugin/redline.lua              -- :Redline command registration
├── stylua.toml
└── README.md
```

## Step 1: Create redline.nvim core ✅

### `lua/redline/util.lua`

Minimal self-contained UI helpers (from jj-fugitive's `ui.lua`):
- `find_buf(pattern)` — find buffer by name pattern
- `create_scratch_buffer(opts)` — unlisted scratch buffer with name/ft/modifiable/bufhidden
- `ensure_visible(bufnr, open_mode)` — cross-tab search, jump or open pane
- `open_pane(open_mode)` — split or tabnew based on config
- `set_statusline(bufnr, text)` — setlocal statusline
- `buf_var(bufnr, name, default)` — safe nvim_buf_get_var with fallback
- `map(bufnr, mode, lhs, rhs)` — buffer-local keymap with noremap+silent
- `close_cmd(open_mode)` — "tabclose" or "close"
- `help_popup(title, lines, opts)` — floating window with auto-close
- `info(msg)`, `warn(msg)` — vim.notify wrappers
- `run(cmd, cwd)` — vim.system():wait() wrapper (from diff-review's providers/util.lua)
- `shorten_hash(value, len)` — truncate hash strings
- `file_hash(path)` — sha256 content hash via sha256sum/shasum/openssl

No dependency on any VCS plugin.

### `lua/redline/parse.lua`

Pure functions, identical to current jj-fugitive/sl-fugitive implementations:
- `find_file_for_cursor(lines, cursor_line)` — walks back for `diff --git a/X b/Y`
- `find_hunk_for_cursor(lines, cursor_line, start_line, normalize)` — walks back for `@@`
- `trim_inline_prefix(line)` — strips 4-space indent

### `lua/redline/format.lua`

- `preamble(opts)` — review buffer initial content, parameterized by `repo_type`,
  `repo_root`, `source`. Supports `opts.prompt_lines` override (nil = default,
  false = none, table = custom) to match diff-review.nvim's flexibility.
- `format_entry(entry, number)` — formats a single review item. Renders all
  fields conditionally from the entry table (union of all provider formats):
  - Core: `file`/`path`, `rev`, `change`/`selected_line`, `comment`
  - Unified diff: `hunk`, `source`, `node`, `summary`, `author`, `date`
  - DiffTool: `side`, `peer_path`, `peer_rev`, `line_number`, `hunk_lines`,
    `context` (multi-line block), `qf_text`, `qf_lnum`
- `next_comment_number(bufnr)` — counts existing `### Review Item %d+` headers.

### `lua/redline/buffer.lua`

- `find(config)` — find existing review buffer by name pattern
- `get_or_create(config)` — find or create scratch buffer (markdown,
  modifiable=true, bufhidden=hide), write preamble on creation, set `q`
  keymap to close. Returns `bufnr`.
- `show(config)` — get_or_create + ensure_visible + set_statusline +
  call `config.on_show(bufnr)` if set. Returns `bufnr`.
- `append(config, entry)` — get_or_create, format entry, append lines,
  notify. Returns `number, bufnr`.

### `lua/redline/init.lua`

Public API:

```lua
M.setup(opts)                              -- config + enable providers
M.show()                                   -- show review buffer, returns bufnr
M.append(entry)                            -- append complete entry
M.comment(bufnr, entry_fn)                -- generic: entry_fn(bufnr) -> entry, err
M.comment_unified_diff(bufnr, ctx)        -- convenience: parse unified diff + ctx
M.extract_unified_diff_entry(bufnr, ctx)  -- exported parser for unified diffs
M.extract_inline_diff_entry(bufnr, ranges) -- exported parser for status inline diffs
```

Config shape:
```lua
{
  repo_type = nil,          -- "jj" | "sapling" | "git" | nil (auto)
  repo_root = nil,          -- string | function() -> string
  open_mode = "split",      -- "split" | "tab"
  buf_name = "redline-review",
  prompt_lines = nil,       -- nil = default, false = none, table = custom
  on_show = nil,            -- function(bufnr) for VCS-specific keymaps
  providers = {},           -- { minigit = true|false, difftool = true|false }
}
```

Key design: context is passed directly (closures), NOT via buffer variables.
This eliminates the `jj_review_context` coupling.

### `plugin/redline.lua`

```lua
vim.api.nvim_create_user_command("Redline", function()
  require("redline").show()
end, { desc = "Open redline review buffer" })
```

## Step 2: mini.git provider ✅

### `lua/redline/providers/minigit.lua`

Activated when `providers.minigit = true` in setup (or auto-detected).

Registers one autocmd:
```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "MiniGitCommandSplit",
  callback = function(au_data) M.on_split(au_data) end,
})
```

`on_split` handler:
- Reads `au_data.data.git_subcommand`
- For `"diff"` or `"show"`: parse revision from `au_data.data.git_command` array,
  map `cR` and `gR` on the output buffer (`data.win_stdout`)
- For `"log"` or `"blame"`: only map `gR`
- Uses `data.cwd` as repo_root fallback
- Sets `repo_type = "git"` if not configured

Revision parsing from `git_command` array:
- `{"git","diff"}` → "worktree vs index"
- `{"git","diff","--cached"}` → "index vs HEAD"
- `{"git","diff","HEAD~1"}` → "HEAD~1"
- `{"git","diff","A..B"}` → "A..B"
- `{"git","show","abc123"}` → "abc123"
- Strip `--` and everything after it (pathspec)
- Skip flags starting with `-`

## Step 3: DiffTool provider (absorbs diff-review.nvim) ✅

### `lua/redline/providers/difftool/`

This provider replaces `~/diff-review.nvim/` entirely. The code is largely a
direct port of the existing modules with `require()` paths updated.

Activated when `providers.difftool = true` in setup.

#### `init.lua` — provider entry point

Registers `BufWinEnter`/`WinEnter` autocmds (from diff-review's `init.lua`):
- On each event, check if `:DiffTool` is active (`nvim.difftool.events` augroup)
- If current window has `diff` set, map `cR` and `gR` on the buffer
- `cR` calls `extract.current()` → `vim.ui.input` → `redline.append(entry)`
- `gR` calls `redline.show()`

Key change from diff-review: drops `packet.lua` entirely. All review buffer
operations go through `require("redline")`.

#### `session.lua` — DiffTool window detection

Direct port of `~/diff-review.nvim/lua/diff-review/session.lua` (~65 lines):
- `current()` — finds diff windows in current tab, sorts by position,
  determines left/right side, returns `{winid, bufnr, peer_win, peer_bufnr,
  side, qf_entry}`

#### `detect.lua` — VCS root detection

Direct port of `~/diff-review.nvim/lua/diff-review/detect.lua` (~95 lines):
- `detect(...)` — walks upward from paths looking for `.jj`/`.hg`/`.git` markers
- `relative_path(path, root)` — compute relative path
- `is_inside_root(path, root)` — check path containment

#### `extract.lua` — entry extraction

Direct port of `~/diff-review.nvim/lua/diff-review/extract.lua` (~210 lines):
- `current()` — combines session, detect, and VCS provider to build a complete
  entry with path, rev, side, peer info, hunk, hunk_lines, context from both
  sides, quickfix metadata. Returns entry table compatible with
  `redline.append()`.

Updated `require()` paths from `diff-review.*` to `redline.providers.difftool.*`.

#### `vcs/` — VCS metadata resolvers

Direct ports from `~/diff-review.nvim/lua/diff-review/providers/`:
- `init.lua` (~25 lines) — `for_detection(detection)` dispatcher
- `base.lua` (~55 lines) — `make_meta()`, `make_side()` helpers
- `util.lua` (~60 lines) — `run()`, `file_hash()`, `shorten_hash()`
  (Note: `run()` and hash utils may share with `redline/util.lua` —
  deduplicate or re-export)
- `git.lua` (~125 lines) — HEAD/blob resolution, worktree hashing,
  `diff_for_path` via `git diff --no-ext-diff`
- `jj.lua` (~105 lines) — `@`/`@-` change+commit ID resolution,
  `diff_for_path` via `jj diff --git`
- `hg.lua` (~150 lines) — `.` revision, manifest file hashes, worktree
  hashing, `diff_for_path` via `hg diff`
- `unknown.lua` (~20 lines) — fallback LEFT/RIGHT labels

## Step 4: Migrate jj-fugitive ⬜

Changes to `~/jj-fugitive/`:

### Add redline dependency
Document in README. In lazy.nvim: `dependencies = { "martintrojer/redline.nvim" }`

### `init.lua` setup
Call `require("redline").setup()` inside `M.setup()`:
```lua
require("redline").setup({
  repo_type = "jj",
  repo_root = function() return M.repo_root() or vim.fn.getcwd() end,
  open_mode = M.config.open_mode,
  buf_name = "jj-review",
  on_show = function(bufnr) -- gl, gs, gb, g? keymaps end,
})
```

### diff.lua
Replace `set_review_context` + `require("jj-fugitive.review")` calls:
```lua
local review_ctx = { file = filename, rev = rev or "@" }
ui.map(bufnr, "n", "cR", function()
  require("redline").comment_unified_diff(bufnr, review_ctx)
end)
ui.map(bufnr, "n", "gR", function() require("redline").show() end)
```

Remove `set_review_context()` helper and the `pcall(nvim_buf_set_var ...)` call.

### log.lua
Same pattern for show detail buffers:
```lua
local review_ctx = { rev = id }
ui.map(show_buf, "n", "cR", function()
  require("redline").comment_unified_diff(show_buf, review_ctx)
end)
ui.map(show_buf, "n", "gR", function() require("redline").show() end)
```

Remove `pcall(vim.api.nvim_buf_set_var, show_buf, "jj_review_context", ...)`.
Keep `gR` on the log buffer itself (line 656).

### status.lua
Replace `comment_inline_diff`:
```lua
local function comment_inline_diff(bufnr)
  local ranges = inline_diff_state(bufnr)
  require("redline").comment(bufnr, function(b)
    return require("redline").extract_inline_diff_entry(b, ranges)
  end)
end
```

### bookmark.lua
Replace `require("jj-fugitive.review").show()` → `require("redline").show()`

### Delete review.lua
Remove `lua/jj-fugitive/review.lua` entirely.

## Step 5: Migrate sl-fugitive ⬜

Same pattern as jj-fugitive, with:
- `repo_type = "Sapling"`
- `buf_name = "sl-review"`
- Richer context in diff.lua and log.lua (include `source`, `node`, `summary`,
  `author`, `date`)
- Also update annotate.lua (`gR` only)

### browse.lua decoupling
`browse.lua` reads `jj_review_context` for `node` and `file` (lines 140, 167).
This is unrelated to review — rename to `sl_buffer_context` in:
- `diff.lua` — keep setting the buffer var (renamed)
- `log.lua` — keep setting the buffer var (renamed)
- `browse.lua` — read from renamed var

### Delete review.lua
Remove `lua/sl-fugitive/review.lua` entirely.

## Step 6: Retire diff-review.nvim ⬜

After the difftool provider is verified working:
- Remove `diff-review` from the Neovim plugin list
- `~/diff-review.nvim/` can be archived
- Users configure redline with `providers = { difftool = true }` instead

## Verification

1. **Static analysis**: `luacheck lua/redline/ plugin/` and `stylua --check .`
2. **mini.git diff**: Open git repo → `:Git diff` → `cR` on diff line → enter
   comment → `gR` → verify review buffer with "git" preamble
3. **mini.git show**: `:Git show HEAD` → `cR` → verify commit hash captured
4. **jj-fugitive diff**: `:J diff` → `cR` → `gR` → verify "jj" preamble,
   verify `gl`/`gs`/`gb` nav keymaps on review buffer
5. **sl-fugitive diff**: `:S diff` → `cR` → `gR` → verify rich metadata
   (source, node, summary, author, date)
6. **Status inline**: `:J status` → `=` to expand → `cR` on inline diff line →
   verify entry with correct file/hunk
7. **Log show**: `:J log` → `<CR>` → `cR` → verify commit rev captured
8. **DiffTool file**: `:DiffTool` on a file → `cR` on right side → verify entry
   with path, rev, side=right, peer info, hunk, context from both sides
9. **DiffTool left side**: cursor on left window → `cR` → verify side=left label
10. **DiffTool directory**: `:DiffTool` on directory → navigate quickfix → `cR` →
    verify quickfix metadata captured
11. **DiffTool VCS providers**: test in git, jj, and hg repos → verify provider-
    backed revision metadata (commit hashes, change IDs, blob IDs)
12. **Buffer persistence**: add comments from different sources → close/reopen
    with `gR` → verify all entries preserved
13. **Cross-tab**: review buffer in tab A, `gR` from tab B → jumps to tab A
14. **Browse (sl)**: verify `:S browse` still works after buf var rename

## Files to create

```
~/redline.nvim/lua/redline/init.lua
~/redline.nvim/lua/redline/parse.lua
~/redline.nvim/lua/redline/format.lua
~/redline.nvim/lua/redline/buffer.lua
~/redline.nvim/lua/redline/util.lua
~/redline.nvim/lua/redline/providers/minigit.lua
~/redline.nvim/lua/redline/providers/difftool/init.lua
~/redline.nvim/lua/redline/providers/difftool/session.lua
~/redline.nvim/lua/redline/providers/difftool/detect.lua
~/redline.nvim/lua/redline/providers/difftool/extract.lua
~/redline.nvim/lua/redline/providers/difftool/vcs/init.lua
~/redline.nvim/lua/redline/providers/difftool/vcs/base.lua
~/redline.nvim/lua/redline/providers/difftool/vcs/util.lua
~/redline.nvim/lua/redline/providers/difftool/vcs/git.lua
~/redline.nvim/lua/redline/providers/difftool/vcs/jj.lua
~/redline.nvim/lua/redline/providers/difftool/vcs/hg.lua
~/redline.nvim/lua/redline/providers/difftool/vcs/unknown.lua
~/redline.nvim/plugin/redline.lua
~/redline.nvim/stylua.toml
```

## Files to modify

```
~/jj-fugitive/lua/jj-fugitive/init.lua       — add redline.setup() call
~/jj-fugitive/lua/jj-fugitive/diff.lua       — replace review calls
~/jj-fugitive/lua/jj-fugitive/log.lua        — replace review calls
~/jj-fugitive/lua/jj-fugitive/status.lua     — replace review calls
~/jj-fugitive/lua/jj-fugitive/bookmark.lua   — replace review calls

~/sl-fugitive/lua/sl-fugitive/init.lua        — add redline.setup() call
~/sl-fugitive/lua/sl-fugitive/diff.lua        — replace review calls + rename buf var
~/sl-fugitive/lua/sl-fugitive/log.lua         — replace review calls + rename buf var
~/sl-fugitive/lua/sl-fugitive/status.lua      — replace review calls
~/sl-fugitive/lua/sl-fugitive/bookmark.lua    — replace review calls
~/sl-fugitive/lua/sl-fugitive/annotate.lua    — replace review calls
~/sl-fugitive/lua/sl-fugitive/browse.lua      — rename jj_review_context → sl_buffer_context
```

## Files to delete

```
~/jj-fugitive/lua/jj-fugitive/review.lua
~/sl-fugitive/lua/sl-fugitive/review.lua
~/diff-review.nvim/  (archive — fully replaced by redline difftool provider)
```
