#!/bin/sh
# ./originate.sh <contract_name> <originator_address> 

set -o xtrace
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BUILD_DIR=$SCRIPT_DIR/../../_build/contracts
CONTRACT_FILE=$SCRIPT_DIR/main.mligo
STORAGE_FILE=$SCRIPT_DIR/storage.mligo
STORAGE_INIT=`ligo compile expression cameligo --michelson-format text --init-file $STORAGE_FILE 'init'`
OUTPUT_FILE=$BUILD_DIR/$1.tez
mkdir -p $BUILD_DIR
ligo compile contract $CONTRACT_FILE > $OUTPUT_FILE
octez-client originate contract $1 transferring 0 from $2 running $OUTPUT_FILE --init "$STORAGE_INIT" --burn-cap 2