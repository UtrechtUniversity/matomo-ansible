#!/bin/sh
set -e

cd images

for image in nginx mta matomo
do cd "$image"
   echo "Building image $image ..."
   ./build.sh $*
   cd ..
done

echo "Building images completed."
