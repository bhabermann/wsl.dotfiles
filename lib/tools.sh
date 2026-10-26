#!/usr/bin/env bash
OPTIONAL_TOOLS=(ripgrep fd bat eza jq yq gh tmux tree direnv atuin mise node dotnet python go uv java)
RECOMMENDED_TOOLS=(ripgrep fd bat eza jq gh tmux direnv)
is_runtime() { case "$1" in node|dotnet|python|go|uv|java) return 0;; *) return 1;; esac; }
valid_tool() {
  local tool
  for tool in "${OPTIONAL_TOOLS[@]}"; do [[ "$tool" != "$1" ]] || return 0; done
  return 1
}
tool_description() {
  case "$1" in
    ripgrep) echo "Fast text search";; fd) echo "Friendly file search";;
    bat) echo "Highlighted file viewer";; eza) echo "Modern directory listing";;
    jq) echo "JSON processing";; yq) echo "YAML processing (Debian jq-based implementation)";;
    gh) echo "GitHub CLI";; tmux) echo "Terminal multiplexer";; tree) echo "Directory trees";;
    direnv) echo "Per-directory environment variables";; atuin) echo "Searchable local shell history";;
    mise) echo "Runtime manager without installing language runtimes";;
    *) printf 'mise-managed %s runtime\n' "$1";;
  esac
}
resolve_tool_selection() {
  local tool preset="${TOOLS_PRESET:-}" selected=""
  if [[ -z "$preset" && -f "$DOTFILES_CONFIG_DIR/selected-tools" ]]; then
    selected="$(cat "$DOTFILES_CONFIG_DIR/selected-tools")"
  else
    case "${preset:-recommended}" in
      minimal) ;;
      recommended) selected="$(printf '%s\n' "${RECOMMENDED_TOOLS[@]}")" ;;
      all) selected="$(printf '%s\n' "${OPTIONAL_TOOLS[@]}")" ;;
      *) die "Unknown tools preset: $preset" ;;
    esac
  fi
  for tool in $selected; do valid_tool "$tool" || die "Saved tool '$tool' is unsupported; rerun with --tools minimal"; done
  if [[ "${NON_INTERACTIVE:-0}" == 0 && ( "${RECONFIGURE:-0}" == 1 || ! -f "$DOTFILES_CONFIG_DIR/selected-tools" ) ]]; then
    local choices="" default
    for tool in "${OPTIONAL_TOOLS[@]}"; do
      default=N
      if grep -qxF "$tool" <<< "$selected"; then default=Y; fi
      if confirm_aligned "$tool" "$(tool_description "$tool")" "$default"; then choices+="$tool"$'\n'; fi
    done
    selected="$choices"
  fi
  for tool in "${WITH_ITEMS[@]}"; do
    valid_tool "$tool" || die "Unknown tool: $tool"
    selected+=$'\n'"$tool"
  done
  for tool in "${WITHOUT_ITEMS[@]}"; do
    valid_tool "$tool" || die "Unknown tool: $tool"
    selected="$(grep -vxF "$tool" <<< "$selected" || true)"
  done
  for tool in "${OPTIONAL_TOOLS[@]}"; do
    if grep -qxF "$tool" <<< "$selected"; then printf '%s\n' "$tool"; fi
  done
  return 0
}
