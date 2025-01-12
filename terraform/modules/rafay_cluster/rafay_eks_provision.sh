#!/bin/bash -x
curl -s -o rctl-linux-amd64.tar.bz2 https://s3-us-west-2.amazonaws.com/rafay-prod-cli/publish/rctl-linux-amd64.tar.bz2
tar -xf rctl-linux-amd64.tar.bz2
chmod 0755 rctl
sleep 30
cp $1 /tmp/eks-ckuster.yaml
sed -i "s/demo-cluster/$CLUSTER_NAME/g" /tmp/eks-ckuster.yaml
sed -i "s/defaultproject/$PROJECT_NAME/g" /tmp/eks-ckuster.yaml
sed -i "s/AWS/$CREDENTIALS_NAME/g" /tmp/eks-ckuster.yaml
./rctl config set project $PROJECT_NAME
./rctl create cluster eks -f /tmp/eks-ckuster.yaml
if [ $? -eq 0 ];
then
    echo "[+] Successfully submitted creation request for cluster ${CLUSTER_NAME}"
fi

CLUSTER_STATUS_ITERATIONS=1
CLUSTER_HEALTH_ITERATIONS=1
CLUSTER_STATUS=`./rctl get cluster ${CLUSTER_NAME} -o json |jq '.status'|cut -d'"' -f2`
if [ -z $CLUSTER_STATUS ]
 then
  echo " !! Unable to fecth cluster status !! "
  echo " !! Cluster Provisioning Failed !! " && exit -1
fi
while [ "$CLUSTER_STATUS" != "READY" ]
do
  sleep 60
  if [ -z $CLUSTER_STATUS ]
   then
    echo " !! Unable to fecth cluster status !! "
    echo " !! Cluster Provisioning Failed !! " && exit -1
  fi
  if [ $CLUSTER_STATUS_ITERATIONS -ge 50 ];
  then
    break
  fi
  CLUSTER_STATUS_ITERATIONS=$((CLUSTER_STATUS_ITERATIONS+1))
  CLUSTER_STATUS=`./rctl get cluster ${CLUSTER_NAME} -o json |jq '.status'|cut -d'"' -f2`
  if [ $CLUSTER_STATUS == "PROVISION_FAILED" ];
  then
    echo -e " !! Cluster provisioning failed with status $CLUSTER_STATUS !!  "
    echo -e " !! Exiting !!  " && exit -1
  fi

  PROVISION_STATUS=`./rctl get cluster ${CLUSTER_NAME} -o json |jq '.provision.status' |cut -d'"' -f2`

  if [ $PROVISION_STATUS == "INFRA_CREATION_FAILED" ];
  then
    echo -e " !! Cluster provisioning failed with status $PROVISION_STATUS !!  "
    echo -e " !! Exiting !!  " && exit -1
  fi

  if [ $PROVISION_STATUS == "BOOTSTRAP_CREATION_FAILED" ];
  then
    echo -e " !! Cluster provisioning failed with status $PROVISION_STATUS !!  "
    echo -e " !! Exiting !!  " && exit -1
  fi

  PROVISION_STATE=`./rctl get cluster ${CLUSTER_NAME} -o json | jq '.provision.running_state' |cut -d'"' -f2`

  echo "$PROVISION_STATE in progress"
done
if [ $CLUSTER_STATUS != "READY" ];
then
    echo -e " !! Cluster provisioning failed with status $CLUSTER_STATUS !!  "
    echo -e " !! Exiting !!  " && exit -1
fi
if [ $CLUSTER_STATUS == "READY" ];
then
    echo "[+] Cluster Provisioned Successfully waiting for it to be healthy"
    CLUSTER_HEALTH=`./rctl get cluster ${CLUSTER_NAME} -o json | jq '.health' |cut -d'"' -f2`
    while [ "$CLUSTER_HEALTH" != 1 ]
    do
      echo "Iteration-${CLUSTER_HEALTH_ITERATIONS} : Waiting 60 seconds for cluster to be healthy..."
      sleep 60
      if [ $CLUSTER_HEALTH_ITERATIONS -ge 15 ];
      then
        break
      fi
      CLUSTER_HEALTH_ITERATIONS=$((CLUSTER_HEALTH_ITERATIONS+1))
      CLUSTER_HEALTH=`./rctl get cluster ${CLUSTER_NAME} -o json | jq '.health' |cut -d'"' -f2`
    done
fi

if [[ $CLUSTER_HEALTH == 0 ]];
then
    echo -e " !! Cluster is not healthy !!  "
    echo -e " !! Exiting !!  " && exit -1
fi
if [[ $CLUSTER_HEALTH == 1 ]];
then
    echo "[+] Cluster Provisioned Successfully and is Healthy"
fi

