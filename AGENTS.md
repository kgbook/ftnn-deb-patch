# Repository Guidelines

## Project Structure & Module Organization

This repository is intentionally small. `patch_ftnn_deb.py` is the Python implementation of the FTNN `.deb` patcher, and `patch_ftnn_deb.sh` is the Bash entrypoint with the same behavior. `README.md` and `README.en.md` are the primary user docs and should stay aligned when behavior or examples change. There is no dedicated `tests/` directory; validation is currently done with syntax checks and manual package patching against a sample `.deb`.

## Build, Test, and Development Commands

Use the scripts directly from the repo root:

```bash
./patch_ftnn_deb.sh FTNN_desktop.deb
./patch_ftnn_deb.py FTNN_desktop.deb
python3 -m py_compile patch_ftnn_deb.py
bash -n patch_ftnn_deb.sh
```

The first two commands generate a patched package beside the original file, typically named `*_patched.deb`. Use `python3 -m py_compile` to catch Python syntax issues and `bash -n` to validate shell syntax before submitting changes.

## Coding Style & Naming Conventions

Follow the existing style in each script. For Python, use 4-space indentation, standard library only, `pathlib.Path`, and `snake_case` for functions such as `patch_preinst()` and `derive_output_path()`. For Bash, keep `set -euo pipefail`, prefer quoted variables, and use lowercase function names. Keep log/output text explicit because these scripts are often run manually during package troubleshooting.

## Testing Guidelines

There is no automated test suite yet, so every change should include lightweight validation:

- Run `python3 -m py_compile patch_ftnn_deb.py`
- Run `bash -n patch_ftnn_deb.sh`
- Patch a known FTNN package and verify the rebuilt package contains the `Non-Ubuntu system detected` branch in `preinst`

If you update patch logic, document the tested FTNN package version in the README.

## Commit & Pull Request Guidelines

Recent history uses short imperative subjects such as `Update README.md` and `Use current-directory examples in docs and help`. Keep commits focused and descriptive. Pull requests should summarize the user-visible change, list validation commands run, and note any README updates. Include the sample package version or reproduction details when changing patch behavior.
