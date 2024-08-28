#!/usr/bin/env groovy

/* IMPORTANT:
 *
 * In order to make this pipeline work, the following configuration on Jenkins is required:
 * - slave with a specific label (see pipeline.agent.label below)
 * - credentials plugin should be installed and have the secrets with the following names:
 *   + lciadm100credentials (token to access Artifactory)
 */

def defaultBobImage = 'armdocker.rnd.ericsson.se/sandbox/adp-staging/adp-cicd/bob.2.0:1.7.0-55'
def bob = new BobCommand()
        .bobImage(defaultBobImage)
        .envVars([ISO_VERSION: '${ISO_VERSION}'])
        .needDockerSocket(true)
        .toString()
def failedStage = ''
def GIT_COMMITTER_NAME = 'lciadm100'
def GIT_COMMITTER_EMAIL = 'lciadm100@ericsson.com'
pipeline {
    agent {
        label 'Cloud-Native'
    }
    environment{
        repositoryUrl = "https://arm2s11-eiffel004.eiffel.gic.ericsson.se:8443/nexus/content/repositories/cloud-native-enm-sdk/templates"
        CSAR_PACKAGE_NAME = "pm-sdk-templates"
        OPENIDM = "eric-enm-openidm-change-password:latest"
        PASSKEY = "eric-enm-securestorage-regen-passkey:latest"
        OPENIDM_IMAGE_PATH = "armdocker.rnd.ericsson.se/proj-enm"
        PASSKEY_IMAGE_PATH = "armdocker.rnd.ericsson.se/proj-enm"
        PACKAGE_TYPE="releases"
        CENMBUILD_ARM_TOKEN = credentials('cenmbuild_ARM_token')
    }
    parameters {
        string(name: 'ISO_VERSION', defaultValue: '0.0.0', description: 'The ENM ISO version (e.g. 1.65.77)')
        string(name: 'SPRINT_TAG', description: 'Tag for GIT tagging the repository after build')
    }
    stages {
        stage('Inject Credential Files') {
            steps {
                withCredentials([file(credentialsId: 'lciadm100-docker-auth', variable: 'dockerConfig')]) {
                    sh "install -m 600 ${dockerConfig} ${HOME}/.docker/config.json"
                }
            }
        }
        stage('Checkout Git Repository') {
            steps {
                git branch: 'master',
                     credentialsId: 'lciadm100_private_key',
                     url: '${GERRIT_MIRROR}/OSS/ENM-Parent/SQ-Gate/com.ericsson.oss.mediation.sdk/pm-sdk-templates'
                sh '''
                    git remote set-url origin --push ${GERRIT_CENTRAL}/OSS/ENM-Parent/SQ-Gate/com.ericsson.oss.mediation.sdk/pm-sdk-templates
                '''
            }
        }
        stage('Helm Dep Up ') {
            steps {
                sh "${bob} helm-dep-up"
            }
            post {
                failure {
                    script {
                        failedStage = env.STAGE_NAME
                    }
                }
            }
        }
        stage('Merge values files') {
            steps{
                 script {
                     appconfig_values = sh (script: "ls ${WORKSPACE}/chart/eric-enmsg-custom-pm-oneflow/appconfig/ | grep values.yaml", returnStatus: true)
                     if (appconfig_values == 0) {
                          sh("${bob} merge-values-files-with-appconfig")
                     } else {
                          sh("${bob} merge-values-files")
                     }
                     sh '''
                         if git status | grep 'values.yaml' > /dev/null; then
                            git add chart/eric-enmsg-custom-pm-oneflow/values.yaml
                            git commit -m "NO JIRA - Merging Values.yaml file with common library values.yaml"
                         fi
                     '''
                }
            }
            post {
                failure {
                    script {
                        failedStage = env.STAGE_NAME
                    }
                }
            }
        }
        stage('Helm Lint') {
            steps {
                sh "${bob} lint-helm"
            }
            post {
                failure {
                    script {
                        failedStage = env.STAGE_NAME
                    }
                }
            }
        }
        stage('Linting Dockerfile') {
            steps {
                sh "${bob} lint-dockerfile"
                archiveArtifacts '*dockerfilelint.log'
            }
            post {
                failure {
                    script {
                        failedStage = env.STAGE_NAME
                    }
                }
            }
        }
        stage('ADP Helm Design Rule Check') {
            steps {
                sh "${bob} test-helm || true"
                archiveArtifacts 'design-rule-check-report.*'
            }
            post {
                failure {
                    script {
                        failedStage = env.STAGE_NAME
                    }
                }
            }
        }
        stage('Swap versions in Dockerfile and values.yaml file'){
            steps{
                echo sh(script: 'env', returnStdout:true)
                sh "sed -i s/ERIC_ENM_PMSDK_IMAGE_TAG=.*/ERIC_ENM_PMSDK_IMAGE_TAG=${env.ERIC_ENM_PMSDK_IMAGE_TAG}/g Dockerfile"
                step ([$class: 'CopyArtifact', projectName: 'sync-build-trigger', filter: "*"]);
                sh "${bob} swap-latest-versions-with-numbers"
                sh '''
                    if git status | grep 'Dockerfile\\|values.yaml' > /dev/null; then
                        git commit -m "NO JIRA - Updating Dockerfile and Values.yaml files with base images version"
                        git push origin HEAD:master
                    else
                        echo `date` > timestamp
                        git add timestamp
                        git commit -m "NO JIRA - Time Stamp "
                        git push origin HEAD:master
                    fi
                '''
            }
        }
        stage('Generate new version') {
            steps {
                sh "${bob} generate-new-version"
                script {
                    env.VERSION = sh(script: "cat .bob/var.version", returnStdout:true).trim()
                    echo "Generated VERSION is: ${VERSION}"
                    env.RSTATE = sh(script: "cat .bob/var.rstate", returnStdout:true).trim()
                    echo "Generated RSTATE is: ${RSTATE}"
                }
            }
            post {
                failure {
                    script {
                        failedStage = env.STAGE_NAME
                    }
                }
            }
        }
        stage('Generate PMSDK templates tar/zip file ') {
            steps {
                sh "${bob} generate-pmsdk"
            }
            post {
                failure {
                    script {
                        failedStage = env.STAGE_NAME
                    }
                }
            }
        }
        stage('Publish PMSDK templates to Nexus') {
            steps {
              script {
               env.filesize = sh(script: "du -h build/${CSAR_PACKAGE_NAME}-${VERSION}.tar.gz | cut -f1", returnStdout: true).trim()
               sh "bash upload_to_nexus.sh ${VERSION} build/${CSAR_PACKAGE_NAME}-${VERSION}.tar.gz ${repositoryUrl} ${CSAR_PACKAGE_NAME} ${PACKAGE_TYPE}"
              }
            }
        }
        stage('Generate ADP Parameters') {
            steps {
                sh "${bob} generate-output-parameters"
                archiveArtifacts 'artifact.properties'
            }
            post {
                failure {
                    script {
                        failedStage = env.STAGE_NAME
                    }
                }
            }
        }
        stage('Tag PMSDK templates Repository') {
            steps {
                wrap([$class: 'BuildUser']) {
                    script {
                        def bobWithCommitterInfo = new BobCommand()
                                .bobImage(defaultBobImage)
                                .needDockerSocket(true)
                                .envVars([
                                        'AUTHOR_NAME'        : "\${BUILD_USER:-${GIT_COMMITTER_NAME}}",
                                        'AUTHOR_EMAIL'       : "\${BUILD_USER_EMAIL:-${GIT_COMMITTER_EMAIL}}",
                                        'GIT_COMMITTER_NAME' : "${GIT_COMMITTER_NAME}",
                                        'GIT_COMMITTER_EMAIL': "${GIT_COMMITTER_EMAIL}"
                                ])
                                .toString()
                        sh "${bobWithCommitterInfo} create-git-tag"
                        sh """
                            tag_id=\$(cat .bob/var.version)
                            git push origin \${tag_id}
                        """
                    }
                }
            }
            post {
                failure {
                    script {
                        failedStage = env.STAGE_NAME
                    }
                }
                always {
                    script {
                        sh "${bob} remove-git-tag"
                    }
                }
            }
        }
        }
    post {
        success {
            script {
                sh '''
                    set +x
                    git tag --annotate --message "Tagging latest in sprint" --force $SPRINT_TAG HEAD
                    git push --force origin $SPRINT_TAG
                    git tag --annotate --message "Tagging latest in sprint with ISO version" --force ${SPRINT_TAG}_iso_${ISO_VERSION} HEAD
                    git push --force origin ${SPRINT_TAG}_iso_${ISO_VERSION}
                '''
            }
        }
        failure {
            mail to: '${GERRIT_CHANGE_OWNER_EMAIL},${GERRIT_PATCHSET_UPLOADER_EMAIL}',
                    subject: "Failed Pipeline: ${currentBuild.fullDisplayName}",
                    body: "Failure on ${env.BUILD_URL}"
        }
    }
}


// More about @Builder: http://mrhaki.blogspot.com/2014/05/groovy-goodness-use-builder-ast.html
import groovy.transform.builder.Builder
import groovy.transform.builder.SimpleStrategy

@Builder(builderStrategy = SimpleStrategy, prefix = '')
class BobCommand {
    def bobImage = 'bob.2.0:latest'
    def envVars = [:]
    def needDockerSocket = false

    String toString() {
        def env = envVars
                .collect({ entry -> "-e ${entry.key}=\"${entry.value}\"" })
                .join(' ')

        def cmd = """\
            |docker run
            |--init
            |--rm
            |--workdir \${PWD}
            |--user \$(id -u):\$(id -g)
            |-v \${PWD}:\${PWD}
            |-v /etc/group:/etc/group:ro
            |-v /etc/passwd:/etc/passwd:ro
            |-v \${HOME}/.m2:\${HOME}/.m2
            |-v \${HOME}/.docker:\${HOME}/.docker
            |${needDockerSocket ? '-v /var/run/docker.sock:/var/run/docker.sock' : ''}
            |${env}
            |\$(for group in \$(id -G); do printf ' --group-add %s' "\$group"; done)
            |--group-add \$(stat -c '%g' /var/run/docker.sock)
            |${bobImage}
            |"""
        return cmd
                .stripMargin()           // remove indentation
                .replace('\n', ' ')      // join lines
                .replaceAll(/[ ]+/, ' ') // replace multiple spaces by one
    }
}
