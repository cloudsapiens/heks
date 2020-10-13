#!/bin/sh

# This script creates all resources used to deploy your SAP HANA, express edition on Amazon EKS

clear
echo "Welcome to heks, the ultimate SAP HANA, express edition installer powered by Amazon Elastic Kubernetes Service (EKS)!"
echo 
read -p "Please enter the name of your EKS cluster: "  eksClusterName
echo 
read -p "Please enter the region of your EKS cluster (should be the same to your AWS CLI region e.g. us-east-1): "  eksClusterRegion
echo 
read -p "Please enter the name of EC2 key pair to be used to SSH to the k8s cluster (you will find the .pem file in the installer folder): "  eksKeyPairName

# Generates new EC2 key pair and saves .pem file to the installation folder
aws ec2 create-key-pair --key-name $eksKeyPairName --query 'KeyMaterial' --output text > $eksKeyPairName.pem

# Created EKS cluster based on provided information
echo "
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
    name: $eksClusterName
    region: $eksClusterRegion
nodeGroups:
    - name: saphana-spot-nodegroup
      minSize: 1
      maxSize: 1
      desiredCapacity: 1
      ssh:
        publicKeyName: $eksKeyPairName
      instancesDistribution:
        instanceTypes: ['r4.xlarge'] 
        onDemandBaseCapacity: 0
        onDemandPercentageAboveBaseCapacity: 0
        spotAllocationStrategy: capacity-optimized
      labels:
        lifecycle: Ec2Spot
        intent: apps
        aws.amazon.com/spot: 'true'
      taints:
        spotInstance: 'true:PreferNoSchedule'
      tags:
        k8s.io/cluster-autoscaler/node-template/label/lifecycle: Ec2Spot
        k8s.io/cluster-autoscaler/node-template/label/intent: apps
        k8s.io/cluster-autoscaler/node-template/label/aws.amazon.com/spot: 'true'
        k8s.io/cluster-autoscaler/node-template/taint/spotInstance: 'true:PreferNoSchedule'
      iam:
        withAddonPolicies:
          autoScaler: true
          cloudWatch: true
          albIngress: true" > create-k8s-cluster-spot-nodes.yaml     

# Creates a Kubernetes cluster with an unmanaged NodeGroup of one R4.XLARGE spot instance
eksctl create cluster -f create-k8s-cluster-spot-nodes.yaml

# Creates a secret based on entered username and password to fetch the private SAP HANA, Express Edition Docker image from DockerHub repository
echo 
read -p "Please enter your username for login to DockerHub: "  dockerhubUsername
unset dockerhubPassword
echo 
promptDockerhub="Please enter your password for login to DockerHub:"
while IFS= read -p "$promptDockerhub" -r -s -n 1 char
do
    if [[ $char == $'\0' ]]
    then
        break
    fi
    promptDockerhub='*'
    dockerhubPassword+="$char"
done
echo 
echo
read -p "Please enter your e-mail addressed used for DockerHub: "  dockerhubEmail
kubectl create secret docker-registry docker-secret --docker-server=https://index.docker.io/v1/ --docker-username=$dockerhubUsername --docker-password=$dockerhubPassword --docker-email=$dockerhubEmail

# Asks user to enter SAP HANA master password
unset sapHanaMasterPassword
echo 
promptSapHana="Please enter master password for SAP HANA:"
echo
while IFS= read -p "$promptSapHana" -r -s -n 1 char
do
    if [[ $char == $'\0' ]]
    then
        break
    fi
    promptSapHana='*'
    sapHanaMasterPassword+="$char"
done

# Generates YAML file for ClusterRole, ServiceAccount, ClusterRoleBinding, DaemonSet, StorageClass, PersistentVolume, PersistentVolumeClaim, Deployment, and Service for SAP HANA, Express Edition
echo "
  kind: ClusterRole
  apiVersion: rbac.authorization.k8s.io/v1
  metadata:
    name: spot-interrupt-handler
    namespace: kube-system
  rules:
  - apiGroups:
    - ''
    resources:
    - '*'
    verbs:
    - '*'
  - apiGroups:
    - rbac.authorization.k8s.io
    resources:
    - '*'
    verbs:
    - '*'
  - apiGroups:
    - apiextensions.k8s.io
    resources:
    - customresourcedefinitions
    verbs:
    - get
    - list
    - watch
    - create
    - delete
---
  apiVersion: v1
  kind: ServiceAccount
  metadata:
    name: spot-interrupt-handler
    namespace: kube-system
---
  kind: ClusterRoleBinding
  apiVersion: rbac.authorization.k8s.io/v1
  metadata:
    name: spot-interrupt-handler
    namespace: kube-system
  subjects:
  - kind: ServiceAccount
    name: spot-interrupt-handler
    namespace: kube-system
  roleRef:
    kind: ClusterRole
    name: spot-interrupt-handler
    apiGroup: rbac.authorization.k8s.io
---
  apiVersion: apps/v1
  kind: DaemonSet
  metadata:
    name: spot-interrupt-handler
    namespace: kube-system
  spec:
    selector:
      matchLabels:
        app: spot-interrupt-handler
    template:
      metadata:
        labels:
          app: spot-interrupt-handler
      spec:
        serviceAccountName: spot-interrupt-handler
        containers:
        - name: spot-interrupt-handler
          image: 'madhuriperi/samplek8spotinterrupt:latest'
          imagePullPolicy: Always
          env:
          - name: POD_NAME
            valueFrom:
              fieldRef:
                fieldPath: metadata.name
          - name: NAMESPACE
            valueFrom:
              fieldRef:
                fieldPath: metadata.namespace
          - name: SPOT_POD_IP
            valueFrom:
              fieldRef:
                fieldPath: status.podIP
        nodeSelector:
          lifecycle: Ec2Spot
---
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: hxe
    labels:
      name: hxe
  spec:
    selector:
      matchLabels:
        run: hxe
        app: hxe
        role: master
        tier: backend
    replicas: 1
    template:
      metadata:
        labels:
          run: hxe
          app: hxe
          role: master
          tier: backend
      spec:
        imagePullSecrets:
        - name: docker-secret
        volumes:
          - name: hxe-data
            emptyDir: {}
        containers:
        - name: hxe-container
          image: 'store/saplabs/hanaexpress:2.00.045.00.20200121.1'
          imagePullPolicy: Always
          ports:
            - containerPort: 39013
              name: port1
            - containerPort: 39017
              name: port2
            - containerPort: 39041
              name: port3
            - containerPort: 39042
              name: port4
            - containerPort: 39043
              name: port5
            - containerPort: 39044
              name: port6
            - containerPort: 39045
              name: port7
            - containerPort: 1128
              name: port8
            - containerPort: 1129
              name: port9
            - containerPort: 59013
              name: port10
            - containerPort: 59014
              name: port11                                       
          args: [ --agree-to-sap-license, --dont-check-system, --master-password, $sapHanaMasterPassword ]
          volumeMounts:
            - name: hxe-data
              mountPath: /hana/mounts
---
  apiVersion: v1
  kind: Service
  metadata:
    name: hxe-connect
    labels:
      app: hxe
  spec:
    type: LoadBalancer
    ports:
    - port: 39013
      targetPort: 39013
      name: port1
    - port: 39017
      targetPort: 39017
      name: port2
    - port: 39041
      targetPort: 39041
      name: port3
    - port: 39042
      targetPort: 39042
      name: port4
     - port: 39043
      targetPort: 39043
      name: port5     
    - port: 39044
      targetPort: 39044
      name: port6
    - port: 39045
      targetPort: 39045
      name: port7
    - port: 1128
      targetPort: 1128
      name: port8
    - port: 1129
      targetPort: 1129
      name: port9
    - port: 59013
      targetPort: 59013
      name: port10
    - port: 59014
      targetPort: 59014
      name: port11
    selector:
      app: hxe" > saphana-k8s-deployment.yaml

# Deploys SAP HANA, Express Edition to a Pod
kubectl create -f saphana-k8s-deployment.yaml

# Provides information about pods
kubectl get pods

echo
echo "Setup completed. Your SAP HANA, express edition will be up and running in a few minutes."