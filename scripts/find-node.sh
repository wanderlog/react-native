#!/bin/bash
# Copyright (c) Facebook, Inc. and its affiliates.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

# Added fix from https://github.com/facebook/react-native/issues/31259#issuecomment-814949865
# for error message:
#
# > /bin/sh -c .../Debug-iphonesimulator/FBReactNativeSpec.build/Script-F45532E0C9BBF654A0883132EA6E54FB.sh
# > nvm is not compatible with the "PREFIX" environment variable: currently set
# > to "/usr/local"
# > Run `unset PREFIX` to unset it.
#
# > Command PhaseScriptExecution failed with a nonzero exit code
# > PhaseScriptExecution [CP-User]\ Generate\ Specs
# > .../FBReactNativeSpec.build/Script-F45532E0C9BBF654A0883132EA6E54FB.sh
unset npm_config_prefix
unset PREFIX

set -e


# Define NVM_DIR and source the nvm.sh setup script
[ -z "$NVM_DIR" ] && export NVM_DIR="$HOME/.nvm"

if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
  # shellcheck source=/dev/null
  . "$HOME/.nvm/nvm.sh"
elif [[ -x "$(command -v brew)" && -s "$(brew --prefix nvm)/nvm.sh" ]]; then
  # shellcheck source=/dev/null
  . "$(brew --prefix nvm)/nvm.sh"
fi

# Set up the nodenv node version manager if present
if [[ -x "$HOME/.nodenv/bin/nodenv" ]]; then
  eval "$("$HOME/.nodenv/bin/nodenv" init -)"
elif [[ -x "$(command -v brew)" && -x "$(brew --prefix nodenv)/bin/nodenv" ]]; then
  eval "$("$(brew --prefix nodenv)/bin/nodenv" init -)"
fi

# Set up the ndenv of anyenv if preset
if [[ ! -x node && -d ${HOME}/.anyenv/bin ]]; then
  export PATH=${HOME}/.anyenv/bin:${PATH}
  if [[ "$(anyenv envs | grep -c ndenv )" -eq 1 ]]; then
    eval "$(anyenv init -)"
  fi
fi
