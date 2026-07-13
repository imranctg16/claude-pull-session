# Demo recording for pull-session, using vhs (https://github.com/charmbracelet/vhs).
#
#   1. Install vhs:  brew install charmbracelet/tap/vhs   (or see the vhs repo)
#   2. Record:       vhs demo/pull-session.tape           ->  writes demo/pull-session.gif
#   3. Reference it at the top of README.md:  ![demo](demo/pull-session.gif)
#
# This tape shows the session LIST (the visual highlight). For the full interactive flow
# (picking from the menu, the summary landing in your chat), record that live with
# asciinema inside a real Claude Code session — it's an interactive TUI vhs can't script cleanly.

Output demo/pull-session.gif

Set Shell "bash"
Set FontSize 17
Set Width 1200
Set Height 760
Set Padding 18
Set Theme "Dracula"

Type "# One command, and you see every Claude Code chat you have open:"
Enter
Sleep 1s

Type 'bash plugins/pull-session/scripts/pull-session.sh'
Sleep 800ms
Enter
Sleep 4s

Type "# Pick one, and its summary drops into your current chat. That's it."
Enter
Sleep 2.5s
