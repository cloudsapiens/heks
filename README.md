[![heks logo](https://github.com/cloudsapiens/heks/blob/main/rsz_heks.png)](https://github.com/cloudsapiens/heks)

```sh
SAP HANA, express edition on Amazon Elastic Kubernetes Service
```

This project is about to provide an automated way to deploy SAP HANA, express edition to Amazon Elastic Kubernetes Service (EKS). 
AWS services used for this solution:
  - Amazon Elastic Kubernetes Service (```EKS```)
  - Amazon Elastic File System (```EFS```)
  - Amazon Elastic Cloud Compute (```EC2```)

Source of the SAP HANA, Express Edition (private repository):  [Docker Hub](https://hub.docker.com/_/sap-hana-express-edition)

# Architecture
[![hecs architecture](https://github.com/cloudsapiens/heks/blob/main/imgs/architecture.png)](https://github.com/cloudsapiens/heks/blob/main/imgs/architecture.png) 

# About SAP HANA, express edition
```SAP HANA, express edition``` is a streamlined version of the SAP HANA platform which enables developers to jumpstart application development in the cloud or personal computer to build and deploy modern applications that use up to 32GB memory. SAP HANA, express edition includes the in-memory data engine with advanced analytical data processing engines for business, text, spatial, and graph data - supporting multiple data models on a single copy of the data. 
The software license allows for both non-production and production use cases, enabling you to quickly prototype, demo, and deploy next-generation applications using SAP HANA, express edition without incurring any license fees. Memory capacity increases beyond 32GB are available for purchase at the SAP Store.

# Preparation

Please make sure that you setup the following before starting the shell script.

1) Ensure that you have an AWS Account
2) Ensure that you have created a [new user in IAM](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html)
3) Ensure that you have generated Access Key and Secret Access Key to your user and stored in a secure place
4) Ensure that you have installed AWS CLI v2.0 (see Step 0)
5) Ensure that you have configured AWS CLI with your Access Key and Secret Access Key in the desired AWS region (see Step 0)
6) Ensure that you have [installed eksctl](https://docs.aws.amazon.com/eks/latest/userguide/getting-started-eksctl.html) 
7) Ensure that you have [installed kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
8) Ensure that you signed up to [Docker Hub](https://hub.docker.com/)

### Step 0: Install AWS CLI v2.0 on your machine.

```sh
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
```
Unzip the file: 
```sh
unzip awscliv2.zip
```
Check where the current AWS CLI is installed with which command: 
```sh
which aws
```
It should be in 
```sh
/usr/bin/aws
```

Update it with the following command: 
```sh
sudo ./aws/install --bin-dir /usr/bin --install-dir /usr/bin/aws-cli --update
```
Check the version of AWS CLI: 
```sh
aws --version
```

Please follow the official AWS documentation and [set-up AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html).

### About the Script 

Saphana-k8s-deployment-script.sh is an ultimate tool to deploy SAP HANA, express edition on Amazon Elastic Kubernetes Service. It utilizes tools like AWS CLI, eksctl and kubectl. 

The script is divided into following sections:

  - Gathering information about name of cluster, AWS region to deploy to, and name of EC2 key pair
  - Generating YAML definition for kubectl to create Kubernetes cluster (```create-k8s-cluster-spot-nodes.yaml```)
  - Installing ```aws-efs-csi-driver```
  - Creating EFS Storage with a dedicated security group and inbound rule 
  - Creating Kubernetes Secret for Docker Registry to store user, password, and Docker Hub e-mail address to pull the necessary images
  - Gathering master password for SAP HANA database
  - Generating YAML file for ```ClusterRole```, ```ServiceAccount```, ```ClusterRoleBinding```, ```DaemonSet```, ```StorageClass```, ```PersistentVolume```, ```Deployment```, and ```Service``` for SAP HANA, Express Edition (```saphana-k8s-deployment.yaml```)

### Installation

Saphana-k8s-deployment-script.sh is the installed file. 

First clone this repository: 
```sh
git clone https://github.com/cloudsapiens/heks.git
```

Secondly, change the access permissions of saphana-k8s-deployment-script.sh:
```sh
chmod +x saphana-k8s-deployment-script.sh
```

Afterwards in the terminal, execut it
```sh
./saphana-k8s-deployment-script.sh
```

you will be asked for some parameters in an interactive shell.

The deployment takes about 10 minutes

### Uninstallation

The following command deletes all EKS related resources in your AWS account
```sh
eksctl delete cluster -f create-k8s-cluster-spot-nodes.yaml
```

Afterwards delete the following in the AWS management console:
 - Security Group with the name efs-sd 
 - Key pair in EC2 console
 - EFS storage 


### (Optional) Create table with HdbSQL command inside the container
 - Connect to your EKS Cluster via SSH with:
```sh 
docker ps -a <CONTAINERID> 
```
 - Execute command: 
```sh 
docker exec -ti <YOURCONTAINERID> bash
```
 - Now, you are inside the container (as user: ```hxeadm```)
 - With the command, you can connect to your DB: 
``` sh 
hdbsql -i 90 -d SYSTEMDB -u SYSTEM -p <YOURVERYSECUREPASSWORD> 
```
 - With the following simple SQL statement you can create a column-stored table with one record: 

```sh
CREATE COLUMN TABLE company_leaders (name NVARCHAR(30), position VARCHAR(30));
INSERT INTO company_leaders VALUES ('Test1', 'Lead Architect');
```
