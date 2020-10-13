#!/bin/sh

# This script deletes all resources used to deploy your SAP HANA, express edition on Amazon EKS

# Delete cluster with EKSCTL
eksctl delete cluster -f create-k8s-cluster-spot-nodes.yaml 

# Delete EC2 key pair
echo 
read -p "Please enter the name of the EC2 keypair (hint: filename without .pem extension): "  ec2KeyPair
aws ec2 delete-key-pair --key-name $ec2KeyPair
rm $ec2KeyPair.pem
