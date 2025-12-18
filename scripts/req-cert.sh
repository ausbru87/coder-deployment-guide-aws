source coder-infra.env

# Check for existing certificate
CERT_ARN=$(aws acm list-certificates --region $AWS_REGION \
  --query "CertificateSummaryList[?DomainName=='$CODER_DOMAIN'].CertificateArn" --output text)

if [ -z "$CERT_ARN" ] || [ "$CERT_ARN" = "None" ]; then
  CERT_ARN=$(aws acm request-certificate \
    --domain-name $CODER_DOMAIN \
    --region $AWS_REGION \
    --validation-method DNS \
    --query 'CertificateArn' --output text)
  echo "Requested new certificate: $CERT_ARN"
else
  echo "Using existing certificate: $CERT_ARN"
fi

# Save to env file (avoid duplicates)
grep -q "CERT_ARN" coder-infra.env || echo "export CERT_ARN=$CERT_ARN" >> coder-infra.env
