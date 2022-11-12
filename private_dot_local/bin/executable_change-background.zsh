#!/usr/bin/env zsh

_change_background() {
  local mode = "day"
  if [[ -z $1 ]]; then
    defaults read -g AppleInterfaceStyle >/dev/null
    if [[ $? -eq 0 ]]; then
      $mode = "night"
    fi
  else
    if [[ $mode == "day" ]]; then
      osascript -l JavaScript -e "Application('System Events')"
    fi 
  fi 
}

tmux source-file "~/.tmux/themes/tokyonight_${mode}.tmux"

#change vim
for pane in $(tmux list-panes -F'#S #I #P #{pane_current_command}' | awk  '/(view|n?vim?x?)/{ print $1":"$2"."$3 }')
do
  tmux send-keys -t $pane escape ENTER
  tmux send-keys -t $pane ':call ChangeBackground()' ENTER
done
