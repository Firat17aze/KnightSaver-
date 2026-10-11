#!/bin/zsh
# Sends this Mac's location to the booted iOS Simulator.
#   scripts/simulator-location.sh           once
#   scripts/simulator-location.sh --follow  every 30 seconds until Ctrl-C
# Needs: brew install corelocationcli, and Location Services allowed for CoreLocationCLI
# (System Settings > Privacy & Security > Location Services).

send() {
  local location
  location=$(CoreLocationCLI --format '%latitude,%longitude') || return 1
  xcrun simctl location booted set "$location" && echo "Simulator location: $location"
}

if [[ "$1" == "--follow" ]]; then
  while true; do
    send
    sleep 30
  done
else
  send
fi
