# Store zsh history in the devcontainer's persistent volume.
export HISTFILE=/persist/zsh/history

# Load workspace-specific interactive zsh hooks.
for workspace_hook in /workspace/.devcontainer/zshrc.d/*.zsh(N); do
    source "$workspace_hook"
done
unset workspace_hook
