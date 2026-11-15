set -U fish_color_normal normal
set -U fish_color_command 88c0d0
set -U fish_color_param e5e9f0
set -U fish_color_keyword 81a1c1
set -U fish_color_quote a3be8c
set -U fish_color_redirection b48ead
set -U fish_color_end 81a1c1
set -U fish_color_error bf616a
set -U fish_color_comment 616e88
set -U fish_color_selection --background=434c5e
set -U fish_color_search_match --background=434c5e
set -U fish_color_operator 81a1c1
set -U fish_color_escape ebcb8b
set -U fish_color_autosuggestion 4c566a
set -U fish_color_cwd 88c0d0
set -U fish_color_cwd_root bf616a

status is-interactive; or exit 0

function fish_greeting
  fastfetch
end

fzf --fish | source

abbr --add ls "eza"
abbr --add grep "grep --color=auto"
abbr --add top "btop"
abbr --add s "ssh stryke@192.168.1.2"
abbr --add gg "cd /mnt/data"
