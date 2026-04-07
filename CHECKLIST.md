# TODO

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

## Future

- [ ] Archive `~/diff-review.nvim/`
