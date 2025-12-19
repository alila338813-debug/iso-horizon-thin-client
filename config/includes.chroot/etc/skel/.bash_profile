if [[ -z $WAYLAND_DISPLAY ]] && [[ $(tty) == /dev/tty1 ]]; then
  export XDG_RUNTIME_DIR=/run/user/$(id -u)
  mkdir -p "$XDG_RUNTIME_DIR"
  chmod 0700 "$XDG_RUNTIME_DIR"
  export WAYLAND_DISPLAY=wayland-0
  systemctl --user import-environment WAYLAND_DISPLAY XDG_RUNTIME_DIR
  systemctl --user start weston@horizon.service
  sleep 3
  systemctl --user start horizon-client.service
fi
