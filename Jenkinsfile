import groovy.json.JsonOutput

pipeline {
    environment {
        // === KEYCLOAK ON CLUSTER VARIABLES
        // the script filepath in your repo
        KC_EXPORT_SCRIPT_REPO_FILEPATH="keycloak-auto-export-script.sh"  // TODO: fill this  
        // Check out docs to see how to create a kubeconfig file:: create-kubeconfig-for-keycloak-backups.md
        KC_SERVICE_ACCOUNT_KUBECONFIG_CREDENTIALS_ID="" // TODO: fill this
        CLUSTER_NAME="" // TODO: fill this
        KC_NAMESPACE=""  // TODO: fill this
        KC_STATEFULSET_NAME="" // TODO: fill this

        // === S3 Upload Variables
        AWS_ACCESS_KEY_ID=credentials('s3-keycloak-backup-user-key-id') // TODO: fill this
        AWS_SECRET_ACCESS_KEY=credentials('s3-keycloak-backup-user-access-key') // TODO: fill this
        S3_BUCKET_NAME="keycloak-backup" // TODO: fill this
        // uncomment below to use a custom endpoint for S3 Compatible Storage
        // AWS_ENDPOINT_URL_S3="https://obs.tr-west-1.myhuaweicloud.com"  // (e.g. Customized endpoint for Huawei S3)


        // === STATIC VARIABLES (DON'T CHANGE THESE!)
        DEBIAN_FRONTEND = 'noninteractive'
        // TZ = 'Europe/Istanbul'
        KC_EXPORTED_ZIP_PATH_IN_CONTAINER='/tmp/keycloak-auto-backups.tar'  // this value comes from the KC_EXPORT_SCRIPT_REPO_FILEPATH script
    } 
    agent {
        node {
            label 'linux'
        }
    }
    stages {
        stage('Keycloak Container Export Backup') {
            // - Finds the pod name of the keycloak container (for kubectl exec|cp)
            // - `kubectl cp` copies the export bash script to container
            // - run the export script inside the container with `kubectl exec`
            // - `kubectl cp` copies the .tar export file to jenkins worker
            steps {
                withCredentials([file(credentialsId: KC_SERVICE_ACCOUNT_KUBECONFIG_CREDENTIALS_ID, variable: 'JKUBECONF')]) {
                    sh """
                    #!/bin/bash

                    # check if the Export Script exists in the cicd repo
                    if [ ! -e "$KC_EXPORT_SCRIPT_REPO_FILEPATH" ]; then
                        echo "Directory KC_EXPORT_SCRIPT_REPO_FILEPATH=$KC_EXPORT_SCRIPT_REPO_FILEPATH does not exist."
                        echo "Bu degiskeni tanimlaman gerek. 'cicd' reposunda bir  '.sh' bash script olmali."
                        exit 1
                    fi

                    echo "KC_NAMESPACE=$KC_NAMESPACE"
                    echo "KC_STATEFULSET_NAME=$KC_STATEFULSET_NAME"
                    echo "KC_EXPORT_SCRIPT_REPO_FILEPATH=$KC_EXPORT_SCRIPT_REPO_FILEPATH"

                    # find the ns, and pod name to exec the export script
                    export POD_NAME=\$(kubectl --kubeconfig "\$JKUBECONF" -n "\$KC_NAMESPACE" \
                        get pod -l app.kubernetes.io/name=keycloak \
                        -o custom-columns=:metadata.name --no-headers)
                    echo "Found the Keycloak pod: POD_NAME=\$POD_NAME"

                    echo "Copying the \$KC_EXPORT_SCRIPT_REPO_FILEPATH to the pod: \$POD_NAME"
                    kubectl --kubeconfig "\$JKUBECONF" -n "\$KC_NAMESPACE" \
                        cp "\$KC_EXPORT_SCRIPT_REPO_FILEPATH" \
                        "\$POD_NAME:/tmp/keycloak-auto-export-script.sh"
                    
                    
                    echo "Making /tmp/keycloak-auto-export-script.sh executable in the pod: \$POD_NAME"
                    kubectl --kubeconfig "\$JKUBECONF" -n "\$KC_NAMESPACE" \
                        exec --stdin "\$POD_NAME" -- \
                            bash -c 'chmod +x /tmp/keycloak-auto-export-script.sh'

                    echo "Running the /tmp/keycloak-auto-export-script.sh script in the pod: \$POD_NAME"
                    kubectl  --kubeconfig "\$JKUBECONF" -n "\$KC_NAMESPACE" \
                        exec --stdin "\$POD_NAME" -- \
                            './tmp/keycloak-auto-export-script.sh'

                    echo "Export finished in keycloak pod: \$POD_NAME"


                    echo "Copying the \$KC_EXPORTED_ZIP_PATH_IN_CONTAINER file in the container to Jenkins workspace"
                    kubectl --kubeconfig "\$JKUBECONF" -n "\$KC_NAMESPACE" \
                        cp "\$POD_NAME:\$KC_EXPORTED_ZIP_PATH_IN_CONTAINER" \
                        "./keycloak-auto-backups.tar"

                    ls -lah keycloak-auto-backups.tar

                    # show the contents of the zip file
                    tar -tvf keycloak-auto-backups.tar

                    echo "Export complete, moving on to S3 upload..."
                    """

                    // stash our keycloak-export-tar so it can be used in the next stage
                    stash name: 'keycloak-export-tar', includes: 'keycloak-auto-backups.tar' 
                }
            }
        }
        stage('Upload to S3') {
            // Uses AWS CLI docker image to have access to the awscli 
            // - Uploads the keycloak-export-tar to S3 with filename: 
            //   s3://${S3_BUCKET_NAME}/${CLUSTER_NAME}/${KC_NAMESPACE}/keycloak-backup--${KC_STATEFULSET_NAME}-$(date +%Y-%m--%d-%H-%M).tar
            agent {
                docker {
                    reuseNode true 
                    image "public.ecr.aws/aws-cli/aws-cli:2.13.32" // use ECR image to avoid docker login
                    args '--entrypoint ""'  // override the entrypoint to use bash
                }
            }
            steps {
                 // move the stashed keycloak-export-tar to the current stage
                unstash 'keycloak-export-tar'

                // do the upload
                sh 'echo "Inside AWS CLI docker image, will upload the following file to S3:"'
                sh 'echo "AWS CLI is configured to upload the endpoint: ${AWS_ENDPOINT_URL_S3}"'
                sh 'ls -alh keycloak-auto-backups.tar'

                sh 'echo "Trying to upload to S3 at folder: s3://${S3_BUCKET_NAME}/${CLUSTER_NAME}/${KC_NAMESPACE}/"'
                sh 'aws s3 cp keycloak-auto-backups.tar s3://${S3_BUCKET_NAME}/${CLUSTER_NAME}/${KC_NAMESPACE}/keycloak-backup--${KC_STATEFULSET_NAME}-$(date +%Y-%m-%d--%H-%M).tar'

                sh 'echo "S3 Upload is complete, heres the current content of s3://${S3_BUCKET_NAME}/${CLUSTER_NAME}/${KC_NAMESPACE}/ :"'
                sh 'aws s3 ls s3://${S3_BUCKET_NAME}/${CLUSTER_NAME}/${KC_NAMESPACE}/'
            }
        }
    }
    options {
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '30'))  // keep last N builds
        timeout(time: 10, unit: 'MINUTES') 
    }
    // triggers {
    //     cron('0 0 * * *') // everyday at midnight
    // }
}