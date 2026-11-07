# Working on Armagetron Pizza

Armagetron Pizza is a client based on the official
[Armagetron Advanced](https://gitlab.com/armagetronad/armagetronad)
`legacy_0.2.9` branch. The upstream project's own guide is in
[`/CONTRIBUTING.md`](../CONTRIBUTING.md); this file covers how this repo is run.

## Branches

| Branch | Purpose |
|---|---|
| `main` | Released versions only. Every merge here is a release and gets a tag (`v1.0.0`). |
| `develop` | Day-to-day integration. All work merges here first. |
| `feature/<name>` | New features. Branch off `develop`, merge back via PR. |
| `fix/<name>` | Bug fixes. Branch off `develop`, merge back via PR. |
| `chore/<name>` | Tooling, CI, docs, repo setup. Branch off `develop`, merge back via PR. |
| `hotfix/<name>` | Urgent fix for a release. Branch off `main`, merge into `main` and `develop`. |

Releasing: open a PR from `develop` into `main`, move the **Unreleased** changelog
entries under a new version heading, merge, then tag the merge commit.

## Rules

`main` and `develop` are protected:

- Changes only land through pull requests (no direct pushes).
- The **Build / Linux client** check must pass before merging.
- Force pushes and branch deletion are blocked.

## Changelog

Changes made in this repo are recorded in [`PIZZA_CHANGELOG.md`](../PIZZA_CHANGELOG.md)
using the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format and
[Semantic Versioning](https://semver.org/). Every PR adds a line under **Unreleased**.

The root `CHANGELOG.md` belongs to the upstream project. Leave it alone so that
merging upstream fixes stays conflict-free.

## Pulling in upstream fixes

```sh
git remote add upstream https://gitlab.com/armagetronad/armagetronad.git   # once
git fetch upstream legacy_0.2.9
git checkout -b chore/upstream-sync develop
git merge upstream/legacy_0.2.9
```

Then open a PR into `develop` as usual.

## Building

```sh
./bootstrap.sh
mkdir build && cd build
../configure --disable-sysinstall --disable-desktop
make -j"$(nproc)"
make check
```

See `.github/workflows/build.yml` for the Ubuntu packages needed.
