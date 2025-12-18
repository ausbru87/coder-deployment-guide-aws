#!/bin/bash

source coder-infra.env

# Check if already validated
CERT_STATUS=$(aws acm describe-certificate --certificate-arn $CERT_ARN --region $AWS_REGION \
  --query 'Certificate.Status' --output text)

if [ "$CERT_STATUS" = "ISSUED" ]; then
  echo "Certificate already validated"
else
  # Get hosted zone for base domain
  BASE_DOMAIN=$(echo $CODER_DOMAIN | cut -d. -f2-)
  HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
    --dns-name $BASE_DOMAIN \
    --query 'HostedZones[0].Id' --output text | cut -d'/' -f3)

  # Get validation record details
  VALIDATION=$(aws acm describe-certificate --certificate-arn $CERT_ARN --region $AWS_REGION \
    --query 'Certificate.DomainValidationOptions[0].ResourceRecord')
  RECORD_NAME=$(echo $VALIDATION | jq -r '.Name')
  RECORD_VALUE=$(echo $VALIDATION | jq -r '.Value')

  # Create/update validation record (UPSERT is idempotent)
  aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "'$RECORD_NAME'",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "'$RECORD_VALUE'"}]
      }
    }]
  }'
  echo "Created validation record"
fi
