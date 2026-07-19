#!/bin/bash
#
DEST=${HOME}/Games/faf-linux/faf-maps-mods/maps

MAPNAME="${1:-}"

if [[ -z "${MAPNAME}" ]]; then
  echo "Please enter the map name" >&2
  exit 1
fi

if [[ ! -d "${DEST}/${MAPNAME}"*/ ]]; then
  echo "Could not find map ${MAPNAME}" >&2
  exit 2
fi

cp -av LineWars_script.lua "${DEST}/${MAPNAME}"*/${MAPNAME}_script.lua
[[ -d "${DEST}/${MAPNAME}"*/lib ]] && rm -rf "${DEST}/${MAPNAME}"*/lib && echo "Removed DEST lib"
cp -av lib "${DEST}/${MAPNAME}"*/
cp -av LineWars_scenario.lua "${DEST}/${MAPNAME}"*/${MAPNAME}_scenario.lua
cp -av LineWars_options.lua "${DEST}/${MAPNAME}"*/${MAPNAME}_options.lua
