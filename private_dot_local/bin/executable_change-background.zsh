#!/usr/bin/env zsh

change_background() {
  local mode = "light"
  if [[ -z $1 ]]; then
    defaults read -g AppleInterfaceStyle >/dev/null
    if [[ $? -eq 0 ]]; then
      $mode = "dark"
    fi
  else
    if [[ $mode == "light" ]]; then
      osascript -l JavaScript -e "Application('System Events')"
    fi 
  fi 
}

#change vim
for pane in $(tmux list-panes -F'#S #I #P #{pane_current_command}' | awk  '/(view|n?vim?x?)/{ print $1":"$2"."$3 }')
do
  tmux send-keys -t $pane escape ENTER
  tmux send-keys -t $pane ':call ChangeBackground()' ENTER
done
