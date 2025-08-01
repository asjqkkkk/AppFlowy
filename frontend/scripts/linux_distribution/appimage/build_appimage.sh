#!/usr/bin/env bash

VERSION=$1

# if the appimage-builder not exist, download it
pip3 install git+https://github.com/Frederic98/appimage-builder.git


# update version
grep -rl "\[CHANGE_THIS\]" scripts/linux_distribution/appimage/AppImageBuilder.yml | xargs sed -i "s/\[CHANGE_THIS\]/$VERSION/"

appimage-builder --recipe scripts/linux_distribution/appimage/AppImageBuilder.yml --skip-tests
