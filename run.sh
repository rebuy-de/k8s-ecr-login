#!/usr/bin/env bash

set -ex

: ${REGION:?"Need to set REGION"}

secret_name=ecr-registry-${REGION}

# make sure apiserver and serviceaccounts are ready
kubectl describe serviceaccount default -n default
kubectl describe serviceaccount default -n kube-system

if [[ -n $ACCOUNT_ID && -n $TRUST_ROLE ]]; then
  STS=$(aws sts assume-role \
    --role-arn $TRUST_ROLE \
    --role-session-name 'default_session' \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
    --output text)

  key_id=$(echo $STS | cut -d ' ' -f1)
  secret=$(echo $STS | cut -d ' ' -f2)
  session=$(echo $STS | cut -d ' ' -f3)

  aws configure set aws_access_key_id $key_id --profile ecr_access
  aws configure set aws_secret_access_key $secret --profile ecr_access
  aws configure set aws_session_token $session --profile ecr_access
elif [[ -n $AWS_ACCESS_KEY_ID && -n $AWS_SECRET_ACCESS_KEY ]]; then
  aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID --profile ecr_access
  aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY --profile ecr_access
else
  echo "You need to set valid credentials."
  exit 1
fi

token=$(aws ecr get-authorization-token --region=$REGION \
  --profile ecr_access \
  --query authorizationData[].authorizationToken \
  --output text | base64 -d | cut -d: -f2)

for ns in default kube-system
do
  (
    set -x
    kubectl delete secret \
      --ignore-not-found ${secret_name} \
      --namespace ${ns}

    kubectl create secret docker-registry ${secret_name} \
      --namespace ${ns} \
      --docker-server=https://${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com \
      --docker-username=AWS \
      --docker-password="${token}" \
      --docker-email=none

    # HACK: we had to append `|| true` because `patch` returns non-zero in case of no changes
    # https://github.com/kubernetes/kubernetes/issues/58212
    kubectl patch serviceaccount default \
      --namespace ${ns} \
      -p "{\"imagePullSecrets\": [{\"name\":\"${secret_name}\"}]}" \
      || true
  )
done
