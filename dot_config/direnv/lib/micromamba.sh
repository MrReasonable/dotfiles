# direnv: `layout micromamba [ENV]` in a project's .envrc activates a
# micromamba environment whenever you cd into the folder (or a subfolder),
# and direnv undoes it when you leave, like proto does for tool versions.
#
#   layout micromamba          # env named by `name:` in ./environment.yml
#   layout micromamba myenv    # a named env
#
# If the env doesn't exist yet and there's an environment.yml, it's created
# from it. Managed by chezmoi (dot_config/direnv/lib/micromamba.sh).
layout_micromamba() {
  local env=${1-}
  if [ -z "$env" ] && [ -f environment.yml ]; then
    env=$(sed -n 's/^name:[[:space:]]*//p' environment.yml | head -1)
  fi
  if [ -z "$env" ]; then
    log_error "layout micromamba: give an env name, or add 'name:' to environment.yml"
    return 1
  fi
  if ! has micromamba; then
    log_error "layout micromamba: micromamba not found on PATH"
    return 1
  fi
  eval "$(micromamba shell hook --shell bash)"
  if ! micromamba env list --json | grep -q "/envs/$env\""; then
    if [ -f environment.yml ]; then
      log_status "creating micromamba env '$env' from environment.yml"
      micromamba create -y -q -n "$env" -f environment.yml >&2 || return 1
    else
      log_error "layout micromamba: no env '$env' (create it: micromamba create -n $env python)"
      return 1
    fi
  fi
  micromamba activate "$env"
  # micromamba edits PS1 for the prompt; direnv can't export that, and p10k's
  # anaconda segment shows the env from these variables instead
  export CONDA_DEFAULT_ENV CONDA_PREFIX CONDA_PROMPT_MODIFIER CONDA_SHLVL
}
