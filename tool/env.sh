#!/usr/bin/env bash
set -euo pipefail
export JAVA_HOME="$HOME/.hermes/toolchains/jdk21"
export ANDROID_HOME="$HOME/.hermes/toolchains/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$HOME/.hermes/toolchains/flutter/bin:$ANDROID_HOME/platform-tools:$PATH"
export GRADLE_USER_HOME="$HOME/.hermes/toolchains/gradle-home"
exec "$@"
