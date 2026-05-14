fpath=("$HOME/.zsh/plugins/zsh-completions/src" $fpath)
autoload -Uz compinit
mkdir -p "$HOME/.cache"
compinit -C -d "$HOME/.cache/zcompdump"
