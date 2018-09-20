#!/bin/sh

# shellcheck disable=SC2034
MODULESH_VERSION=0.3.0

_PROXY(){
  $3 _ || return 1
  eval "$1"'_PROXY'"$2"' {
    '"$3"' f=$1 local="'"$3"' IFS" i; shift
    for i in "$@"; do local="$local $i=\"\""; done
    eval "'"$1"'$f'"$2"' { $local; _$f \"\$@\"; }"
  }'
}
_PROXY '' '()' local 2>/dev/null || _PROXY 'function ' '' typeset

_DELEGATE(){
  $3 _ || return 1
  eval "$1"'_DELEGATE'"$2"' {
    '"$3"' source=$1 name=$2 func=$3 local="'"$3"' IFS" i; shift 3
    [ $# -gt 0 ] && for i in "$@"; do local="$local $i=\"\""; done
    eval "'"$1"'$func'"$2"' {
      $local MODULE_SOURCE=\"$source\" MODULE_NAME=\"$name\"
      if [ \$# -gt 0 ]; then _$func \"\$@\"; else _$func; fi
    }"
  }'
}
_DELEGATE '' '()' local 2>/dev/null || _DELEGATE 'function ' '' typeset

_PROXY IMPORT module modns modname prefix exports func alias defname chunk path

# Usage: IMPORT <module>[:<prefix>] [<func[:<alias>]>...]
_IMPORT() {
  module=${1%%:*} modns=${module%/*} modname=${module##*/} IFS=' ' exports=''
  case $modns in *[!a-zA-Z0-9/]*)
    echo "ERROR: Namespace allows only character [a-zA-Z0-9/] in $modns" >&2
    exit 1
  esac
  case $modname in *[!a-zA-Z0-9_]*)
    echo "ERROR: Module allows only character [a-zA-Z0-9_] in $modname" >&2
    exit 1
  esac

  chunk="$modns/" modns=''
  while [ "$chunk" ]; do
    modns=${modns}${modns:+_}${chunk%%/*} chunk=${chunk#*/}
  done

  case $1 in
    *:*) prefix=${1#*:} ;;
    *) prefix=${modns}_${modname}
  esac
  shift

  if eval [ -z "\${${modns}_${modname}+x}" ]; then
    if [ -z "$SH_MODULE_DIR" ]; then
      echo 'ERROR: SH_MODULE_DIR variable not set' >&2
      exit 1
    fi
    chunk="$SH_MODULE_DIR:" MODULE_SOURCE='' MODULE_NAME="${modns}_${modname}"
    while [ "$chunk" ]; do
      path=${chunk%%:*} chunk=${chunk#*:}
      [ "$path" ] || continue
      path=$path/${module%/*}/$modname
      [ -f "$path.sh" ] && MODULE_SOURCE="$path.sh" && break
      [ -f "$path/$modname.sh" ] && MODULE_SOURCE="$path/$modname.sh" && break
    done
    if [ -z "$MODULE_SOURCE" ]; then
      echo "ERROR: Module '$module' not found" >&2
      exit 1
    fi
    # shellcheck disable=SC1090
    . "$MODULE_SOURCE" && $MODULE_NAME
  fi

  eval "exports=\$${modns}_${modname}"
  [ $# -eq 0 ] && eval "set -- $exports"

  for func in "$@"; do
    case $func in
      *:*) alias=${func#*:} func=${func%:*} ;;
      *) alias=''
    esac
    [ "$alias" ] && defname=$alias || defname=${prefix}${prefix:+_}$func
    if [ "$exports" = "${exports#* $func}" ]; then
      echo "ERROR: '$func' is not exported at $module." >&2
      exit 1
    fi
    func="${modns}_${modname}_${func}"
    [ "$defname" = "$func" ] && continue
    # posh: checking $# in $func() to avoid https://bugs.debian.org/861743
    eval "$defname() { if [ \$# -gt 0 ]; then $func \"\$@\"; else $func; fi; }"
  done
}

# Usage: EXPORT <func> [<variable-names>...]
EXPORT() {
  eval "$MODULE_NAME=\"\${$MODULE_NAME:-} $1\""
  # shellcheck disable=SC2145
  _DELEGATE "$MODULE_SOURCE" "$MODULE_NAME" "${MODULE_NAME}_$@"
}

# Usage: DEPENDS <module>...
DEPENDS() {
  while [ $# -gt 0 ]; do IMPORT "$1"; shift; done
}
