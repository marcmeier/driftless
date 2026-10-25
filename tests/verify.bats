#!/usr/bin/env bats
# lib/verify.sh: runs through without a user manager (as bootstrap.sh runs it) and counts failures

setup() {
  load helpers
  setup_sandbox
  machine A
}

@test "verify runs to the end without a user session" {
  run dl A verify
  [[ $output == *"== Sync"* ]]
  [[ $output == *" FAIL, "* ]]
  [[ $output == *"no user manager"* ]]
}

@test "verify runs on when find cannot read a folder in the home" {
  mkdir -p "$(home A)/locked/inner" && chmod 000 "$(home A)/locked"
  run dl A verify
  chmod 755 "$(home A)/locked"
  [[ $output == *"== Sync"* ]]
}

@test "verify says when no key can log in with SSH" {
  run dl A verify
  [[ $output == *"no ~/.ssh/authorized_keys"* ]]
  mkdir -p "$(home A)/.ssh" && echo "ssh-ed25519 AAAA test" > "$(home A)/.ssh/authorized_keys"
  run dl A verify
  [[ $output != *"no ~/.ssh/authorized_keys"* ]]
}
