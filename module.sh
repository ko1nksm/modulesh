#!/bin/sh

# shellcheck disable=SC2034
MODULESH_VERSION=0.3.0

_PROXY(){
  $3 _ || return 1
  eval "$1"'_PROXY'"$2"' {
    '"$3"' func=${1%:*} to=${1#*:} local="'"$3"' IFS" i; shift
    for i in "$@"; do
      case $i in
        *=*) local="$local ${i%%=*}=\"${i#*=}\"" ;;
        *) local="$local $i=\"\"" ;; # Initialize value for shell compatibility.
      esac
    done
    [ "$func" = "$to" ] && to=_$to
    eval "'"$1"'$func'"$2"' { $local; if [ \$# -gt 0 ]; then $to \"\$@\"; else $to; fi; }"
  }'
}
_PROXY '' '()' local 2>/dev/null || _PROXY 'function ' '' typeset

_PROXY IMPORT module modname prefix exports func alias defname chunk base MODULE_SOURCE MODULE_NAME

# Usage: IMPORT <module>[:<prefix>] [<func[:<alias>]>...]
_IMPORT() {
  module=${1%%:*} IFS=' ' exports=''
  case ${module%/*} in *[!a-zA-Z0-9/]*)
    echo "ERROR: Namespace allows only character [a-zA-Z0-9/] in ${module%/*}" >&2
    exit 1
  esac
  case ${module##*/} in *[!a-zA-Z0-9_]*)
    echo "ERROR: Module allows only character [a-zA-Z0-9_] in ${module##*/}" >&2
    exit 1
  esac

  chunk="$module/" modname=''
  while [ "$chunk" ]; do
    modname=${modname}${modname:+_}${chunk%%/*} chunk=${chunk#*/}
  done

  case $1 in
    *:*) prefix=${1#*:} ;;
    *) prefix=$modname
  esac
  shift

  if eval [ -z "\${$modname+x}" ]; then
    if [ -z "$SH_MODULE_DIR" ]; then
      echo 'ERROR: SH_MODULE_DIR variable not set' >&2
      exit 1
    fi
    chunk="$SH_MODULE_DIR:" MODULE_SOURCE='' MODULE_NAME="$modname"
    while [ "$chunk" ]; do
      base=${chunk%%:*} chunk=${chunk#*:}
      [ "$base" ] || continue
      if [ -f "$base/$module.sh" ]; then
        MODULE_SOURCE="$base/$module.sh" && break
      elif [ -f "$base/$module/${module##*/}.sh" ]; then
        MODULE_SOURCE="$base/$module/${module##*/}.sh" && break
      fi
    done
    if [ -z "$MODULE_SOURCE" ]; then
      echo "ERROR: Module '$module' not found" >&2
      exit 1
    fi
    # shellcheck disable=SC1090
    . "$MODULE_SOURCE" && $MODULE_NAME
  fi

  eval "exports=\$$modname"
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
    func="${modname}_${func}"
    [ "$defname" = "$func" ] && continue
    # posh: checking $# in $func() to avoid https://bugs.debian.org/861743
    eval "$defname() { if [ \$# -gt 0 ]; then $func \"\$@\"; else $func; fi; }"
  done
}

# Usage: EXPORT <func> [<variable-names>...]
EXPORT() {
  eval "$MODULE_NAME=\"\${$MODULE_NAME:-} $1\""
  # shellcheck disable=SC2145
  _PROXY "${MODULE_NAME}_$@" MODULE_SOURCE="$MODULE_SOURCE" MODULE_NAME="$MODULE_NAME"
}

# Usage: DEPENDS <module>...
DEPENDS() {
  while [ $# -gt 0 ]; do IMPORT "$1"; shift; done
}
