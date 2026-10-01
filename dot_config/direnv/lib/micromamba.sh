# direnv: `layout micromamba [ENV]` in a project's .envrc activates a
# micromamba environment whenever you cd into the folder (or a subfolder),
# and direnv undoes it when you leave, like proto does for tool versions.
#
#   layout micromamba          # ./env if it's an environment (micromamba
#                              # create -p ./env ...), else the `name:` in
#                              # ./environment.yml
#   layout micromamba myenv    # a named env (micromamba create -n myenv ...)
#   layout micromamba ./venv   # an env in a folder (any path with a /)
#
# A named env that doesn't exist yet is created from ./environment.yml if
# there is one. Managed by chezmoi (dot_config/direnv/lib/micromamba.sh).
layout_micromamba() {
  local env=${1-} label
  if ! has micromamba; then
    log_error "layout micromamba: micromamba not found on PATH"
    return 1
  fi
  if [ -z "$env" ]; then
    if [ -d env/conda-meta ]; then
      env=./env
    elif [ -f environment.yml ]; then
      env=$(sed -n 's/^name:[[:space:]]*//p' environment.yml | head -1)
    fi
  fi
  if [ -z "$env" ]; then
    log_error "layout micromamba: no ./env folder environment, no environment.yml name, and no env given"
    return 1
  fi
  eval "$(micromamba shell hook --shell bash)"
  case $env in
    */*)  # a folder environment
      env=$(cd "$env" 2>/dev/null && pwd) || { log_error "layout micromamba: no folder $1"; return 1; }
      [ -d "$env/conda-meta" ] || { log_error "layout micromamba: $env isn't a micromamba environment"; return 1; }
      # name it after the project, not ".../env", for the prompt
      label=$(basename "$(dirname "$env")")
      [ "$(basename "$env")" = env ] || label=$(basename "$env")
      ;;
    *)    # a named environment
      label=$env
      if ! micromamba env list --json | grep -q "/envs/$env\""; then
        if [ -f environment.yml ]; then
          log_status "creating micromamba env '$env' from environment.yml"
          micromamba create -y -q -n "$env" -f environment.yml >&2 || return 1
        else
          log_error "layout micromamba: no env '$env' (create it: micromamba create -n $env python)"
          return 1
        fi
      fi
      ;;
  esac
  micromamba activate "$env"
  # direnv can't export micromamba's PS1 change; p10k's anaconda segment shows
  # the env from these variables instead (CONDA_PROMPT_MODIFIER first)
  CONDA_PROMPT_MODIFIER="($label) "
  export CONDA_DEFAULT_ENV CONDA_PREFIX CONDA_PROMPT_MODIFIER CONDA_SHLVL
}
