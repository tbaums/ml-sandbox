####
# run `aws configure` and leave all blank except default region.
# set default region to us-east-1 when prompted.
###

export AWS_ACCOUNT=arrikto-dev
export AWS_IAM_USER=mt
export AWS_DEFAULT_REGION=$(aws configure get region)
export VPCID=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true | jq -r '.Vpcs[0].VpcId')    
echo ${VPCID?}
export SUBNETIDS=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=${VPCID?} | jq -r '.Subnets[].SubnetId' | xargs)
echo ${SUBNETIDS?}
export SECURITYGROUP=max-permissions-eks-clusters
echo ${SECURITYGROUP?}
export SECURITYGROUPID=$(aws ec2 describe-security-groups --filters Name=vpc-id,Values=${VPCID?} Name=group-name,Values=${SECURITYGROUP?} | jq -r '.SecurityGroups[].GroupId')
echo ${SECURITYGROUPID?}

export CIDR=24.90.93.97/32  
echo ${CIDR?}
aws ec2 authorize-security-group-ingress \
     --group-id ${SECURITYGROUPID?} \
     --protocol tcp \
     --port 0-65535 \
     --cidr ${CIDR?}
aws ec2 authorize-security-group-ingress \
     --group-id ${SECURITYGROUPID?} \
     --protocol icmp \
     --port -1

####
# Manually edit sg inbound to allow 172.0.0.0/8 (jumphost)
####

export CIDRS=$CIDR
echo ${CIDRS?}
export CLUSTERNAME=mt
echo ${CLUSTERNAME?}
export ACCOUNT_ID=$(aws sts get-caller-identity | jq -r '.Account')
echo ${ACCOUNT_ID}
export SECURITYGROUPIDS=${SECURITYGROUPID?}
echo ${SECURITYGROUPIDS}

aws eks create-cluster \
      --name ${CLUSTERNAME?} \
      --role-arn arn:aws:iam::${ACCOUNT_ID?}:role/eksServiceRole \
      --resources-vpc-config subnetIds=${SUBNETIDS// /,},securityGroupIds=${SECURITYGROUPIDS// /,},endpointPublicAccess=true,endpointPrivateAccess=true,publicAccessCidrs=${CIDRS// /,} \
      --tags owner=${AWS_ACCOUNT?}/${AWS_IAM_USER?} \
      --kubernetes-version 1.17

watch aws eks describe-cluster --name mt --query 'cluster.status'

eksctl utils associate-iam-oidc-provider --cluster $CLUSTERNAME --approve

export OIDC_PROVIDER=$(aws eks describe-cluster --name $CLUSTERNAME --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///")
echo ${OIDC_PROVIDER?}

aws iam get-open-id-connect-provider \
     --open-id-connect-provider-arn arn:aws:iam::$ACCOUNT_ID:oidc-provider/$OIDC_PROVIDER

aws eks update-kubeconfig --name $CLUSTERNAME

export INSTANCE_TYPE=m5d.2xlarge
echo ${INSTANCE_TYPE?}

export WORKER_SUBNET=subnet-38d9a636
echo ${WORKER_SUBNET}

aws eks create-nodegroup \
     --cluster-name ${CLUSTERNAME?} \
     --nodegroup-name general-workers \
     --disk-size 200 \
     --scaling-config minSize=1,maxSize=3,desiredSize=2 \
     --subnets ${WORKER_SUBNET?} \
     --instance-types ${INSTANCE_TYPE?} \
     --ami-type AL2_x86_64 \
     --node-role arn:aws:iam::${ACCOUNT_ID?}:role/eksWorkerNodeRole \
     --labels role=general-worker \
     --tags owner=${AWS_ACCOUNT?}/${AWS_IAM_USER?},kubernetes.io/cluster/${CLUSTERNAME?}=owned \
     --release-version 1.17.12-20210310 \
     --kubernetes-version 1.17

watch aws eks describe-nodegroup --cluster-name mt --nodegroup-name general-workers --query 'nodegroup.status'

cat<<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:sts::409688176173:assumed-role/mtanenbaum-ekf-max/i-05fb2a592c2c060ad
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: arn:aws:iam::409688176173:role/eksWorkerNodeRole
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:nodes
        - system:bootstrappers
  mapUsers: |
    - userarn: arn:aws:iam::409688176173:user/michael.tanenbaum
      username: iam-user-mtanenbaum-admin
      groups:
        - system:masters
EOF

touch /root/.aws/credentials

rok-deploy 

kubectl annotate storageclass rok \
         storageclass.kubernetes.io/is-default-class=true
kubectl annotate volumesnapshotclass rok \
         snapshot.storage.kubernetes.io/is-default-class=true
kubectl annotate storageclass gp2 --overwrite \
         storageclass.kubernetes.io/is-default-class=false

export CLUSTERNAME=mt
export DOMAIN=aws-dev.arrikto.com
export SUBDOMAIN=a1-east.aws-dev.arrikto.com

ZONES=$(aws route53 list-hosted-zones-by-name --output json --dns-name "${DOMAIN}." | jq -r '.HostedZones[].Id' | wc -l)
[[ "$ZONES" -eq 1 ]] && echo OK

export AWS_ZONE_ID=$(aws route53 list-hosted-zones-by-name --output json --dns-name "${DOMAIN}." | jq -r '.HostedZones[].Id' | xargs) 
echo ${AWS_ZONE_ID?}

aws route53 list-resource-record-sets \
     --output json \
     --hosted-zone-id $AWS_ZONE_ID \
     --query "ResourceRecordSets[?Type == 'NS']" | \
         jq -r '.[0].ResourceRecords[].Value'



export IAM_ROLE_NAME=eks-external-dns-$CLUSTERNAME
export IAM_ROLE_DESCRIPTION=ExternalDNS
export IAM_POLICY_NAME=AllowExternalDNSUpdates
export SERVICE_ACCOUNT_NAMESPACE=default
export SERVICE_ACCOUNT_NAME=external-dns

export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
export OIDC_PROVIDER=$(aws eks describe-cluster --name $CLUSTERNAME --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///")

j2 rok/eks/iamsa-trust.json.j2 -o iam-$IAM_ROLE_NAME-trust.json
git add iam-$IAM_ROLE_NAME-trust.json
git commit -m "Add JSON trust policy document for $IAM_ROLE_NAME"

aws iam get-role --role-name $IAM_ROLE_NAME
aws iam list-attached-role-policies --role-name $IAM_ROLE_NAME

sed -e 's/arn:aws:iam::123456789012:role\/eks-external-dns/arn:aws:iam::409688176173:role\/eks-external-dns-mt/g' rok/external-dns/overlays/deploy/patches/sa.yaml > changed.txt && mv changed.txt rok/external-dns/overlays/deploy/patches/sa.yaml && cat rok/external-dns/overlays/deploy/patches/sa.yaml

sed -e 's/external-dns-test.my-org.com/aws-dev.arrikto.com/g' rok/external-dns/overlays/deploy/patches/deploy.yaml > changed.txt && mv changed.txt rok/external-dns/overlays/deploy/patches/deploy.yaml && cat rok/external-dns/overlays/deploy/patches/deploy.yaml

git commit -am "Configure ExternalDNS"

rok-deploy --apply rok/external-dns/overlays/deploy

rok-deploy --apply rok/cert-manager/cert-manager-kube-system-resources/base

rok-deploy --apply rok/cert-manager/cert-manager/overlays/deploy

export VPCID=$(aws eks describe-cluster --name ${CLUSTERNAME?} | jq -r '.cluster.resourcesVpcConfig.vpcId') && echo ${VPCID}
export IGW=$(aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=${VPCID?} | jq -r '.InternetGateways[].InternetGatewayId')
export RTB=$(aws ec2 describe-route-tables \
                  --filters Name=vpc-id,Values=${VPCID} \
                            Name=route.destination-cidr-block,Values=0.0.0.0/0 \
                            Name=route.gateway-id,Values=${IGW} | \
                  jq -r '.RouteTables[].RouteTableId')
export MRTB=$(aws ec2 describe-route-tables \
                   --filters Name=vpc-id,Values=${VPCID} \
                             Name=association.main,Values=true | \
                   jq -r '.RouteTables[].RouteTableId')
[[ "$RTB" == "$MRTB" ]] && export SUBNETS=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPCID | jq -r '.Subnets[].SubnetId' | xargs)


export SUBNETS=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPCID | jq -r '.Subnets[].SubnetId' | xargs) && echo ${SUBNETS?}

aws ec2 create-tags \
     --resources ${SUBNETS// /,} \
     --tags Key=kubernetes.io/role/elb,Value=1
aws ec2 create-tags \
     --resources ${SUBNETS} \
     --tags Key=kubernetes.io/role/elb,Value=1
subnet-f8e8bdb5

export IAM_ROLE_NAME=eks-aws-load-balancer-controller-${CLUSTERNAME?}
export IAM_ROLE_DESCRIPTION="AWS Load Balancer Controller"
export IAM_POLICY_NAME=AWSLoadBalancerControllerIAMPolicy
export SERVICE_ACCOUNT_NAMESPACE=kube-system
export SERVICE_ACCOUNT_NAME=aws-load-balancer-controller

export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text) && echo ${AWS_ACCOUNT_ID}
export OIDC_PROVIDER=$(aws eks describe-cluster --name $CLUSTERNAME --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///") && echo ${OIDC_PROVIDER?}

j2 rok/eks/iamsa-trust.json.j2 -o iam-$IAM_ROLE_NAME-trust.json


git add iam-$IAM_ROLE_NAME-trust.json
git diff
git commit -m "Add JSON trust policy document for $IAM_ROLE_NAME"


###=========
# DO NOT SKIP ROLE CREATION + Policy Attach steps BELOW
# Each is specific per-cluster
###=========

aws iam create-role \
     --role-name $IAM_ROLE_NAME \
     --assume-role-policy-document file://iam-$IAM_ROLE_NAME-trust.json \
     --description "$IAM_ROLE_DESCRIPTION"

aws iam attach-role-policy \
     --role-name $IAM_ROLE_NAME \
     --policy-arn=arn:aws:iam::$AWS_ACCOUNT_ID:policy/$IAM_POLICY_NAME

sed -e 's/arn:aws:iam::123456789012:role\/eks-aws-load-balancer-controller/arn:aws:iam::409688176173:role\/eks-aws-load-balancer-controller-mt/g' rok/aws-load-balancer-controller/overlays/deploy/patches/sa.yaml > changed.txt && mv changed.txt rok/aws-load-balancer-controller/overlays/deploy/patches/sa.yaml && cat rok/aws-load-balancer-controller/overlays/deploy/patches/sa.yaml

sed -e 's/CLUSTERNAME/mt/g' rok/aws-load-balancer-controller/overlays/deploy/patches/deploy.yaml > changed.txt && mv changed.txt rok/aws-load-balancer-controller/overlays/deploy/patches/deploy.yaml && cat rok/aws-load-balancer-controller/overlays/deploy/patches/deploy.yaml

git commit -am "Configure AWS Load Balancer Controller"
rok-deploy --apply rok/aws-load-balancer-controller/overlays/deploy

###-----
# Use existing cert
###-----

export CERT=arn:aws:acm:us-east-1:409688176173:certificate/19fea3ff-552e-447c-b3f2-c3b9df8c3104
echo ${CERT?}

# aws acm request-certificate \
#      --domain-name ${SUBDOMAIN} \
#      --subject-alternative-names "*.${SUBDOMAIN}" \
#      --validation-method DNS

# export CERT=$(aws acm list-certificates | \
#      jq -r '.CertificateSummaryList[]  | select(.DomainName == "'$SUBDOMAIN'") | .CertificateArn')
# echo ${CERT?}

export AWS_ZONE_ID=$(aws route53 list-hosted-zones-by-name --output json --dns-name "${DOMAIN}." | jq -r '.HostedZones[0].Id')
echo ${AWS_ZONE_ID}

aws acm describe-certificate --certificate-arn $CERT | \
    jq -r '.Certificate.DomainValidationOptions[].ResourceRecord|.Name,.Value' | paste - - | \
        while read name value; do
            aws route53 change-resource-record-sets \
                --hosted-zone-id $AWS_ZONE_ID \
                --change-batch '{"Comment": "Add CNAME for ACM DNS Validation",
                                 "Changes": [
                                    {
                                      "Action": "UPSERT",
                                      "ResourceRecordSet": {
                                        "Name": "'$name'",
                                        "Type": "CNAME",
                                        "TTL": 300,
                                        "ResourceRecords": [
                                          {
                                            "Value": "'$value'"
                                          }
                                        ]
                                      }
                                    }
                                  ]
                                }'
        done

# watch aws acm describe-certificate --certificate-arn $CERT

sed -e 's/arn:aws:acm:us-west-1:222222222222:certificate\/9b414703-707a-4589-a0ef-86b3d38df62f/arn:aws:acm:us-east-1:409688176173:certificate\/19fea3ff-552e-447c-b3f2-c3b9df8c3104/g' rok/nginx-ingress-controller/overlays/deploy/patches/ingress-alb.yaml > changed.txt && mv changed.txt rok/nginx-ingress-controller/overlays/deploy/patches/ingress-alb.yaml && cat rok/nginx-ingress-controller/overlays/deploy/patches/ingress-alb.yaml


sed -e 's/1.2.3.4\/0.0.0.0\/0/g' rok/nginx-ingress-controller/overlays/deploy/patches/ingress-alb.yaml > changed.txt && mv changed.txt rok/nginx-ingress-controller/overlays/deploy/patches/ingress-alb.yaml && cat rok/nginx-ingress-controller/overlays/deploy/patches/ingress-alb.yaml

git commit -am "Expose NGINX Ingress Controller with an ALB"
rok-deploy --apply rok/nginx-ingress-controller/overlays/deploy


vi rok/nginx-ingress-controller/overlays/deploy/patches/service-alb.yaml

vi rok/rok-external-services/istio/istio-1-5-7/istio-install-1-5-7/overlays/deploy/kustomization.yaml

vi rok/rok-external-services/istio/istio-1-5-7/istio-install-1-5-7/overlays/deploy/patches/ingress-host.yaml

vi rok/rok-external-services/istio/istio-1-5-7/istio-install-1-5-7/overlays/deploy/kustomization.yaml

vi rok/rok-external-services/istio/istio-1-5-7/istio-install-1-5-7/overlays/deploy/kustomization.yaml

vi rok/rok-external-services/istio/istio-1-5-7/istio-install-1-5-7/overlays/deploy/trusted-front-proxies.yaml

sed -e 's/<bcrypt password hash>/$2y$12$MjGwqs4txV4Q5PXZmdxeDun07iNu.ygcNyi1fAVnWwHx7O8iRLqzy/g' kubeflow/manifests/dex-auth/dex-crds/overlays/deploy/patches/config-map.yaml > changed.txt && mv changed.txt kubeflow/manifests/dex-auth/dex-crds/overlays/deploy/patches/config-map.yaml

export OIDC_CLIENT_ID="authservice"
export OIDC_CLIENT_SECRET="$(openssl rand -base64 32)"
j2 kubeflow/manifests/dex-auth/dex-crds/overlays/deploy/secret_params.env.j2 -o kubeflow/manifests/dex-auth/dex-crds/overlays/deploy/secret_params.env
j2 kubeflow/manifests/istio/oidc-authservice/overlays/deploy/secret_params.env.j2 -o kubeflow/manifests/istio/oidc-authservice/overlays/deploy/secret_params.env

git commit -am "kubeflow: Configure authentication"

kubectl delete -k rok/rok-external-services/dex/overlays/deploy
kubectl delete -k rok/rok-external-services/authservice/overlays/deploy

rok-deploy --apply install/kubeflow

echo "    gw.ui.kubeflow_dashboard_enabled: true" >> rok/rok-cluster/overlays/deploy/patches/configvars.yaml

git add rok/rok-cluster/overlays/deploy
git commit -m "Enable Kubeflow dashboard integration"
rok-deploy --apply rok/rok-cluster/overlays/deploy

export USER=user 
export NAMESPACE=kubeflow-${USER//[^a-zA-Z0-9\-]/-}
cd ~/ops/deployments/kubeflow/manifests
mkdir -p namespace-resources/profiles
j2 namespace-resources/profile.yaml.j2 -o namespace-resources/profiles/$NAMESPACE.yaml
git add namespace-resources/profiles/$NAMESPACE.yaml
git commit -am "Create Profile for $USER"
kubectl apply -f namespace-resources/profiles/$NAMESPACE.yaml
while ! kubectl get ns $NAMESPACE; do :; done
cd ~/ops/deployments/kubeflow/manifests
mkdir -p namespace-resources/overlays/$NAMESPACE
j2 namespace-resources/kustomization.yaml.j2 -o namespace-resources/overlays/$NAMESPACE/kustomization.yaml
git add namespace-resources/overlays/$NAMESPACE
git commit -m "Set up namespace '$NAMESPACE' with access to Rok and KFP"
rok-deploy --apply namespace-resources/overlays/$NAMESPACE









#=====================================
export AWS_DEFAULT_REGION=us-east-1
echo ${AWS_DEFAULT_REGION}

export VPCID=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true | jq -r '.Vpcs[0].VpcId')    
echo ${VPCID?}
export SUBNETIDS="subnet-38d9a636"
echo ${SUBNETIDS?}
export CIDR=24.90.93.97/32  
echo ${CIDR?}
export SECURITYGROUPID=sg-0fbd1a0dc17419777 
echo ${SECURITYGROUPID?}


export CIDRS=$CIDR
echo ${CIDRS}
export CLUSTERNAME=mt2
echo ${CLUSTERNAME}

export ACCOUNT_ID=$(aws sts get-caller-identity | jq -r '.Account')
echo ${ACCOUNT_ID?}

export AWS_ACCOUNT_ID=$(aws sts get-caller-identity | jq -r '.Account')
echo ${AWS_ACCOUNT_ID?}

export AWS_IAM_USER=mtanenbaum
echo ${AWS_IAM_USER?}

export SECURITYGROUPIDS=${SECURITYGROUPID?}
echo ${SECURITYGROUPID?}
export AWS_ACCOUNT=arrikto-dev
echo ${AWS_ACCOUNT?}

aws eks create-cluster --name ${CLUSTERNAME?} --role-arn arn:aws:iam::${ACCOUNT_ID?}:role/eksServiceRole --resources-vpc-config subnetIds=${SUBNETIDS// /,},securityGroupIds=sg-0fbd1a0dc17419777,endpointPublicAccess=true,endpointPrivateAccess=true,publicAccessCidrs=0.0.0.0/0 --tags owner=${AWS_ACCOUNT?}/${AWS_IAM_USER?} --kubernetes-version 1.17

watch -n 5 aws eks describe-cluster --name ${CLUSTERNAME?}

aws eks update-kubeconfig --name $CLUSTERNAME

export INSTANCE_TYPE=m5d.2xlarge
echo ${INSTANCE_TYPE}

aws eks create-nodegroup \
     --cluster-name ${CLUSTERNAME?} \
     --nodegroup-name general-workers \
     --disk-size 300 \
     --scaling-config minSize=1,maxSize=3,desiredSize=2 \
     --subnets subnet-38d9a636 \
     --instance-types ${INSTANCE_TYPE?} \
     --ami-type AL2_x86_64 \
     --node-role arn:aws:iam::${ACCOUNT_ID?}:role/eksWorkerNodeRole \
     --labels role=general-workers \
     --tags owner=${AWS_ACCOUNT?}/${AWS_IAM_USER?},kubernetes.io/cluster/${CLUSTERNAME?}=owned \
     --release-version 1.17.12-20210310 \
     --kubernetes-version 1.17




watch -n 5 aws eks describe-nodegroup --cluster-name mt --nodegroup-name general-workers

cat<<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:sts::409688176173:assumed-role/mtanenbaum-ekf-max/i-05fb2a592c2c060ad
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: arn:aws:iam::409688176173:role/eksWorkerNodeRole
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:nodes
        - system:bootstrappers
  mapUsers: |
    - userarn: arn:aws:iam::409688176173:user/michael.tanenbaum
      username: iam-user-mtanenbaum-admin
      groups:
        - system:masters
EOF

eksctl utils associate-iam-oidc-provider --cluster $CLUSTERNAME --approve
export OIDC_PROVIDER=$(aws eks describe-cluster --name $CLUSTERNAME --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///")
aws iam get-open-id-connect-provider \
     --open-id-connect-provider-arn arn:aws:iam::$ACCOUNT_ID:oidc-provider/$OIDC_PROVIDER


export DOMAIN=aws-dev.arrikto.com
export SUBDOMAIN=a1-east.aws-dev.arrikto.com

ZONES=$(aws route53 list-hosted-zones-by-name --output json --dns-name "${DOMAIN}." | jq -r '.HostedZones[].Id' | wc -l)
[[ "$ZONES" -eq 1 ]] && echo OK

export AWS_ZONE_ID=$(aws route53 list-hosted-zones-by-name --output json --dns-name "${DOMAIN}." | jq -r '.HostedZones[].Id' | xargs) 
echo ${AWS_ZONE_ID?}

aws route53 list-resource-record-sets \
     --output json \
     --hosted-zone-id $AWS_ZONE_ID \
     --query "ResourceRecordSets[?Type == 'NS']" | \
         jq -r '.[0].ResourceRecords[].Value'

aws route53 list-resource-record-sets \
     --output json \
     --hosted-zone-id $AWS_ZONE_ID

export IAM_ROLE_NAME=eks-external-dns-$CLUSTERNAME
export IAM_ROLE_DESCRIPTION=ExternalDNS
export IAM_POLICY_NAME=AllowExternalDNSUpdates
export SERVICE_ACCOUNT_NAMESPACE=default
export SERVICE_ACCOUNT_NAME=external-dns

j2 rok/eks/iamsa-trust.json.j2 -o iam-$IAM_ROLE_NAME-trust.json
git add iam-$IAM_ROLE_NAME-trust.json
git commit -m "Add JSON trust policy document for $IAM_ROLE_NAME"

aws iam create-role \
     --role-name $IAM_ROLE_NAME \
     --assume-role-policy-document file://iam-$IAM_ROLE_NAME-trust.json \
     --description "$IAM_ROLE_DESCRIPTION"

aws iam attach-role-policy \
     --role-name $IAM_ROLE_NAME \
     --policy-arn=arn:aws:iam::$AWS_ACCOUNT_ID:policy/$IAM_POLICY_NAME


sed -e 's/arn:aws:iam::123456789012:role\/eks-external-dns/arn:aws:iam::409688176173:role\/eks-external-dns-mt/g' rok/external-dns/overlays/deploy/patches/sa.yaml > changed.txt && mv changed.txt rok/external-dns/overlays/deploy/patches/sa.yaml

sed -e 's/external-dns-test.my-org.com/aws-dev.arrikto.com/g' rok/external-dns/overlays/deploy/patches/deploy.yaml > changed.txt && mv changed.txt rok/external-dns/overlays/deploy/patches/deploy.yaml

git commit -am "Configure ExternalDNS"

rok-deploy --apply rok/external-dns/overlays/deploy

rok-deploy --apply rok/cert-manager/cert-manager-kube-system-resources/base

rok-deploy --apply rok/cert-manager/cert-manager/overlays/deploy

aws ec2 create-tags \
     --resources ${SUBNETS?} \
     --tags Key=kubernetes.io/role/elb,Value=1

export IAM_ROLE_NAME=eks-aws-load-balancer-controller-${CLUSTERNAME?}
export IAM_ROLE_DESCRIPTION="AWS Load Balancer Controller"
export IAM_POLICY_NAME=AWSLoadBalancerControllerIAMPolicy
export SERVICE_ACCOUNT_NAMESPACE=kube-system
export SERVICE_ACCOUNT_NAME=aws-load-balancer-controller

j2 rok/eks/iamsa-trust.json.j2 -o iam-$IAM_ROLE_NAME-trust.json

git add iam-$IAM_ROLE_NAME-trust.json
git commit -m "Add JSON trust policy document for $IAM_ROLE_NAME"

aws iam create-role \
     --role-name $IAM_ROLE_NAME \
     --assume-role-policy-document file://iam-$IAM_ROLE_NAME-trust.json \
     --description "$IAM_ROLE_DESCRIPTION"

aws iam attach-role-policy \
     --role-name $IAM_ROLE_NAME \
     --policy-arn=arn:aws:iam::$AWS_ACCOUNT_ID:policy/$IAM_POLICY_NAME

sed -e 's/arn:aws:iam::123456789012:role\/eks-aws-load-balancer-controller/arn:aws:iam::409688176173:role\/eks-aws-load-balancer-controller-mt/g' rok/aws-load-balancer-controller/overlays/deploy/patches/sa.yaml > changed.txt && mv changed.txt rok/aws-load-balancer-controller/overlays/deploy/patches/sa.yaml

sed -e 's/CLUSTERNAME/mt/g' rok/aws-load-balancer-controller/overlays/deploy/patches/deploy.yaml > changed.txt && mv changed.txt rok/aws-load-balancer-controller/overlays/deploy/patches/deploy.yaml

git commit -am "Configure AWS Load Balancer Controller"
rok-deploy --apply rok/aws-load-balancer-controller/overlays/deploy

aws acm request-certificate \
     --domain-name ${SUBDOMAIN} \
     --subject-alternative-names "*.${SUBDOMAIN}" \
     --validation-method DNS

export CERT=$(aws acm list-certificates | \
     jq -r '.CertificateSummaryList[]  | select(.DomainName == "'$SUBDOMAIN'") | .CertificateArn')
echo ${CERT?}

export AWS_ZONE_ID=$(aws route53 list-hosted-zones-by-name --output json --dns-name "${DOMAIN}." | jq -r '.HostedZones[0].Id')
echo ${AWS_ZONE_ID}

aws acm describe-certificate --certificate-arn $CERT | \
    jq -r '.Certificate.DomainValidationOptions[].ResourceRecord|.Name,.Value' | paste - - | \
        while read name value; do
            aws route53 change-resource-record-sets \
                --hosted-zone-id $AWS_ZONE_ID \
                --change-batch '{"Comment": "Add CNAME for ACM DNS Validation",
                                 "Changes": [
                                    {
                                      "Action": "UPSERT",
                                      "ResourceRecordSet": {
                                        "Name": "'$name'",
                                        "Type": "CNAME",
                                        "TTL": 300,
                                        "ResourceRecords": [
                                          {
                                            "Value": "'$value'"
                                          }
                                        ]
                                      }
                                    }
                                  ]
                                }'
        done

watch aws acm describe-certificate --certificate-arn $CERT


vi rok/nginx-ingress-controller/overlays/deploy/patches/ingress-alb.yaml

arn:aws:acm:us-east-1:409688176173:certificate/19fea3ff-552e-447c-b3f2-c3b9df8c3104

sed -e 's/1.2.3.4\/32/0.0.0.0\/0/g' rok/nginx-ingress-controller/overlays/deploy/patches/ingress-alb.yaml > changed.txt && mv changed.txt rok/nginx-ingress-controller/overlays/deploy/patches/ingress-alb.yaml 

kubectl get ingress -n ingress-nginx ingress-nginx -o json | jq -r '.status.loadBalancer.ingress[].hostname'

vi rok/nginx-ingress-controller/overlays/deploy/patches/service-alb.yaml

vi rok/rok-external-services/istio/istio-1-5-7/istio-install-1-5-7/overlays/deploy/kustomization.yaml

vi rok/rok-external-services/istio/istio-1-5-7/istio-install-1-5-7/overlays/deploy/patches/ingress-host.yaml

vi rok/rok-external-services/istio/istio-1-5-7/istio-install-1-5-7/overlays/deploy/kustomization.yaml

vi rok/rok-external-services/istio/istio-1-5-7/istio-install-1-5-7/overlays/deploy/kustomization.yaml

vi rok/rok-external-services/istio/istio-1-5-7/istio-install-1-5-7/overlays/deploy/trusted-front-proxies.yaml

sed -e 's/<bcrypt password hash>/$2y$12$MjGwqs4txV4Q5PXZmdxeDun07iNu.ygcNyi1fAVnWwHx7O8iRLqzy/g' kubeflow/manifests/dex-auth/dex-crds/overlays/deploy/patches/config-map.yaml > changed.txt && mv changed.txt kubeflow/manifests/dex-auth/dex-crds/overlays/deploy/patches/config-map.yaml

export OIDC_CLIENT_ID="authservice"
export OIDC_CLIENT_SECRET="$(openssl rand -base64 32)"
j2 kubeflow/manifests/dex-auth/dex-crds/overlays/deploy/secret_params.env.j2 -o kubeflow/manifests/dex-auth/dex-crds/overlays/deploy/secret_params.env
j2 kubeflow/manifests/istio/oidc-authservice/overlays/deploy/secret_params.env.j2 -o kubeflow/manifests/istio/oidc-authservice/overlays/deploy/secret_params.env

git commit -am "kubeflow: Configure authentication"

kubectl delete -k rok/rok-external-services/dex/overlays/deploy
kubectl delete -k rok/rok-external-services/authservice/overlays/deploy

rok-deploy --apply install/kubeflow

echo "    gw.ui.kubeflow_dashboard_enabled: true" >> rok/rok-cluster/overlays/deploy/patches/configvars.yaml

git add rok/rok-cluster/overlays/deploy
git commit -m "Enable Kubeflow dashboard integration"
rok-deploy --apply rok/rok-cluster/overlays/deploy

export USER=user 
export NAMESPACE=kubeflow-${USER//[^a-zA-Z0-9\-]/-}
cd ~/ops/deployments/kubeflow/manifests
mkdir -p namespace-resources/profiles
j2 namespace-resources/profile.yaml.j2 -o namespace-resources/profiles/$NAMESPACE.yaml
git add namespace-resources/profiles/$NAMESPACE.yaml
git commit -am "Create Profile for $USER"
kubectl apply -f namespace-resources/profiles/$NAMESPACE.yaml
while ! kubectl get ns $NAMESPACE; do :; done
cd ~/ops/deployments/kubeflow/manifests
mkdir -p namespace-resources/overlays/$NAMESPACE
j2 namespace-resources/kustomization.yaml.j2 -o namespace-resources/overlays/$NAMESPACE/kustomization.yaml
git add namespace-resources/overlays/$NAMESPACE
git commit -m "Set up namespace '$NAMESPACE' with access to Rok and KFP"
rok-deploy --apply namespace-resources/overlays/$NAMESPACE


