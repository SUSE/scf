#!/usr/bin/env bash

has_release() {
  helm list | awk 'NR>1 { print $1 }' | grep --quiet --word-regexp "${1}"
  echo $?
}
