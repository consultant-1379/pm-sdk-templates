#!/bin/bash

# Script to create pm-sdk-templates tar.gz for upload to nexus.

CAT=cat
CP=cp
DATE=date
ECHO=echo
GETOPT=getopt
MKDIR=mkdir
RM=rm
SED=sed
TAR=tar

PROJECT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

CHART_FILE="${PROJECT_DIR}/chart/eric-enmsg-custom-pm-oneflow/Chart.yaml"
BUILD_DIR="${PROJECT_DIR}/build"
BUILD_SOURCE_DIR="${BUILD_DIR}/pm-sdk-templates"

info() {
  local _msg_="${1}"
  ${ECHO} -e "INFO : ${_msg_}"
}

error() {
  local _msg_="${1}"
  ${ECHO} -e "ERROR - ${_msg_}" >&2
}

clean(){
  info "Cleaning previous builds ..."
  if [[ ! -f ${BUILD_DIR} ]] ; then
     ${RM} -rf ${RM_OPTS} ${BUILD_DIR}
  fi
}

setup() {
  info "Setting up build ..."
  ${MKDIR} ${MKDIR_OPTS} ${BUILD_DIR} || exit 1
  ${MKDIR} ${MKDIR_OPTS} ${BUILD_SOURCE_DIR} || exit 1
  ${CP} -R ${CP_OPTS} ${PROJECT_DIR}/chart ${PROJECT_DIR}/image_content ${BUILD_SOURCE_DIR} || exit 1
  ${CP} -R ${CP_OPTS} ${PROJECT_DIR}/Dockerfile ${BUILD_SOURCE_DIR} || exit 1
  ${CP} -R ${CP_OPTS} ${PROJECT_DIR}/eric-enm-custom-models-pm-oneflow ${BUILD_SOURCE_DIR} || exit 1
}

update_Chart() {
  local _version_=${1}
  info "Update the Chart.yaml with the new version, ${_version_}"
  ${SED} -i "s/version:.*/version: ${_version_}/;" ${CHART_FILE}
}

create_tar() {
  local _version_=${1}
  local _tar_dest_=${2}
  _tar_name_="pm-sdk-templates-${_version_}.tar.gz"
  ${TAR} czvf ${_tar_dest_}/${_tar_name_} -C ${_tar_dest_} pm-sdk-templates
  info "Generated ${_tar_dest_}/${_tar_name_}"
  ${TAR} -ztvf ${_tar_dest_}/${_tar_name_}
}

usage() {
  info "Usage: $0 OPTIONS"
  info "Options:"
  info "\t-c\t\tClean build environment"
  info "\t-g\t\tGenerate a new pm-sdk-templates tar file"
  info "\t--version\tIf preparing/generating the tar, use this version for the tar"
  info "\t-v\t\tEnable debug mode"
  info "\t-h\t\tPrint help"
}

if [[ $# -eq 0 ]] ; then
  usage
  exit 2
fi

OPTS=$(${GETOPT} -o 'vgc' -a --longoptions 'version:,dest:' -n "$0" -- "$@")
eval set --${OPTS}


VERBOSE=
CLEAN=
GENERATE=
_version_=
_dest_=${BUILD_DIR}

while :; do
  case "${1}" in
  --version)
    _version_=${2}
    shift 2
    ;;
  --dest)
    _dest_=$(realpath ${2})
    shift 2
    ;;
  -c)
    CLEAN=true
    shift
    ;;
  -g)
    GENERATE=true
    shift
    ;;
  -v)
    VERBOSE=true
    shift
    ;;
  --)
    shift
    break
    ;;
  *)
    error "Unknown argument ${1}"
    exit 1
  esac
done

RM_OPTS=
MKDIR_OPTS=
CP_OPTS=
if [[ ${VERBOSE} ]] ; then
  set -x
  RM_OPTS="--verbose"
  MKDIR_OPTS="--verbose"
  CP_OPTS="--verbose"
fi


if [[ ${CLEAN} ]] ; then
  clean
fi

if [[ ${GENERATE} ]] ; then
  if [[ -z ${_version_} ]] ; then
    error "No VERSION specified!"
    exit 2
  fi
  clean
  update_Chart ${_version_}
  setup
  create_tar ${_version_} ${_dest_}
fi
