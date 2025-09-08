#!/usr/bin/env bash
set -e

#MISE alias="dc"
#MISE description="Connect to Claude Code devcontainer"
#USAGE flag "--clean" help="Start by cleaning the container"

# Get workspace root directory
WORKSPACE_ROOT="$(pwd)"

# Set default path to ${HOME} in workspace
export CLAUDE_BIND_DIR="${CLAUDE_BIND_DIR:-$HOME}"

echo "🤖 Connecting to Claude Code devcontainer..."
echo "💾 Data location: $CLAUDE_BIND_DIR"

# Check if devcontainer is running
echo "📦 Checking devcontainer status..."
CONFIG_FILE="${CONFIG_FILE:-.devcontainer/claude-code/devcontainer.json}"

CONTAINER_RUNNING=false
if devcontainer exec --workspace-folder . --config "$CONFIG_FILE" echo "test" &>/dev/null; then
  CONTAINER_RUNNING=true
fi

echo "$usage_clean"
echo "$CONTAINER_RUNNING"

if [ "$usage_clean" = "true" ] || [ "$CONTAINER_RUNNING" = "false" ]; then
  echo "📦 Starting devcontainer..."

  DEVCONTAINER_UP_ARGS=(
    "up"
    "--workspace-folder" "."
    "--config" "$CONFIG_FILE"
  )

  if [ "$usage_clean" = "true" ]; then
    echo "🔄 Rebuilding container..."
    DEVCONTAINER_UP_ARGS+=("--remove-existing-container")
  fi

  if ! devcontainer "${DEVCONTAINER_UP_ARGS[@]}"; then
    echo "❌ Failed to start devcontainer"
    exit 1
  fi

  # Wait for initialization
  echo "⏳ Waiting for devcontainer initialization..."
  sleep 3

  # Verify permissions on first start
  echo "🔐 Verifying permissions..."
  devcontainer exec --workspace-folder . --config "$CONFIG_FILE" bash -c '
    if [ -d "$HOME/.claude" ]; then
      echo "✅ .claude directory: $(ls -ld $HOME/.claude | awk "{print \$3}")"
    fi
    if [ -f "$HOME/.claude.json" ]; then
      echo "✅ .claude.json file: $(ls -l $HOME/.claude.json | awk "{print \$3}")"
    fi
  '
else
  echo "✅ Devcontainer is already running"
fi

# Test connection
if ! devcontainer exec --workspace-folder . --config "$CONFIG_FILE" echo "Connection test" &>/dev/null; then
  echo "❌ Failed to connect to devcontainer"
  echo "💡 Try running manually: devcontainer up --workspace-folder . --config $CONFIG_FILE"
  exit 1
fi

# Check Claude Code status
echo ""
echo "🔍 Checking Claude Code environment..."
devcontainer exec --workspace-folder . --config "$CONFIG_FILE" bash -c '
  if command -v claude &>/dev/null; then
    CLAUDE_VERSION=$(claude --version 2>&1 | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" | head -1 || echo "unknown")
    echo "✅ Claude Code: Installed (v$CLAUDE_VERSION)"
    # Check configuration files
    if [ -d "$HOME/.claude" ] && [ -f "$HOME/.claude.json" ]; then
      echo "✅ Configuration files: Ready"
      # Count saved sessions if any exist
      if [ -d "$HOME/.claude" ] && [ -n "$(find $HOME/.claude -name "*.json" 2>/dev/null)" ]; then
        SESSION_COUNT=$(find $HOME/.claude -name "*.json" 2>/dev/null | wc -l)
        echo "📊 Saved sessions: $SESSION_COUNT"
      fi
    else
      echo "⚠️  Configuration files: Will be created on first run"
    fi
  else
    echo "❌ Claude Code: Not installed"
    echo "💡 Run this inside the container:"
    echo "   npm install -g @anthropic-ai/claude-code"
  fi
'

echo ""
echo "✅ Connected successfully!"
echo "💾 Data persisted at:"
echo "   Host: $CLAUDE_BIND_DIR"
echo "   Container: /home/vscode/.claude*"
echo ""
echo "💡 Usage:"
echo "   claude              - Start Claude Code"
echo "   claude --help       - Show help"
echo "   exit               - Exit container"
echo ""
if [ "$CLAUDE_BIND_DIR" = "$WORKSPACE_ROOT/.claude-config" ]; then
  echo "📝 Using default storage location"
  echo "   To use custom path:"
  echo "   CLAUDE_BIND_DIR=/path/to/dir ./claude-dev.sh"
fi
echo ""

# Start interactive bash session
devcontainer exec --workspace-folder . --config "$CONFIG_FILE" /bin/bash
