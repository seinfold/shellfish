
# fnm
set FNM_PATH "$HOME/.local/share/fnm"

if test -d $FNM_PATH
  set -gx XDG_RUNTIME_DIR "$HOME/.local/run"
  mkdir -p $XDG_RUNTIME_DIR

  set -gx FNM_MULTISHELL_PATH "$XDG_RUNTIME_DIR/fnm_multishells"
  mkdir -p $FNM_MULTISHELL_PATH

  fish_add_path $FNM_PATH
  fnm env | source
end
