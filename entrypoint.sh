#!/bin/bash

if [[ -z $EMAIL || -z $DOMAINS || -z $SECRET || -z $DEPLOYMENT ]]; then
	echo "EMAIL, DOMAINS, SECERT, and DEPLOYMENT env vars required"
	env
	exit 1
fi
SERVICE_ACCOUNT_PATH="/var/run/secrets/certificates-updater/"
NAMESPACE=$(cat $SERVICE_ACCOUNT_PATH/namespace)
NOW=$(date '+%Y-%m-%dT%H:%M:%SZ')

cd $HOME
python3 -m http.server 80 &
PID=$!
if [[ -z $ISSUE_CERTIFICATE ]]; then
	echo "Running certbot to issue a TEST certificate..."
	certbot certonly --test-cert --webroot -w $HOME -n --agree-tos --email ${EMAIL} --no-self-upgrade -d ${DOMAINS} #Use --test-cert for development
else
	echo "Running certbot to issue a PRODUCTION certificate..."
	certbot certonly --webroot -w $HOME -n --agree-tos --email ${EMAIL} --no-self-upgrade -d ${DOMAINS} #Use --test-cert for development
fi

kill $PID

CERTPATH=/etc/letsencrypt/live/$(echo $DOMAINS | cut -f1 -d',')

ls $CERTPATH || exit 1

cat /secret-patch-template.json | \
	sed "s/NAMESPACE/${NAMESPACE}/" | \
	sed "s/NAME/${SECRET}/" | \
	sed "s/TLSCERT/$(cat ${CERTPATH}/fullchain.pem | base64 | tr -d '\n')/" | \
	sed "s/TLSKEY/$(cat ${CERTPATH}/privkey.pem |  base64 | tr -d '\n')/" \
	> /secret-patch.json

ls /secret-patch.json || exit 1

# update secret
curl --cacert $SERVICE_ACCOUNT_PATH/ca.crt -H "Authorization: Bearer $(cat $SERVICE_ACCOUNT_PATH/token)" -k -XPATCH  -H "Accept: application/json, */*" -H "Content-Type: application/strategic-merge-patch+json" -d @/secret-patch.json https://kubernetes/api/v1/namespaces/${NAMESPACE}/secrets/${SECRET}

echo "Secret ${SECRET} updated"

cat /deployment-patch-template.json | \
	sed "s/TLSUPDATED/$(date)/" | \
	sed "s/NAMESPACE/${NAMESPACE}/" | \
	sed "s/NAME/${DEPLOYMENT}/" \
	> /deployment-patch.json

ls /deployment-patch.json || exit 1

# update pod spec on ingress deployment to trigger redeploy
# curl --cacert $SERVICE_ACCOUNT_PATH/ca.crt -H "Authorization: Bearer $(cat $SERVICE_ACCOUNT_PATH/token)" -k -v -XPATCH  -H "Accept: application/json, */*" -H "Content-Type: application/strategic-merge-patch+json" -d @/deployment-patch.json https://kubernetes/apis/extensions/v1beta1/namespaces/${NAMESPACE}/deployments/${DEPLOYMENT}

curl --location --request PATCH "https://kubernetes/apis/apps/v1/namespaces/${NAMESPACE}/deployments/${DEPLOYMENT}?fieldManager=kubectl-rollout&pretty=true" \
--cacert $SERVICE_ACCOUNT_PATH/ca.crt -H "Authorization: Bearer $(cat $SERVICE_ACCOUNT_PATH/token)" -k -H "Accept: application/json, */*" \
--header 'Content-Type: application/strategic-merge-patch+json' \
--data-raw '{
    "spec": {
        "template": {
            "metadata": {
                "annotations": {
                    "kubectl.kubernetes.io/restartedAt": "'$NOW'"
                }
            }
        }
    }
}'

