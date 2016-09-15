#!/usr/bin/env bash

source helpers.sh

ENV_VARS=(
  DCOS
  TOKEN
  EVALUATION_PASSPHRASE
  ELB_HOST
  AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY
  CLIENT_NUMBER
)

for ENV_VAR in "${ENV_VARS[@]}"
do
  if [ -z "${!ENV_VAR}" ]; then
    echo ">>> ${ENV_VAR} is not configured; please export it."
    exit 1
  fi
done

EVAL_NUMBER=1
SIMULATION=ad_counter
PARTITION_PROBABILITY=0
AAE_INTERVAL=20000
DELTA_INTERVAL=20000
INSTRUMENTATION=true
LOGS="s3"
EXTENDED_LOGGING=true
MAILBOX_LOGGING=false

declare -A EVALUATIONS

## client_server_state_based_with_aae_test
EVALUATIONS["client_server_state_based_with_aae"]="partisan_client_server_peer_service_manager state_based false false"

## client_server_delta_based_with_aae_test
EVALUATIONS["client_server_delta_based_with_aae"]="partisan_client_server_peer_service_manager delta_based false false"

## peer_to_peer_state_based_with_aae_test
EVALUATIONS["peer_to_peer_state_based_with_aae"]="partisan_hyparview_peer_service_manager state_based false false"

## peer_to_peer_state_based_with_aae_and_tree_test
##EVALUATIONS["peer_to_peer_state_based_with_aae_and_tree"]="partisan_hyparview_peer_service_manager state_based true false"

## peer_to_peer_delta_based_with_aae_test
EVALUATIONS["peer_to_peer_delta_based_with_aae"]="partisan_hyparview_peer_service_manager delta_based false false"

## code_peer_to_peer_delta_based_with_aae
EVALUATIONS["code_peer_to_peer_delta_based_with_aae"]="partisan_hyparview_peer_service_manager delta_based false true"

for i in $(seq 1 $EVAL_NUMBER)
do
  echo "[$(date +%T)] Running evaluation $i of $EVAL_NUMBER"

  for EVAL_ID in "${!EVALUATIONS[@]}"
  do
    STR=${EVALUATIONS["$EVAL_ID"]}
    IFS=' ' read -a CONFIG <<< "$STR"
    PEER_SERVICE=${CONFIG[0]}
    MODE=${CONFIG[1]}
    BROADCAST=${CONFIG[2]}
    HEAVY_CLIENTS=${CONFIG[3]}
    TIMESTAMP=$(date +%s)
    REAL_EVAL_ID=$EVAL_ID"_"$CLIENT_NUMBER

    if [ "$PEER_SERVICE" == "partisan_client_server_peer_service_manager" ] && [ "$CLIENT_NUMBER" -gt "128" ]; then
      echo "[$(date +%T)] Client-Server topology with $CLIENT_NUMBER clients is not supported"
    elif [ "$MODE" == "state_based" ] && [ "$PARTITION_PROBABILITY" -gt "0" ]; then
      echo "[$(date +%T)] Skipping $EVAL_ID with $CLIENT_NUMBER clients with configuration $STR"
    else
      PEER_SERVICE=$PEER_SERVICE MODE=$MODE BROADCAST=$BROADCAST SIMULATION=$SIMULATION EVAL_ID=$REAL_EVAL_ID EVAL_TIMESTAMP=$TIMESTAMP CLIENT_NUMBER=$CLIENT_NUMBER HEAVY_CLIENTS=$HEAVY_CLIENTS PARTITION_PROBABILITY=$PARTITION_PROBABILITY AAE_INTERVAL=$AAE_INTERVAL DELTA_INTERVAL=$DELTA_INTERVAL INSTRUMENTATION=$INSTRUMENTATION LOGS=$LOGS AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY EXTENDED_LOGGING=$EXTENDED_LOGGING MAILBOX_LOGGING=$MAILBOX_LOGGING ./dcos-deploy.sh

      echo "[$(date +%T)] Running $EVAL_ID with $CLIENT_NUMBER clients with configuration $STR"

      wait_for_completion $TIMESTAMP
    fi
  done

  echo "[$(date +%T)] Evaluation $i of $EVAL_NUMBER completed!"
done
