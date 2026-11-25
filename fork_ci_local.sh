#!/usr/bin/env bash
# MemNote fork (NOTE-234): the jobs of .github/workflows/pr_validation.yaml and
# build_clones.yaml, run locally on Linux x64. GitHub runs none of them for this fork
# (see "CI" in FORK_PATCHES.md), so a green run of this script is the bar for a fork change.
#
#   bash fork_ci_local.sh <branch or tag, as pushed to the fork> [work directory]
#
# It takes a fresh clone of the pushed branch, as actions/checkout does, and installs the
# Flutter release the workflows pin (FLUTTER_VERSION), as subosito/flutter-action does.
# The SDK, the clone, the pub cache and HOME all live in the work directory, by default
# on tmpfs (/dev/shm/super-editor-ci, about 4 GB), so the run writes nothing to disk and
# touches no SDK or pub cache of the machine. On the MemNote Windows machine:
#
#   wsl.exe -d Ubuntu -- bash /mnt/c/<path to this checkout>/fork_ci_local.sh note-NNN-<slug>
#
# Each job's log is <work directory>/logs/<job>.log and the result of each is a line of
# <work directory>/summary.txt. The exit code is the number of failed jobs.
#
# What it cannot do: build for macOS or iOS. test_mac is not run, and the clones CI builds
# on a Mac are compiled another way here (see the end of this file). test_windows is
# `flutter test` in super_editor/ on the Windows machine.
set -u
BRANCH="${1:?usage: fork_ci_local.sh <branch> [work directory]}"
ROOT="${2:-/dev/shm/super-editor-ci}"
LOGS="$ROOT/logs"
SUMMARY="$ROOT/summary.txt"
FAILED=0

mkdir -p "$ROOT/home"
rm -rf "$LOGS" "$ROOT/src"
mkdir -p "$LOGS"
export HOME="$ROOT/home"
export PUB_CACHE="$ROOT/pub-cache"
export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true
: > "$SUMMARY"

note() { echo "$*" | tee -a "$SUMMARY"; }

git clone --quiet --depth 1 --branch "$BRANCH" https://github.com/donaldheppner/super_editor.git "$ROOT/src" \
  || { note "clone of $BRANCH failed"; exit 99; }
note "head: $(git -C "$ROOT/src" rev-parse HEAD) ($BRANCH)"

FLUTTER_VERSION=$(sed -n 's/^ *FLUTTER_VERSION: *"\(.*\)".*/\1/p' "$ROOT/src/.github/workflows/pr_validation.yaml" | head -1)
[ -n "$FLUTTER_VERSION" ] || { note "no FLUTTER_VERSION in pr_validation.yaml"; exit 99; }

SDK="$ROOT/flutter-$FLUTTER_VERSION"
if [ ! -x "$SDK/bin/flutter" ]; then
  url="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  mkdir -p "$SDK.tmp"
  curl -fsSL "$url" -o "$ROOT/flutter.tar.xz" || { note "SDK download failed: $url"; exit 99; }
  tar -xJf "$ROOT/flutter.tar.xz" -C "$SDK.tmp" || { note "SDK extract failed"; exit 99; }
  rm -f "$ROOT/flutter.tar.xz"
  mv "$SDK.tmp/flutter" "$SDK" && rmdir "$SDK.tmp"
fi
export PATH="$SDK/bin:/usr/local/bin:/usr/bin:/bin"
git config --global --add safe.directory "$SDK" > /dev/null 2>&1
flutter --version > "$LOGS/flutter-version.log" 2>&1
note "sdk: $(head -1 "$LOGS/flutter-version.log")"
note "host: $(uname -m) $(. /etc/os-release; echo "$PRETTY_NAME")"

# step <job> <directory in the checkout> <command...>
step() {
  local name="$1" dir="$2"; shift 2
  local log="$LOGS/$name.log" start=$SECONDS code last
  ( cd "$ROOT/src/$dir" && "$@" ) > "$log" 2>&1
  code=$?
  [ $code -eq 0 ] || FAILED=$((FAILED + 1))
  last=$(tr '\r' '\n' < "$log" | grep -v '^\s*$' | tail -1 | cut -c1-160)
  note "$( [ $code -eq 0 ] && echo PASS || echo FAIL ) | $name | exit=$code | $((SECONDS - start))s | $last"
}

# --- pr_validation.yaml
step pubget_super_editor                  super_editor            flutter pub get
step test_linux                           super_editor            flutter test
step test_goldens_super_editor            super_editor            flutter test test_goldens

step pubget_super_editor_spellcheck       super_editor_spellcheck flutter pub get
step test_super_editor_spellcheck         super_editor_spellcheck flutter test
step test_super_editor_spellcheck_goldens super_editor_spellcheck flutter test test_goldens

step pubget_super_editor_clipboard        super_editor_clipboard  flutter pub get
step analyze_super_editor_clipboard       super_editor_clipboard  flutter analyze --no-fatal-infos
step test_super_editor_clipboard          super_editor_clipboard  flutter test

step pubget_super_keyboard                super_keyboard          flutter pub get
step analyze_super_keyboard               super_keyboard          flutter analyze --no-fatal-infos
step test_super_keyboard                  super_keyboard          flutter test
step test_goldens_super_keyboard          super_keyboard          flutter test test_goldens

step pubget_super_text_layout             super_text_layout       flutter pub get
step analyze_super_text_layout            super_text_layout       flutter analyze --no-fatal-infos
step test_super_text_layout               super_text_layout       flutter test
step test_goldens_super_text_layout       super_text_layout       flutter test test_goldens

step pubget_attributed_text               attributed_text         dart pub get
step analyze_attributed_text              attributed_text         dart analyze
step test_attributed_text                 attributed_text         dart test

step pubget_docs_website                  doc/website             dart pub get
step build_docs_website                   doc/website             dart run bin/super_editor_docs.dart

# --- build_clones.yaml. CI builds each clone on a Mac, for macOS, web or iOS. Here: each
# clone's tests where it has any, the web build for the two that have a web/ directory
# (medium's is CI's own step), and for the rest `flutter build bundle`, which compiles the
# Dart and leaves out only the native shell. google_docs cannot take the bundle route: a
# build hook of one of its dependencies asks for the Android SDK.
for clone in bear google_docs medium obsidian quill slack ios_messenger; do
  step "pubget_$clone" "super_clones/$clone" flutter pub get
done
step build_medium                         super_clones/medium        flutter build web --debug
step build_google_docs                    super_clones/google_docs   flutter build web --debug
step test_obsidian                        super_clones/obsidian      flutter test
step test_quill                           super_clones/quill         flutter test
for clone in bear obsidian quill slack ios_messenger; do
  step "build_$clone" "super_clones/$clone" flutter build bundle --debug
done

note "failed: $FAILED"
exit "$FAILED"
