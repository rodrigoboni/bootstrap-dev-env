#!/usr/bin/env bash

set -e

ZSHRC="$HOME/.zshrc"

# Load SDKMAN if present
if [ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
    source "$HOME/.sdkman/bin/sdkman-init.sh"
fi

echo "🔍 Detecting installed Java versions..."

# -----------------------------
# SDKMAN FLOW
# -----------------------------
if command -v sdk >/dev/null 2>&1; then
    echo "Using SDKMAN..."

    mapfile -t raw_versions < <(sdk list java | grep -E "installed|local only")

    if [ ${#raw_versions[@]} -gt 0 ]; then
        echo ""
        echo "Available Java versions:"

        versions=()
        for i in "${!raw_versions[@]}"; do
            version=$(echo "${raw_versions[$i]}" | awk '{print $NF}')
            label=$(echo "${raw_versions[$i]}" | grep -oE "installed|local only")
            versions+=("$version")

            printf "%d) %s (%s)\n" "$((i+1))" "$version" "$label"
        done

        echo ""
        read -p "Select a version to set as default: " choice

        if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#versions[@]} )); then
            echo "Invalid selection"
            exit 1
        fi

        selected="${versions[$((choice-1))]}"

        echo "Setting default Java to: $selected"
        sdk default java "$selected"

        JAVA_HOME_CANDIDATE="$HOME/.sdkman/candidates/java/current"

        # Update .zshrc
        echo "Updating JAVA_HOME in $ZSHRC..."

        # Remove old JAVA_HOME lines
        sed -i '/export JAVA_HOME=/d' "$ZSHRC"

        # Append new one
        echo "export JAVA_HOME=$JAVA_HOME_CANDIDATE" >> "$ZSHRC"
        echo 'export PATH=$JAVA_HOME/bin:$PATH' >> "$ZSHRC"

        echo "✅ Done (SDKMAN)!"
        echo "👉 Restart your terminal or run: source ~/.zshrc"
        exit 0
    fi
fi

# -----------------------------
# SYSTEM JAVA FLOW
# -----------------------------
echo "Falling back to system Java..."

mapfile -t java_bins < <(update-alternatives --list java)

if [ ${#java_bins[@]} -eq 0 ]; then
    echo "No Java versions found."
    exit 1
fi

echo ""
echo "Available Java versions:"
for i in "${!java_bins[@]}"; do
    printf "%d) %s\n" "$((i+1))" "${java_bins[$i]}"
done

echo ""
read -p "Select a version to set as default: " choice

if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#java_bins[@]} )); then
    echo "Invalid selection"
    exit 1
fi

selected_java="${java_bins[$((choice-1))]}"
java_home="$(dirname "$(dirname "$selected_java")")"

echo "Setting JAVA_HOME to: $java_home"

tools=(java javac jar javadoc javap)

for tool in "${tools[@]}"; do
    if update-alternatives --list "$tool" >/dev/null 2>&1; then
        candidate="$java_home/bin/$tool"
        if [ -f "$candidate" ]; then
            echo "→ Setting $tool"
            sudo update-alternatives --set "$tool" "$candidate"
        fi
    fi
done

# Update .zshrc
echo "Updating JAVA_HOME in $ZSHRC..."

sed -i '/export JAVA_HOME=/d' "$ZSHRC"

echo "export JAVA_HOME=$java_home" >> "$ZSHRC"
echo 'export PATH=$JAVA_HOME/bin:$PATH' >> "$ZSHRC"

echo "✅ Done (system Java)!"
echo "👉 Restart your terminal or run: source ~/.zshrc"
