# Codex component

This component installs the shared Codex configuration, delegation and reuse-first skills, agent, and model
profiles. Use the repository-level `install.sh` for normal setup.

The default `scodex` profile uses Sol. Lower-cost profiles are also available:

```bash
scodex --cheap
scodex --normal
scodex --hard
```

The installer does not modify `~/.codex/config.toml`. It maintains a marker-delimited block in
the global AGENTS file and installs namespaced profiles, agent, and skill assets.
