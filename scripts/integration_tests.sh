#!/bin/bash

function log() {
    echo "[$(date)]" $@
}

function list_dir() {
    ls -I .git -alR $1
}

function generate_git_config() {
    echo "[user]
    email = example@example.com
    name = DFM Tester
" > $HOME/.gitconfig
}

function cleanup() {
    rm -rf $HOME_DIR
    rm -rf $CONFIG_DIR

    if [[ -n $1 ]]; then
        echo "Exiting!"
        exit $1
    fi

    export HOME_DIR=$(mktemp -d)
    export DFM_CONFIG_DIR=$(mktemp -d)
    export HOME=$HOME_DIR

    generate_git_config
}

function x() {
    echo "Running: $@"
    $@
    if [[ $? != 0 ]]; then
        FAILED_CODE=$?
        log "Failed to run $@"
        cleanup $FAILED_CODE
    fi
}

##############
# CLONE TEST #
##############
function dfm_clone_test() {
    local DFM=$1
    shift;
    local PROFILE_NAME=$1
    shift;
    local PROFILE_REPOSITORY=$1

    log "Running clone tests..."

    x $DFM_BIN --version
    x $DFM_BIN clone --name $PROFILE_NAME $PROFILE_REPOSITORY
    x $DFM_BIN link $PROFILE_NAME

    if [ ! -d $DFM_CONFIG_DIR/profiles/integration ]; then
        log "Failed to clone integration profile! \$DFM_CONFIG_DIR contents:"
        ls -laR $DFM_CONFIG_DIR
        exit 1
    fi

    log "[PASS] Integration profile cloned"

    if [ ! -L $HOME/.dotfile ]; then
        log "Failed to link integration profile! \$HOME contents:"
        ls -laR $HOME
        exit 1
    fi

    log "[PASS] Integration profile linked"

    cleanup
}

function dfm_clone_and_link_test() {
    local DFM=$1
    shift;
    local PROFILE_NAME=$1
    shift;
    local PROFILE_REPOSITORY=$1

    log "Running clone tests..."

    x $DFM_BIN clone --link --name $PROFILE_NAME $PROFILE_REPOSITORY

    if [ ! -d $DFM_CONFIG_DIR/profiles/integration ]; then
        log "Failed to clone integration profile! \$DFM_CONFIG_DIR contents:"
        ls -laR $DFM_CONFIG_DIR
        exit 1
    fi

    log "[PASS] Integration profile cloned"

    if [ ! -L $HOME/.dotfile ]; then
        log "Failed to link integration profile! \$HOME contents:"
        ls -laR $HOME
        exit 1
    fi

    log "[PASS] Integration profile linked"

    cleanup
}

#############
# INIT TEST #
#############
function dfm_init_and_add_test() {
    local DFM=$1;

    log "Running init tests..."

    x $DFM init integration-test
    x $DFM link integration-test

    if [ ! -d $DFM_CONFIG_DIR/profiles/integration-test/.git ]; then
        log "Failed to create git repository in \$DFM_CONFIG_DIR/profiles/integration-test. \$DFM_CONFIG_DIR contents:"
        ls -laR $DFM_CONFIG_DIR
        exit 1
    fi

    log "[PASS] Integration profile created"

    echo "# A fake dotfile" > $HOME/.dfm_dotfile

    x $DFM add $HOME/.dfm_dotfile

    if [ ! -L $HOME/.dfm_dotfile ]; then
        log "\$HOME/.dfm_dotfile is not a link. \$HOME contents:"
        list_dir $HOME
        log "\$DFM_CONFIG_DIR contents"
        list_dir $DFM_CONFIG_DIR
        exit 1
    fi

    log "[PASS] Added dotfile is now a symlink"

    if [ ! -f $DFM_CONFIG_DIR/profiles/integration-test/.dfm_dotfile ]; then
        log "\$DFM_CONFIG_DIR/profiles/integration-test/.dfm_dotfile is not a file. \$HOME contents:"
        list_dir $HOME
        log "\$DFM_CONFIG_DIR contents"
        list_dir $DFM_CONFIG_DIR
        exit 1
    fi

    log "[PASS] Added dotfile is in git repository"
        
    cleanup
}

DFM_BIN=""
export PROFILE_REPOSITORY="https://github.com/chasinglogic/dfm_dotfile_test.git"
export PROFILE_NAME="integration"
export HOME_DIR=$(mktemp -d)
export DFM_CONFIG_DIR=$(mktemp -d)

while getopts ":b:" opt; do
    case $opt in
        b) DFM_BIN="$OPTARG" ;;
        \?) echo "Invalid option: -$OPTARG" >&2 ; exit 1 ;;
    esac
done

mkdir -p $HOME_DIR
export HOME=$HOME_DIR

generate_git_config

x $DFM_BIN --version
dfm_clone_test $DFM_BIN $PROFILE_NAME $PROFILE_REPOSITORY
dfm_clone_and_link_test $DFM_BIN $PROFILE_NAME $PROFILE_REPOSITORY
dfm_init_and_add_test $DFM_BIN