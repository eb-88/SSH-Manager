#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
mkdir -p "$scratch/home" "$scratch/bin"
export HOME="$scratch/home" MOCK_LOG="$scratch/log"
export PATH="$scratch/bin:$PATH"
checkout="$HOME/.local/share/ssh-manager"
launcher="$HOME/.local/bin/ssh-manager"

cat > "$scratch/bin/git" <<'GIT'
#!/usr/bin/env bash
set -euo pipefail
if [[ $1 == clone ]]; then
    dest=${!#}
    mkdir -p -- "$dest/.git"
    cat > "$dest/ssh-manager.sh" <<'V1'
#!/usr/bin/env bash
printf 'v1\n' >> "$MOCK_LOG"
V1
elif [[ $1 == -C && $3 == pull && $4 == --ff-only ]]; then
    [[ ${MOCK_FAIL_PULL:-0} != 1 ]] || exit 1
    cat > "$2/ssh-manager.sh" <<'V2'
#!/usr/bin/env bash
printf 'v2\n' >> "$MOCK_LOG"
V2
else
    printf 'Unexpected git command: %s\n' "$*" >&2
    exit 1
fi
GIT
chmod +x "$scratch/bin/git"

bash "$root/install.sh" > "$scratch/screen"
[[ -f "$checkout/.git/../ssh-manager.sh" && -x "$launcher" ]]
[[ $(cat "$MOCK_LOG") == v1 ]]

mkdir -p "$HOME/.ssh/ssh-manager"
printf 'preserve me\n' > "$HOME/.ssh/ssh-manager/language"
printf 'n\n' | bash "$root/install.sh" > "$scratch/screen" 2>&1
grep -Fq 'not changed' "$scratch/screen"
[[ $(cat "$MOCK_LOG") == v1 ]]
grep -Fq "v1" "$launcher"

printf 'y\n' | bash "$root/install.sh" > "$scratch/screen" 2>&1
[[ $(cat "$MOCK_LOG") == $'v1\nv2' ]]
grep -Fq "v2" "$launcher"
[[ $(cat "$HOME/.ssh/ssh-manager/language") == 'preserve me' ]]

if printf 'y\n' | MOCK_FAIL_PULL=1 bash "$root/install.sh" > "$scratch/screen" 2>&1; then
    echo 'Failed git update incorrectly succeeded' >&2
    exit 1
fi
grep -Fq "v2" "$launcher"
[[ $(cat "$MOCK_LOG") == $'v1\nv2' ]]

rm -rf -- "$checkout/.git"
if printf 'y\n' | bash "$root/install.sh" > "$scratch/screen" 2>&1; then
    echo 'Non-Git directory was overwritten' >&2
    exit 1
fi
grep -Fq 'not an SSH Manager Git checkout' "$scratch/screen"
[[ $(cat "$MOCK_LOG") == $'v1\nv2' ]]
printf 'Installer tests passed.\n'
