#!/bin/bash

NORMAL='\033[0m'
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'

#check autoscale responses
cf autoscale set-policy testApp /var/vcap/packages/cf-plugin-autoscale/src/github.com/hpcloud/cf-plugin-autoscale/test-assets/sample-policy.json | egrep "Error|Failed" && \
{
 echo -e "${RED}1. SET POLICY FAILED${NORMAL}"
} || \
{
 echo -e "${GREEN}1. SET POLICY OK${NORMAL}"
}

policy=`cf autoscale get-policy testApp`

[ -z "$policy" -o ! -z "`echo $policy | egrep -i 'Error|Failed'`" ] && \
{
 echo -e "${RED}2. GET POLICY FAILED${NORMAL}" 
} || \
{
 echo -e "${GREEN}2. GET POLICY OK${NORMAL}"
 echo "POLICY:\n$policy"
}

state=`cf autoscale toggle-policy testApp false`
echo $state | egrep "Error|Failed" && \
{
  echo -e "${RED}3. TOGGLE POLICY FAILED${NORMAL}" 
} || \
{
 echo -e "${GREEN}3. TOGGLE POLICY OK${NORMAL}"
 echo "POLICY STATE:$state"
}

info=`cf autoscale get-policy-status testApp`
echo $info | egrep "Error|Failed" && \
{
  echo -e "${RED}4. GET POLICY STATUS FAILED${NORMAL}" 
} || \
{
 echo -e "${GREEN}4. GET POLICY STATUS OK${NORMAL}"
 echo "POLICY STATUS:$info"
}

hist=`cf autoscale get-autoscaling-history testApp`
echo $hist | egrep "Error|Failed" && \
{
  echo -e "${RED}5. GET AUTOSCALING HISTORY FAILED${NORMAL}" 
} || \
{
 echo -e "${GREEN}5. GET AUTOSCALING HISTORY OK${NORMAL}"
 echo "HISTORY:\n$hist"
}

metric=`cf autoscale get-scaling-metrics testApp`
echo $metric | egrep "Error|Failed" && \
{
  echo -e "${RED}6. GET SCALING METRICS FAILED${NORMAL}" 
} || \
{
 echo -e "${GREEN}6. GET SCALING METRICS OK${NORMAL}"
 echo "$metric"
}

cf autoscale delete-policy testApp | egrep "Error|Failed" && \
{
 echo -e "${RED}7. DELETE POLICY FAILED${NORMAL}"
} || \
{
 echo -e "${GREEN}7. DELETE POLICY OK${NORMAL}"
}

#clean up
echo "CLEANING UP..."
cf delete-org -f autoscaler-acceptance
