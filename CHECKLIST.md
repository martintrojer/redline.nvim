# Checklist

## Verification

- [ ] `:Git show HEAD` → `cR` → verify commit hash captured
- [ ] `:GG` on hash → `cR` → verify hash captured (show_at_cursor path)
- [ ] `:J diff` → `cR` → `gR` → verify "jj" preamble, nav keymaps
- [ ] `:S diff` → `cR` → `gR` → verify rich metadata (source, node, summary, author, date)
- [ ] `:J status` → `=` to expand → `cR` on inline diff line
- [ ] `:J log` → `<CR>` → `cR` → verify commit rev captured
- [ ] `:DiffTool` on file → `cR` right side → verify entry with path, rev, side, peer info, hunk, context
- [ ] `:DiffTool` left side → `cR` → verify side=left
- [ ] `:DiffTool` directory → navigate quickfix → `cR` → verify quickfix metadata
- [ ] `:DiffTool` in git, jj, hg repos → verify provider-backed revision metadata
- [ ] Buffer persistence: add comments, close, `gR` → entries preserved
- [ ] Cross-tab: review buffer in tab A, `gR` from tab B → jumps to tab A
- [ ] `:S browse` → verify works after `sl_buffer_context` rename

## Code review

### Critical

- [x] Delete `vcs/util.lua` — pointless re-export of `redline.util`
- [x] Move `repo_relpath` from git.lua and hg.lua into base.lua
- [x] Extract `resolve_session` 4-branch pattern into `base.resolve_sides()`

### Recommended

- [x] Rewrite `difftool/init.lua` `comment_current` to use `redline.comment()`
- [x] Simplify `base.make_meta` to accept two side spec tables
- [x] Remove unreachable `old_file` branch in `parse.lua`
- [x] Deduplicate `_configs` by `buf_name` in `make_config`

### Suggestions

- [ ] `schedule_attach` in difftool double-fires (vim.schedule + vim.defer_fn) — single defer_fn suffices
- [ ] Use `util.warn` instead of `vim.notify` directly in `difftool/init.lua` `comment_current`
- [ ] `help_popup` creates buffer with modifiable=true then immediately sets false — pass lines before locking
- [ ] `detect.find_root` uses `type = "directory"` which misses `.git` files in worktrees — use `type = "any"`
- [ ] `relative_path` and `is_inside_root` in detect.lua share duplicated path normalization

## Future

- [ ] Archive `~/diff-review.nvim/`
