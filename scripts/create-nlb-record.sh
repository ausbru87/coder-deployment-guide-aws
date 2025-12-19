#!/bin/bash

source coder-infra.env

# Get the NLB hostname
NLB_HOSTNAME=$(kubectl get svc coder -n coder \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "NLB Hostname: $NLB_HOSTNAME"

# Get hosted zone ID
BASE_DOMAIN=$(echo $CODER_DOMAIN | cut -d. -f2-)
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name $BASE_DOMAIN \
  --query 'HostedZones[0].Id' --output text | cut -d'/' -f3)

# Create A record (alias to NLB)
aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch '{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "'$CODER_DOMAIN'",
      "Type": "A",
      "AliasTarget": {
        "HostedZoneId": "Z18D5FSROUN65G",
        "DNSName": "'$NLB_HOSTNAME'",
        "EvaluateTargetHealth": true
      }
    }
  }]
}'
