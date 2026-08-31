# Wayland demo recording

The host-side demo uses a real Wayland terminal and virtual keyboard. It does
not change Docfd or run recording tools in the VHS container.

## Requirements

- `foot`, as the demo terminal
- `ydotool` with `ydotoold` running and access to `/dev/uinput`
- `showmethekey-gtk`, to display input events
- a screen recorder such as OBS, Kooha, or your compositor's recorder
- `docfd` available on `PATH`

Show Me The Key reads input devices through libinput, so it should see the
virtual keyboard created by ydotool. Verify this with a short manual test before
recording the complete demo.

## One-time setup

Start `ydotoold` with the included helper. It creates the socket with your user
as its owner:

```sh
./demo-wayland-start-ydotoold.sh
```

The demo script explicitly uses `/tmp/.ydotool_socket` by default. If your
service uses another socket, pass the same path to both scripts:

```sh
export YDOTOOL_SOCKET=/run/user/"$(id -u)"/.ydotool_socket
./demo-wayland-start-ydotoold.sh
./demo-wayland.sh
```

Then start the key display with its floating window enabled and its settings
window hidden:

```sh
showmethekey-gtk -k -A -C
```

Wayland does not allow the application to position its own floating window.
Move it over the desired part of the terminal and configure your compositor to
keep it above other windows. Show Me The Key documents suitable rules for
GNOME, KDE, Sway, and Hyprland.

Test that the virtual keyboard and key display communicate:

```sh
ydotool type test
```

## Record

From the Docfd repository, start the recorder and then run:

```sh
bash demo-wayland.sh
```

The script gives a three-second countdown, launches a new `foot` window, and
replays the existing interactive repository demo. Do not change keyboard focus
while it is running: ydotool deliberately sends input to the focused window.

The delays can be adjusted without editing the script:

```sh
DOCFD_DEMO_TYPING_DELAY_MS=75 DOCFD_DEMO_STARTUP_DELAY=5 \
  bash demo-wayland.sh
```

The script closes its terminal after the final pause. Stop the recorder, then
crop or encode the recording with the recorder's normal workflow.
