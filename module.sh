#!/bin/sh

# shellcheck disable=SC2034
MODULESH_VERSION=0.1.0

# shellcheck disable=SC2039
_PROXY(){ local _; }
if _PROXY 2>/dev/null; then
  # checking $# in $func() to avoid https://bugs.debian.org/861743
  eval '_PROXY() {
    local func=${1%:*} to=${1#*:} local="local IFS"; shift
    while [ $# -gt 0 ]; do local="$local $1="; shift; done
    [ "$func" = "$to" ] && to=_$to
    eval "$func() { $local; if [ \$# -gt 0 ]; then $to \"\$@\"; else $to; fi; }"
  }'
else
  eval 'function _PROXY {
    typeset func=${1%:*} to=${1#*:} local="typeset IFS"; shift
    while [ $# -gt 0 ]; do local="$local $1="; shift; done
    [ "$func" = "$to" ] && to=_$to
    eval "function $func { $local; $to \"\$@\"; }"
  }'
fi

_PROXY IMPORT module modname prefix exports func alias defname chunk
_PROXY DEPENDS prefix chunk

# Usage: IMPORT <module>[:<prefix>] [<func[:<alias>]>...]
_IMPORT() {
  path='' module=${1%%:*} prefix=${1#*:} IFS=' ' exports=''
  case ${module%/*} in *[!a-zA-Z0-9/]*)
    echo "ERROR: Namespace allows only character [a-zA-Z0-9/] in $path" >&2
    exit 1
  esac
  case ${module##*/} in *[!a-zA-Z0-9_]*)
    echo "ERROR: Module allows only character [a-zA-Z0-9_] in $path" >&2
    exit 1
  esac

  [ "$module" = "$prefix" ] && prefix=${module##*/}
  shift

  chunk="$module/" modname=''
  while [ "$chunk" ]; do
    modname=${modname}${modname:+_}${chunk%%/*} chunk=${chunk#*/}
  done

  if eval [ -z "\${$modname+x}" ]; then
    if [ -z "$SH_MODULE_DIR" ]; then
      echo 'ERROR: SH_MODULE_DIR variable not set' >&2
      exit 1
    fi
    chunk=$SH_MODULE_DIR:
    while [ "$chunk" ]; do
      path=${chunk%%:*} chunk=${chunk#*:}
      [ "$path" ] && [ -f "$path/$module.sh" ] && break
    done
    if [ -z "$path" ]; then
      echo "ERROR: Module '$module' not found" >&2
      exit 1
    fi
    # shellcheck disable=SC1090
    . "$path/$module.sh"
    $modname
  fi

  eval "exports=\$${modname}"
  [ $# -eq 0 ] && eval "set -- $exports"

  for func in "$@"; do
    case $func in
      *:*) alias=${func#*:} func=${func%:*} ;;
      *) alias=''
    esac
    [ "$alias" ] && defmodname=$alias || defmodname=${prefix}${prefix:+_}$func
    if [ "$exports" = "${exports#* $func}" ]; then
      echo "ERROR: '$func' is not exported at $module." >&2
      exit 1
    fi
    [ "${defmodname}" = "${modname}_${func}" ] && continue
    eval "${defmodname}() { ${modname}_${func} \"\$@\"; }"
  done
}

# Usage: EXPORT <func> [<variable-modnames>...]
EXPORT() {
  eval "$modname=\"\${$modname:-} $1\""
  eval "_PROXY ${modname}_$*"
}

# Usage: DEPENDS <module>...
_DEPENDS() {
  while [ $# -gt 0 ]; do
    chunk="$1/" prefix=''
    while [ "$chunk" ]; do
      prefix=${prefix}${prefix:+_}${chunk%%/*} chunk=${chunk#*/}
    done
    IMPORT "$1:$prefix"
    shift
  done
}
