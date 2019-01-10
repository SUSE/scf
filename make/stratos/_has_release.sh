#!/usr/bin/env bash

has_release() {
  helm list | grep --quiet "${1}"
  echo $?
}
