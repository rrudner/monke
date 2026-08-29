# Codex component

This component installs the shared Codex configuration, side-task delegation, Markdown compaction,
and reuse-first skills, agent, and Sol profile. Use the repository-level `install.sh` for normal
setup.

The installer does not modify `~/.codex/config.toml`. It maintains a marker-delimited block in
the global AGENTS file and installs a namespaced profile, agent, and skill assets.
