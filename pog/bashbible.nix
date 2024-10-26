# bash bible functions implemented as a set of attribute sets in nix
# https://github.com/dylanaraps/pure-bash-bible
{ pkgs, ... }:
let
  inherit (pkgs.lib) attrValues concatStrings;
in
rec {
  functions = {
    strings = {
      trim_string = ''
        trim_string() {
          # Usage: trim_string "   example   string    "
          : "''${1#"''${1%%[![:space:]]*}"}"
          : "''${_%"''${_##*[![:space:]]}"}"
          printf '%s\n' "$_"
        }
      '';
      trim_all = ''
        # shellcheck disable=SC2086,SC2048
        trim_all() {
          # Usage: trim_all "   example   string    "
          set -f
          set -- $*
          printf '%s\n' "$*"
          set +f
        }
      '';
      regex = ''
        regex() {
          # Usage: regex "string" "regex"
          [[ $1 =~ $2 ]] && printf '%s\n' "''${BASH_REMATCH[1]}"
        }
      '';
      split = ''
        split() {
          # Usage: split "string" "delimiter"
          IFS=$'\n' read -d "" -ra arr <<< "''${1//$2/$'\n'}"
          printf '%s\n' "''${arr[@]}"
        }
      '';
      lower = ''
        lower() {
          # Usage: lower "string"
          printf '%s\n' "''${1,,}"
        }
      '';
      upper = ''
        upper() {
          # Usage: upper "string"
          printf '%s\n' "''${1^^}"
        }
      '';
      reverse_case = ''
        reverse_case() {
          # Usage: reverse_case "string"
          printf '%s\n' "''${1~~}"
        }
      '';
      trim_quotes = ''
        trim_quotes() {
          # Usage: trim_quotes "string"
          : "''${1//\'}"
          printf '%s\n' "''${_//\"}"
        }
      '';
      strip_all = ''
        strip_all() {
          # Usage: strip_all "string" "pattern"
          printf '%s\n' "''${1//$2}"
        }
      '';
      strip = ''
        strip() {
          # Usage: strip "string" "pattern"
          printf '%s\n' "''${1/$2}"
        }
      '';
      lstrip = ''
        # shellcheck disable=SC2295
        lstrip() {
          # Usage: lstrip "string" "pattern"
          printf '%s\n' "''${1##$2}"
        }
      '';
      rstrip = ''
        # shellcheck disable=SC2295
        rstrip() {
          # Usage: rstrip "string" "pattern"
          printf '%s\n' "''${1%%$2}"
        }
      '';
      urlencode = ''
        urlencode() {
          # Usage: urlencode "string"
          local LC_ALL=C
          for (( i = 0; i < ''${#1}; i++ )); do
            : "''${1:i:1}"
            case "$_" in
              [a-zA-Z0-9.~_-])
                  printf '%s' "$_"
              ;;

              *)
                  printf '%%%02X' "'$_"
              ;;
            esac
          done
          printf '\n'
        }
      '';
      urldecode = ''
        urldecode() {
          # Usage: urldecode "string"
          : "''${1//+/ }"
          printf '%b\n' "''${_//%/\\x}"
        }
      '';
    };
    arrays = {
      reverse_array = ''
        reverse_array() {
          # Usage: reverse_array "array"
          shopt -s extdebug
          f()(printf '%s\n' "''${BASH_ARGV[@]}"); f "$@"
          shopt -u extdebug
        }
      '';
      remove_array_dups = ''
        remove_array_dups() {
          # Usage: remove_array_dups "array"
          declare -A tmp_array

          for i in "$@"; do
              [[ $i ]] && IFS=" " tmp_array["''${i:- }"]=1
          done

          printf '%s\n' "''${!tmp_array[@]}"
        }
      '';
      random_array_element = ''
        random_array_element() {
          # Usage: random_array_element "array"
          local arr=("$@")
          printf '%s\n' "''${arr[RANDOM % $#]}"
        }
      '';
      cycle = ''
        cycle() {
          printf '%s ' "''${arr[''${i:=0}]}"
          ((i=i>=''${#arr[@]}-1?0:++i))
        }
      '';
    };
    files = {
      head = ''
        head() {
          # Usage: head "n" "file"
          mapfile -tn "$1" line < "$2"
          printf '%s\n' "''${line[@]}"
        }
      '';
      tail = ''
        tail() {
          # Usage: tail "n" "file"
          mapfile -tn 0 line < "$2"
          printf '%s\n' "''${line[@]: -$1}"
        }
      '';
      lines = ''
        lines() {
          # Usage: lines "file"
          mapfile -tn 0 lines < "$1"
          printf '%s\n' "''${#lines[@]}"
        }
      '';
      count = ''
        count() {
          # Usage: count /path/to/dir/*
          #        count /path/to/dir/*/
          printf '%s\n' "$#"
        }
      '';
      extract = ''
        extract() {
          # Usage: extract file "opening marker" "closing marker"
          while IFS=$'\n' read -r line; do
            [[ $extract && $line != "$3" ]] &&
              printf '%s\n' "$line"

            [[ $line == "$2" ]] && extract=1
            [[ $line == "$3" ]] && extract=
          done < "$1"
        }
      '';
    };
    paths = {
      dirname = ''
        dirname() {
          # Usage: dirname "path"
          local tmp=''${1:-.}

          [[ $tmp != *[!/]* ]] && {
            printf '/\n'
            return
          }

          tmp=''${tmp%%"''${tmp##*[!/]}"}

          [[ $tmp != */* ]] && {
            printf '.\n'
            return
          }

          tmp=''${tmp%/*}
          tmp=''${tmp%%"''${tmp##*[!/]}"}

          printf '%s\n' "''${tmp:-/}"
        }
      '';
      basename = ''
        basename() {
          # Usage: basename "path" ["suffix"]
          local tmp

          tmp=''${1%"''${1##*[!/]}"}
          tmp=''${tmp##*/}
          tmp=''${tmp%"''${2/"$tmp"}"}

          printf '%s\n' "''${tmp:-/}"
        }
      '';
    };
    terminal = {
      get_term_size = ''
        get_term_size() {
          # Usage: get_term_size

          # (:;:) is a micro sleep to ensure the variables are
          # exported immediately.
          shopt -s checkwinsize; (:;:)
          printf '%s\n' "$LINES $COLUMNS"
        }
      '';
      get_window_size = ''
        # shellcheck disable=SC2141
        get_window_size() {
          # Usage: get_window_size
          printf '%b' "''${TMUX:+\\ePtmux;\\e}\\e[14t''${TMUX:+\\e\\\\}"
          IFS=';t' read -d t -t 0.05 -sra term_size
          printf '%s\n' "''${term_size[1]}x''${term_size[2]}"
        }
      '';
      get_cursor_pos = ''
        get_cursor_pos() {
          # Usage: get_cursor_pos
          IFS='[;' read -p $'\e[6n' -d R -rs _ y x _
          printf '%s\n' "$x $y"
        }
      '';
    };
    conversion = {
      hex_to_rgb = ''
        hex_to_rgb() {
          # Usage: hex_to_rgb "#FFFFFF"
          #        hex_to_rgb "000000"
          : "''${1/\#}"
          ((r=16#''${_:0:2},g=16#''${_:2:2},b=16#''${_:4:2}))
          printf '%s\n' "$r $g $b"
        }
      '';
      rgb_to_hex = ''
        rgb_to_hex() {
          # Usage: rgb_to_hex "r" "g" "b"
          printf '#%02x%02x%02x\n' "$1" "$2" "$3"
        }
      '';
    };
    other = {
      read_sleep = ''
        read_sleep() {
          # Usage: read_sleep 1
          #        read_sleep 0.2
          read -rt "$1" <> <(:) || :
        }
      '';
      date = ''
        date() {
          # Usage: date "format"
          # See: 'man strftime' for format.
          printf "%($1)T\\n" "-1"
        }
      '';
      uuid = ''
        uuid() {
          # Usage: uuid
          C="89ab"

          for ((N=0;N<16;++N)); do
            B="$((RANDOM%256))"

            case "$N" in
              6)  printf '4%x' "$((B%16))" ;;
              8)  printf '%c%x' "''${C:$RANDOM%''${#C}:1}" "$((B%16))" ;;

              3|5|7|9)
                printf '%02x-' "$B"
              ;;

              *)
                printf '%02x' "$B"
              ;;
            esac
          done

          printf '\n'
        }
      '';
      bar = ''
        bar() {
          # Usage: bar 1 10
          #            ^----- Elapsed Percentage (0-100).
          #               ^-- Total length in chars.
          ((elapsed=$1*$2/100))

          # Create the bar with spaces.
          printf -v prog  "%''${elapsed}s"
          printf -v total "%$(($2-elapsed))s"

          printf '%s\r' "[''${prog// /-}''${total}]"
        }
      '';
      get_functions = ''
        get_functions() {
          # Usage: get_functions
          IFS=$'\n' read -d "" -ra functions < <(declare -F)
          printf '%s\n' "''${functions[@]//declare -f }"
        }
      '';
      bkr = ''
        bkr() {
          (nohup "$@" &>/dev/null &)
        }
      '';
    };
  };

  bible = ''
    ## bash bible
    ### strings
    ${concatStrings (attrValues functions.strings)}
    ### arrays
    ${concatStrings (attrValues functions.arrays)}
    ### files
    ${concatStrings (attrValues functions.files)}
    ### paths
    ${concatStrings (attrValues functions.paths)}
    ### terminal
    ${concatStrings (attrValues functions.terminal)}
    ### conversion
    ${concatStrings (attrValues functions.conversion)}
    ### other
    ${concatStrings (attrValues functions.other)}
    ## end bash bible
  '';
}
