#!/bin/sh

# Exit on errors
set -e
# Compile all p4 programs in p4src
cd p4src
mkdir -p build
for f in *n.p4; do
    sudo p4c-bmv2 --json build/${f%%.*}.json $f
done

cd ../

cp ~/onos-p4-dev/p4src/build/intmon.json ~/Apps/intmon/src/main/resources/
