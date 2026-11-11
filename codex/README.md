# Codex component

This component installs the shared Codex configuration, side-task delegation, Markdown compaction,
and reuse-first skills, agent, and Sol profile. Use the repository-level `install.sh` for normal
setup.

The installer does not modify `~/.codex/config.toml`. It maintains a marker-delimited block in
the global AGENTS file and installs a namespaced profile, agent, and skill assets.

`profiles/monke.config.toml` owns active model defaults; `skills/monke-delegate/SKILL.md` owns task
routing. `config.toml` is a frozen legacy ownership fingerprint, including its historical model
names. The installer and uninstaller use it to recognize unchanged legacy assets; do not update
it with active defaults.
