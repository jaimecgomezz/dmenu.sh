#!/usr/bin/env bash

# @jaimecgomezz
#
# Control bluectl through dmenu
#
# Requires:
#   - dmenu
#   - bluectl
#   - notify-send

retry_msg="Retry"
scan_msg="Scan devices"
scanned_msg="Scanned"
info_msg="More info"
config_msg="Configure controller"
pair_msg="Pair"
remove_msg="Remove"
block_msg="Block"
unblock_msg="Unblock"
trust_msg="Trust"
untrust_msg="Untrust"
connect_msg="Connect"
disconnect_msg="Disonnect"

__copy() {
  echo "$1"
  echo "$1" | tr -d "\n" | xclip -selection c
  notify-send "$1"
}

__bluectl_select() {
  declare form=$1 prompt="$2" preselection="$3"

  case $form in
    1) dmenu -l 10 -p "$prompt" ;;
    2) dmenu -l 10 -p "$prompt" -d '>' -ps "$preselection" ;;
  esac
}

__bluectl_notify() {
  echo "$1"
  notify-send --app-name "Bluetooth" "Bluetooth" "$1"
}

__bluectl_info_submenu() {
  name="$1"
  options="$(echo "$2" | grep -v "^[A-Z]" | sed 's/\t//' | head -n -1 | sed -e 's/\ \+/ /g' -e 's/UUID: \(.*\)\ (\(.*\))/\1: \2/' | awk -F ': ' '{print $1">"$2}')"
  selection="$(echo -e "$options" | __bluectl_select 2 "$name" )"

  case "$selection" in
    '') return ;;
    *) __copy "$selection" ;;
  esac

  exit 0
}

__bluectl_device_submenu() {
  declare id pairing_msg trusting_msg blocking_msg connection_msg prompt selection options

  id="$1"

  while true; do
    info="$(echo "info $id" | bluetoothctl)"

    name="$(echo "$info" | grep Name: | sed 's/^.*: //')"
    name="${name:-$(echo "$info" | grep Alias: | sed 's/^.*: //')}"

    paired="$(echo "$info" | grep Paired: | sed 's/^.*: //')"
    trusted="$(echo "$info" | grep Trusted: | sed 's/^.*: //')"
    blocked="$(echo "$info" | grep Blocked: | sed 's/^.*: //')"
    connected="$(echo "$info" | grep Connected: | sed 's/^.*: //')"

    [ "$paired" = "yes" ] && pairing_msg="$remove_msg" || pairing_msg="$pair_msg"
    [ "$trusted" = "yes" ] && trusting_msg="$untrust_msg" || trusting_msg="$trust_msg"
    [ "$blocked" = "yes" ] && blocking_msg="$unblock_msg" || blocking_msg="$block_msg"
    [ "$connected" = "yes" ] && connection_msg="$disconnect_msg" || connection_msg="$connect_msg"

    options="$connection_msg\n$trusting_msg\n$blocking_msg\n$pairing_msg\n$info_msg"

    selection="$(echo -e "$options" | __bluectl_select 1 "$name")"

    case "$selection" in
      '') return ;;
      "$connect_msg")
        echo "connect $id" | bluetoothctl
        __bluectl_notify "Connected: $name"
        preselection=0
        sleep 3
      ;;
      "$disconnect_msg")
        echo "disconnect $id" | bluetoothctl
        __bluectl_notify "Disconnected: $name"
        preselection=0
        sleep 3
      ;;
      "$trust_msg")
        echo "trust $id" | bluetoothctl
        __bluectl_notify "Trusted: $name"
        preselection=1
      ;;
      "$untrust_msg")
        echo "untrust $id" | bluetoothctl
        __bluectl_notify "Untrusted: $name"
        preselection=1
      ;;
      "$block_msg")
        echo "block $id" | bluetoothctl
        __bluectl_notify "Blocked: $name"
        preselection=2
      ;;
      "$unblock_msg")
        echo "unblock $id" | bluetoothctl
        __bluectl_notify "Unblocked: $name"
        preselection=2
      ;;
      "$remove_msg")
        echo "remove $id" | bluetoothctl
        __bluectl_notify "Removed: $name"
        preselection=3
      ;;
      "$pair_msg")
        echo "pair $id" | bluetoothctl
        __bluectl_notify "Paired: $name"
        preselection=3
      ;;
      "$info_msg")
        __bluectl_info_submenu "$name" "$info"
        preselection=4
      ;;
    esac
  done
}

__bluectl_scan() {
devices="$(expect <<'EOF'

spawn bluetoothctl
send -- "scan on\r"
expect "Discovery started"

set timeout 3
while 1 {
    expect {
        -re "(.*)\r" { puts $expect_out(1,string) }
        timeout break
    }
}

send -- "scan off\r"
send -- "exit\r"
expect eof
EOF
)"


 echo "$(echo "$devices" | grep Device | grep NEW | sed 's/\r//g' | grep -v ']>' | nl -v 0 -w 1 -s ' ' | awk '{print $5">"$1"@"$4}')"
}

__bluectl_scan_submenu() {
  declare preselection selection devices options

  devices="$(__bluectl_scan)"

  while [ -z "$devices" ]; do
    selection="$(echo "$retry_msg" | __bluectl_select 1 "$scanned_msg")"

    case "$selection" in
      '') return ;;
      "$retry_msg") devices="$(__bluectl_scan)" ;;
    esac
  done

  while true; do
    options="$devices${devices:+\n}$retry_msg"
    selection="$(echo -e "$options" | __bluectl_select 2 "$scanned_msg" "$preselection")"

    case "$selection" in
      '') return ;;
      "$retry_msg")
        __bluectl_scan_submenu
        return
      ;;
      *)
        id="$(echo "$selection" | awk -F '@' '{print $2}')"
        preselection="$(echo "$selection" | awk -F '@' '{print $1}')"
        __bluectl_device_submenu "$id"
      ;;
    esac
  done
}

__bluectl_main() {
  declare preselection prompt devices options selection

  prompt="$(echo "list" | bluetoothctl | grep Controller | grep default | awk -F ' ' '{print $3}')"

  while true; do
    devices="$(echo "devices Paired" | bluetoothctl | grep Device | nl -v 0 -w 1 -s ' ' | awk -F ' ' '{print $4">"$1"@"$3}')"
    options="${devices}${devices:+\n}$scan_msg"

    selection="$(echo -e "$options" | __bluectl_select 2 "$prompt" "$preselection")"

    case "$selection" in
      '') return ;;
      "$scan_msg")
        preselection="$(($(echo "$devices" | wc -l)))"
        __bluectl_scan_submenu
      ;;
      *)
        id="$(echo "$selection" | awk -F '@' '{print $2}')"
        preselection="$(echo "$selection" | awk -F '@' '{print $1}')"
        __bluectl_device_submenu "$id"
      ;;
    esac
  done
}

if [ "$0" = "$BASH_SOURCE" ]; then
  __bluectl_main
fi
