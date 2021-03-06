#!/bin/sh

myname_mymodule() {
  DEFAULT_LOCAL default_local_var
  EXPORT foo a b c
  EXPORT bar
  EXPORT baz
  EXPORT change_var local_var
  EXPORT hello
  EXPORT module_info
  EXPORT default_local
}

myname_mymodule_prepare() {
  default_local_var=test
}

_myname_mymodule_foo() {
  echo ok: foo $#
}

_myname_mymodule_bar() {
  echo ok: bar $#
}

_myname_mymodule_baz() {
  echo ok: baz $#
}

_myname_mymodule_change_var() {
  local_var=1
  global_var=1

  echo "local: $local_var, global: $global_var"
}

_myname_mymodule_hello() {
  echo "hello $*"
}

_myname_mymodule_module_info() {
  echo "$MODULE_SOURCE $MODULE_NAME"
}

_myname_mymodule_default_local() {
  echo $default_local_var
}
