function create_kubeconfig(){
  FILE=~/.kube/config
  if [[  -f "$FILE" ]]; then
      return 1
  fi
  CLUSTER_SERVER=https://kubernetes.default.svc  &>/dev/null
  CURRENT_CONTEXT=my  &>/dev/null
  SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount  &>/dev/null
  NAMESPACE=$(cat ${SERVICEACCOUNT}/namespace)  &>/dev/null
  USER_TOKEN_VALUE=$(cat ${SERVICEACCOUNT}/token| base64 -w 0)  &>/dev/null
  CLUSTER_CA=$(cat ${SERVICEACCOUNT}/ca.crt | base64 -w 0)  &>/dev/null

  kubectl config set-cluster my-cluser --server=https://kubernetes.default.svc:443  &>/dev/null
  kubectl config set-credentials user1 --token $USER_TOKEN_VALUE  &>/dev/null
  kubectl config set-context my --cluster=my-cluster --user=user1  &>/dev/null
  kubectl config use-context my  &>/dev/null

  clear
}
function use_ns(){
    #echo $NGINX_NS
    cp ~/.kube/config .kubeconfig  &>/dev/null
    export KUBECONFIG=.kubeconfig
    if [ -z "$1" ] ; then
        NS=$NGINX_NS      
    else       
        NS=$1
    fi   
    kubectl create ns $NS >/dev/null 2>&1 
    kubectl config set-context --current --namespace=$NS &>/dev/null
}
function wait_5_sec(){
  [[ $VERBOSE ]] &&  PROMPT_TIMEOUT=5
  wait
  [[ $VERBOSE ]] &&  PROMPT_TIMEOUT=0
}

function wait_clear(){
  wait
  clear
}
function end_demo(){
  clear
  p 'Thank you for watching TeraSky (c)'
  exit
}
function caption(){
  msg=$(echo "****************** $1 ******************")
  p "$msg"
  msg_count=${#msg}
  seperators=""
  for i in $(eval echo "{1..$msg_count}"); do seperators=$(echo "$seperators*") ; done
  [[ $VERBOSE ]] && p "$seperators"
}

COMMANDS="kubectl"
COMMANDS="$COMMANDS pxctl"
COMMANDS="$COMMANDS kubectl-pxc"
COMMANDS="$COMMANDS jq"
COMMANDS="$COMMANDS yq"
COMMANDS="$COMMANDS kubectl-node_shell"

function clear_all_resources() {
  kubectl delete -n portworx-poc  $(kubectl get deployment -n portworx-poc -o name)  &>/dev/null
  kubectl delete -n portworx-poc  $(kubectl get pvc -n portworx-poc -o name) &>/dev/null
  kubectl delete ns portworx-poc &>/dev/null
  kubectl delete -f .  &>/dev/null
  helm uninstall dbench-portworx-sc-high-io -n pwx-poc-benchmark &>/dev/null
}

function wait_for_pod_by_label(){
    LABEL=$1
    NS=$2
    [[ -z $NS ]] && NS=default
    sleep 2 &>/dev/null
    POD=$(kubectl get pod -n $NS  -l $LABEL -o name)
    p "We need to wait for pod: '$POD' to be up and running"
    kubectl wait --for=condition=ContainersReady -n $NS pod -l $LABEL --timeout 5m &>/dev/null
    p "pod $POD is ready..."  
}
function check_requirments() {
    NEED_TO_EXIT=0
    for comm in $COMMANDS; do
    if ! which $comm >/dev/null ; then
        echo -e "${RED} You need to install $comm to run this demo"
        NEED_TO_EXIT=1
    fi
   
    done 
      [[ $NEED_TO_EXIT == 1 ]] && exit 1
   
  }