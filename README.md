# jenkins-job-backup-keycloak

A jenkins job to backup running bitnami Keycloak container in a K8s cluster.


## Index

- [Create kubeconfig for Keycloak Backups](create-kubeconfig-for-keycloak-backups.md)
- [keycloak-auto-export-script.sh](keycloak-auto-export-script.sh)
- [Jenkinsfile](Jenkinsfile)

## About the pipeline

- finds which pod to `exec` into
- `kubectl cp` copies the `keycloak-auto-export-script.sh` script into keycloak container
- `kubectl exec` into the running keycloak container and runs our script
- `kubectl cp` copies the backup file from the keycloak container to the jenkins workspace
- `aws s3 cp` copies the backup file to an S3 compatible bucket (in this pipeline it's Huawei OBS)
  - Upload path is: `s3://${S3_BUCKET_NAME}/${CLUSTER_NAME}/${KC_NAMESPACE}/keycloak-backup--${KC_STATEFULSET_NAME}-$(date +%Y-%m-%d--%H-%M).tar`

## How to implement it

- Follow [Create kubeconfig for Keycloak Backups](create-kubeconfig-for-keycloak-backups.md) to:
  - Create ClusterRole, ServiceAccount, ClusterRoleBinding, Secret for sa token
  - Create kubeconfig file for the Service Account we just created
  - Create a Jenkins credential of type `Secret file` with the kubeconfig file we just created
- Copy the [keycloak-auto-export-script.sh](keycloak-auto-export-script.sh) and [Jenkinsfile](Jenkinsfile) to your CICD repo
- Fill in the `environment` in the Jenkinsfile with your values
  - `KC_EXPORT_SCRIPT_REPO_FILEPATH`: Relative filepath for `keycloak-auto-export-script.sh` script in your repo
  - `KC_SERVICE_ACCOUNT_KUBECONFIG_CREDENTIALS_ID`: The Jenkins credential ID of the kubeconfig file we created
  - `CLUSTER_NAME`: Your cluster name (will be used as the backup file name)
  - `KC_NAMESPACE`: Keycloak instance namespace
  - `KC_STATEFULSET_NAME`: Keycloak statefulset name
  - `AWS_ACCESS_KEY_ID`: (you should use Jenkins credentials for this)
  - `AWS_SECRET_ACCESS_KEY`: (you should use Jenkins credentials for this)
  - `S3_BUCKET_NAME`: S3 bucket name
