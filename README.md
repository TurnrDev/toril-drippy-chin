# Drippy Chin

## Clone the repository

This repository uses [Git LFS](https://git-lfs.com/) for its large map-image
assets and includes the OpenStreetMap Carto renderer as a Git submodule.
Install Git and Git LFS before cloning (Git LFS is sometimes mistakenly called
"Git LTS").

```sh
# Install Git LFS once on your machine, then enable it for your user account.
git lfs install

# Clone the repository and fetch all submodules in one step.
git clone --recurse-submodules https://github.com/TurnrDev/toril-drippy-chin.git
cd toril-drippy-chin

# Download the LFS-managed map assets.
git lfs pull
```

If you already cloned the repository without its submodule, run:

```sh
git submodule update --init --recursive
git lfs pull
```

When pulling future changes, update both the repository and its submodules:

```sh
git pull
git submodule update --init --recursive
git lfs pull
```
