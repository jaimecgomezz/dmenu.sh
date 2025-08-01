# @jaimecgomezz
#
# Control pactl through dmeny
#
# Requires:
#   - dmenu
#   - pactl
#   - notify-send

sources_msg="Mics"
sinks_msg="Speakers"
sink_inputs_msg="Playbacks"
default_msg="Set as default"
volume_msg="Volume"
mute_msg="Mute"
redirect_msg="Redirect"

__copy() {
  echo "$1"
  echo "$1" | tr -d "\n" | xclip -selection c
  notify-send "$1"
}

__select() {
  form=$1
  prompt="$2"
  preselection="$3"

  case $form in
    2) dmenu -l 10 -p "$prompt" -d '>' ;;
    3) dmenu -l 10 -p "$prompt" -d '>' -ps "$preselection" ;;
    *) dmenu -l 10 -p "$prompt" ;;
  esac
}

__audio_notify() {
  echo "$1"
  notify-send --app-name "Audio" "Audio" "$1"
}

__audio_find_sink() {
  echo "$(pactl -f json list sinks | jq -r ".[] | select(.name==\"$1\")")"
}

__audio_find_default_sink() {
  echo "$(pactl -f json list sinks | jq -r ".[] | select(.name==\"$(pactl get-default-sink)\")")"
}

__audio_find_sink_input() {
  echo "$(pactl -f json list sink-inputs | jq -r ".[] | select(.index==$1)")"
}

__audio_find_source() {
  echo "$(pactl -f json list sources | jq -r ".[] | select(.index==$1)")"
}

__audio_find_default_source() {
  echo "$(pactl -f json list sources | jq -r ".[] | select(.name==\"$(pactl get-default-source)\")")"
}

__audio_source_volume_submenu() {
  declare preselection

  id="$1"
  options="+5\n+10\n+20\n-5\n-10\n-20"

  while true; do
    source="$(__audio_find_source "$id")"
    volume="$(echo "$source" | jq -r '.volume | "L: \(.["front-left"].value_percent), R: \(.["front-right"].value_percent)"')"

    selection="$(echo -e "$options" | __select 3 "$volume" "$preselection")"

    case "$selection" in
      "+5") preselection=0 ;;
      "+10") preselection=1 ;;
      "+20") preselection=2 ;;
      "-5") preselection=3 ;;
      "-10") preselection=4 ;;
      "-20") preselection=5 ;;
      *) return ;;
    esac

    pactl set-source-volume "$id" "${selection}%"
  done
}

__audio_source_submenu() {
  declare preselection

  id="$1"

  while true; do
    source="$(__audio_find_source "$id")"

    prompt="$(echo "$source" | jq -r '.description')"
    muted="$(echo "$source" | jq -r '.mute')"
    volume="$(echo "$source" | jq -r '.volume | "L: \(.["front-left"].value_percent), R: \(.["front-right"].value_percent)"')"

    muting_msg="$mute_msg ($muted)"
    voluming_msg="$volume_msg ($volume)"

    options="$default_msg\n$muting_msg\n$voluming_msg"

    selection="$(echo -e "$options" | __select 3 "$prompt" "$preselection")"

    case "$selection" in
      '') return ;;
      "$default_msg")
        pactl set-default-source "$id"
        preselection=0
      ;;
      "$mute_msg"*)
        pactl set-source-mute "$id" toggle
        preselection=1
      ;;
      "$volume_msg"*)
        __audio_source_volume_submenu "$id"
        preselection=2
      ;;
    esac
  done
}

__audio_sources_submenu() {
  declare preselection

  sources="$(pactl -f json list sources | jq -r 'sort_by(.description) | reverse | to_entries | .[] | "\(.value.description)>\(.key)@\(.value.index)"')"

  while true; do
    source="$(__audio_find_default_source)"
    prompt="$(echo "$source" | jq -r '.description')"

    selection="$(echo "$sources" | __select 3 "${prompt:-$sources_msg}" "$preselection")"

    [ -n "$selection" ] || return

    id="$(echo "$selection" | awk -F '@' '{print $2}')"
    preselection="$(echo "$selection" | awk -F '@' '{print $1}')"

    __audio_source_submenu "$id"
  done
}

__audio_sink_volume_submenu() {
  declare preselection

  id="$1"
  options="+5\n+10\n+20\n-5\n-10\n-20"

  while true; do
    sink="$(__audio_find_sink "$id")"

    volume="$(echo "$sink" | jq -r '.volume | "L: \(.["front-left"].value_percent), R: \(.["front-right"].value_percent)"')"

    selection="$(echo -e "$options" | __select 3 "$volume" "$preselection")"

    case "$selection" in
      "+5") preselection=0 ;;
      "+10") preselection=1 ;;
      "+20") preselection=2 ;;
      "-5") preselection=3 ;;
      "-10") preselection=4 ;;
      "-20") preselection=5 ;;
      *) return ;;
    esac

    pactl set-sink-volume "$id" "${selection}%"
  done
}

__audio_sink_submenu() {
  declare preselection

  id="$1"

  while true; do
    sink="$(__audio_find_sink "$id")"

    prompt="$(echo "$sink" | jq -r '.description')"
    muted="$(echo "$sink" | jq -r '.mute')"
    volume="$(echo "$sink" | jq -r '.volume | "L: \(.["front-left"].value_percent), R: \(.["front-right"].value_percent)"')"

    muting_msg="$mute_msg ($muted)"
    voluming_msg="$volume_msg ($volume)"

    options="$default_msg\n$muting_msg\n$voluming_msg"

    selection="$(echo -e "$options" | __select 3 "$prompt" "$preselection")"

    case "$selection" in
      '') return ;;
      "$default_msg")
        pactl set-default-sink "$id"
        preselection=0
      ;;
      "$mute_msg"*)
        pactl set-sink-mute "$id" toggle
        preselection=1
      ;;
      "$volume_msg"*)
        __audio_sink_volume_submenu "$id"
        preselection=2
      ;;
    esac
  done
}

__audio_sinks_submenu() {
  declare preselection

  sinks="$(pactl -f json list sinks | jq -r 'sort_by(.description) | reverse | to_entries | .[] | "\(.value.description)>\(.key)@\(.value.name)"')"

  while true; do
    sink="$(__audio_find_default_sink)"

    prompt="$(echo "$sink" | jq -r '.description')"

    selection="$(echo "$sinks" | __select 3 "${prompt:-$sinks_msg}" "$preselection")"

    [ -n "$selection" ] || return

    id="$(echo "$selection" | awk -F '@' '{print $2}')"
    preselection="$(echo "$selection" | awk -F '@' '{print $1}')"

    __audio_sink_submenu "$id"
  done
}

__audio_sink_input_redirect_submenu() {
  declare preselection

  id="$1"
  sinks="$(pactl -f json list sinks | jq -r 'sort_by(.description) | reverse | to_entries | .[] | "\(.value.description)>\(.key)@\(.value.name)"')"

  while true; do
    selection="$(echo "$sinks" | __select 3 "${prompt:-$sinks_msg}" "$preselection")"

    [ -n "$selection" ] || return

    sink="$(echo "$selection" | awk -F '@' '{print $2}')"
    preselection="$(echo "$selection" | awk -F '@' '{print $1}')"

    pactl move-sink-input "$id" "$sink"
  done
}

__audio_sink_input_volume_submenu() {
  declare preselection

  id="$1"
  options="+5\n+10\n+20\n-5\n-10\n-20"

  while true; do
    sink_input="$(__audio_find_sink_input "$id")"

    volume="$(echo "$sink_input" | jq -r '.volume | "L: \(.["front-left"].value_percent), R: \(.["front-right"].value_percent)"')"

    selection="$(echo -e "$options" | __select 3 "$volume" "$preselection")"

    case "$selection" in
      "+5") preselection=0 ;;
      "+10") preselection=1 ;;
      "+20") preselection=2 ;;
      "-5") preselection=3 ;;
      "-10") preselection=4 ;;
      "-20") preselection=5 ;;
      *) return ;;
    esac

    pactl set-sink-input-volume "$id" "${selection}%"
  done
}

__audio_sink_input_submenu() {
  declare preselection

  id="$1"

  while true; do
    sink_input="$(__audio_find_sink_input "$id")"

    prompt="$(echo "$sink_input" | jq -r '.properties.["application.name"]')"
    muted="$(echo "$sink_input" | jq -r '.mute')"
    volume="$(echo "$sink_input" | jq -r '.volume | "L: \(.["front-left"].value_percent), R: \(.["front-right"].value_percent)"')"

    muting_msg="$mute_msg ($muted)"
    voluming_msg="$volume_msg ($volume)"

    options="$redirect_msg\n$muting_msg\n$voluming_msg"
    selection="$(echo -e "$options" | __select 3 "$prompt" "$preselection")"

    case "$selection" in
      '') return ;;
      "$redirect_msg")
        __audio_sink_input_redirect_submenu "$id"
        preselection=0
      ;;
      "$mute_msg"*)
        pactl set-sink-input-mute "$id" toggle
        preselection=1
      ;;
      "$volume_msg"*)
        __audio_sink_input_volume_submenu "$id"
        preselection=2
      ;;
    esac
  done

}

__audio_sink_inputs_submenu() {
  declare preselection

  sink_inputs="$(pactl -f json list sink-inputs | jq -r 'to_entries | .[] | "\(.value.properties.["application.name"])>\(.key)@\(.value.index)"')"

  while true; do
    selection="$(echo "$sink_inputs" | __select 3 "$sink_inputs_msg" "$preselection")"

    [ -n "$selection" ] || return

    id="$(echo "$selection" | awk -F '@' '{print $2}')"
    preselection="$(echo "$selection" | awk -F '@' '{print $1}')"

    __audio_sink_input_submenu "$id"
  done
}

__audio_main() {
  declare preselection

  while true; do
    options="$sinks_msg\n$sink_inputs_msg\n$sources_msg"
    selection="$(echo -e "$options" | __select 3 "$main_prompt" "$preselection")"

    case "$selection" in
      '') exit 0;;
      "$sinks_msg")
        __audio_sinks_submenu
        preselection=0
      ;;
      "$sink_inputs_msg")
        __audio_sink_inputs_submenu
        preselection=1
      ;;
      "$sources_msg")
        __audio_sources_submenu
        preselection=2
      ;;
    esac
  done
}

__audio_main
