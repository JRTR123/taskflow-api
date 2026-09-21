pipeline {

    agent { label 'linux-build' }

    environment {
        APP_NAME = 'taskflow-api'
        NODE_ENV = 'test'
        REGISTRY = 'localhost:5000'
    }

    parameters {
        booleanParam(
            name: 'FAIL_HEALTH',
            defaultValue: false,
            description: 'Build an image whose /health returns 500 (rollback demo)'
        )
        booleanParam(
            name: 'RUN_IAC',
            defaultValue: false,
            description: 'Run Terraform plan/apply + Ansible (Lab 08). Leaves a pause for approval.'
        )
    }

    options {
        timeout(time: 45, unit: 'MINUTES')
    }

    stages {

        /*
         * ==========================================
         * INSTALL
         * ==========================================
         */
        stage('Install') {
            steps {
                sh 'sh scripts/docker-run.sh -u "$(id -u):$(id -g)" -e HOME=/tmp node:20-alpine npm ci'
            }
        }


        /*
         * ==========================================
         * 1. GITLEAKS - SECRET DETECTION
         * ==========================================
         */
        stage('Secrets Detection') {

            steps {
                sh '''
                    sh scripts/docker-run.sh \
                      zricethezav/gitleaks:latest \
                      detect \
                      --source="$WORKSPACE" \
                      --log-opts="-n 1" \
                      --report-format=sarif \
                      --report-path="$WORKSPACE/gitleaks.sarif" \
                      --exit-code=1
                '''
            }

            post {
                always {
                    archiveArtifacts(
                        artifacts: 'gitleaks.sarif',
                        allowEmptyArchive: true
                    )
                }
            }
        }


        /*
         * ==========================================
         * 2. SAST
         * ESLint Security + Semgrep
         * ==========================================
         */
        stage('SAST') {

            parallel {

                stage('ESLint Security') {

                    steps {
                        sh '''
                            sh scripts/docker-run.sh \
                              -u "$(id -u):$(id -g)" \
                              -e HOME=/tmp \
                              node:20-alpine \
                              sh -c "npm install --no-save eslint-plugin-security @microsoft/eslint-formatter-sarif && npx eslint src/ -f @microsoft/eslint-formatter-sarif -o eslint-security.sarif || true"
                        '''
                    }

                    post {
                        always {
                            archiveArtifacts(
                                artifacts: 'eslint-security.sarif',
                                allowEmptyArchive: true
                            )
                        }
                    }
                }


                stage('Semgrep') {

                    steps {
                        sh '''
                            sh scripts/docker-run.sh \
                              semgrep/semgrep \
                              semgrep \
                              --config=p/owasp-top-ten \
                              --config=p/nodejs \
                              --sarif \
                              -o "$WORKSPACE/semgrep.sarif" \
                              "$WORKSPACE" || true
                        '''
                    }

                    post {
                        always {
                            archiveArtifacts(
                                artifacts: 'semgrep.sarif',
                                allowEmptyArchive: true
                            )
                        }
                    }
                }
            }
        }


        /*
         * ==========================================
         * 3. SCA - NPM AUDIT
         * Block ONLY CRITICAL
         * High/Moderate/Low = warning
         * ==========================================
         */
        stage('SCA — npm audit') {

            steps {
                script {

                    sh '''
                        sh scripts/docker-run.sh \
                          -u "$(id -u):$(id -g)" \
                          -e HOME=/tmp \
                          node:20-alpine \
                          sh -c "npm audit --audit-level=high --json > audit.json || true"
                    '''

                    def critical = sh(
                        script: '''
                            sh scripts/docker-run.sh -u "$(id -u):$(id -g)" -e HOME=/tmp node:20-alpine \
                              node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync('audit.json')); console.log(data.metadata && data.metadata.vulnerabilities && data.metadata.vulnerabilities.critical || 0);"
                        ''',
                        returnStdout: true
                    ).trim().toInteger()

                    def high = sh(
                        script: '''
                            sh scripts/docker-run.sh -u "$(id -u):$(id -g)" -e HOME=/tmp node:20-alpine \
                              node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync('audit.json')); console.log(data.metadata && data.metadata.vulnerabilities && data.metadata.vulnerabilities.high || 0);"
                        ''',
                        returnStdout: true
                    ).trim().toInteger()

                    def moderate = sh(
                        script: '''
                            sh scripts/docker-run.sh -u "$(id -u):$(id -g)" -e HOME=/tmp node:20-alpine \
                              node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync('audit.json')); console.log(data.metadata && data.metadata.vulnerabilities && data.metadata.vulnerabilities.moderate || 0);"
                        ''',
                        returnStdout: true
                    ).trim().toInteger()

                    def low = sh(
                        script: '''
                            sh scripts/docker-run.sh -u "$(id -u):$(id -g)" -e HOME=/tmp node:20-alpine \
                              node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync('audit.json')); console.log(data.metadata && data.metadata.vulnerabilities && data.metadata.vulnerabilities.low || 0);"
                        ''',
                        returnStdout: true
                    ).trim().toInteger()

                    echo "======================================"
                    echo "NPM AUDIT RESULT"
                    echo "Critical : ${critical}"
                    echo "High     : ${high}"
                    echo "Moderate : ${moderate}"
                    echo "Low      : ${low}"
                    echo "======================================"

                    if (critical > 0) {
                        echo "WARNING: ${critical} CRITICAL finding(s). Policy Gate will block the build."
                    } else {
                        echo "SCA: 0 CRITICAL vulnerabilities"
                    }

                    if (high > 0 || moderate > 0 || low > 0) {
                        echo "WARNING: non-CRITICAL vulnerabilities present (build continues)."
                    }
                }
            }

            post {
                always {
                    archiveArtifacts(
                        artifacts: 'audit.json',
                        allowEmptyArchive: true
                    )
                }
            }
        }


        /*
         * ==========================================
         * Convert npm audit -> scan-result.json
         * ==========================================
         */
        stage('Prepare Security Scan Result') {

            steps {

                sh '''
                    sh scripts/docker-run.sh \
                      -u "$(id -u):$(id -g)" \
                      -e HOME=/tmp \
                      node:20-alpine \
                      node scripts/audit-to-scan-result.js audit.json scan-result.json
                    echo "=== scan-result.json ==="
                    cat scan-result.json
                '''
            }

            post {
                always {
                    archiveArtifacts(
                        artifacts: 'scan-result.json',
                        allowEmptyArchive: true
                    )
                }
            }
        }


        /*
         * ==========================================
         * 4. SBOM
         * Syft -> CycloneDX JSON
         * ==========================================
         */
        stage('Generate SBOM') {

            steps {

                sh '''
                    sh scripts/docker-run.sh \
                      anchore/syft:latest \
                      dir:. \
                      -o cyclonedx-json=taskflow-api.cdx.json
                '''
            }

            post {
                always {
                    archiveArtifacts(
                        artifacts: 'taskflow-api.cdx.json',
                        allowEmptyArchive: true
                    )
                }
            }
        }


        /*
         * ==========================================
         * 5. SIGN SBOM
         * Cosign
         * ==========================================
         */
        stage('Sign SBOM') {

            steps {
                sh '''
                    rm -f cosign.key cosign.pub taskflow-api.cdx.json.sig
                    sh scripts/docker-run.sh \
                      -u "$(id -u):$(id -g)" \
                      -e COSIGN_PASSWORD=lab \
                      -e COSIGN_YES=true \
                      gcr.io/projectsigstore/cosign:v2.4.1 \
                      generate-key-pair

                    sh scripts/docker-run.sh \
                      -u "$(id -u):$(id -g)" \
                      -e COSIGN_PASSWORD=lab \
                      -e COSIGN_YES=true \
                      gcr.io/projectsigstore/cosign:v2.4.1 \
                      sign-blob --yes --key cosign.key \
                      --output-signature taskflow-api.cdx.json.sig \
                      taskflow-api.cdx.json

                    ls -l taskflow-api.cdx.json taskflow-api.cdx.json.sig cosign.pub
                '''
            }

            post {
                always {
                    archiveArtifacts(
                        artifacts: 'taskflow-api.cdx.json,taskflow-api.cdx.json.sig,cosign.pub',
                        allowEmptyArchive: true
                    )
                }
            }
        }


        /*
         * ==========================================
         * 6. OPA POLICY GATE
         * ==========================================
         */
        stage('Policy Gate') {

            steps {

                script {

                    sh '''
                        sh scripts/docker-run.sh \
                          openpolicyagent/opa:0.70.0 \
                          eval \
                          --data policy/security.rego \
                          --input scan-result.json \
                          data.security.deny \
                          --format pretty
                    '''

                    def denyCount = sh(
                        script: '''
                            sh scripts/docker-run.sh \
                              openpolicyagent/opa:0.70.0 \
                              eval --format raw \
                              --data policy/security.rego \
                              --input scan-result.json \
                              'count(data.security.deny)'
                        ''',
                        returnStdout: true
                    ).trim().toInteger()

                    echo "OPA deny count = ${denyCount}"

                    if (denyCount > 0) {

                        error(
                            "POLICY GATE BLOCKED: ${denyCount} CRITICAL vulnerability detected"
                        )

                    }

                    echo "POLICY GATE PASSED"
                }
            }

            post {
                always {

                    archiveArtifacts(
                        artifacts: 'opa-result.json',
                        allowEmptyArchive: true
                    )
                }
            }
        }


        /*
         * ==========================================
         * 7. LINT
         * ==========================================
         */
        stage('Lint') {

            steps {
                sh 'sh scripts/docker-run.sh -u "$(id -u):$(id -g)" -e HOME=/tmp node:20-alpine npm run lint'
            }
        }


        /*
         * ==========================================
         * 8. UNIT TEST
         * ==========================================
         */
        stage('Unit Test') {

            steps {

                sh '''
                    mkdir -p reports
                    sh scripts/docker-run.sh \
                      -u "$(id -u):$(id -g)" \
                      -e HOME=/tmp \
                      -e JEST_JUNIT_OUTPUT_DIR=reports \
                      -e JEST_JUNIT_OUTPUT_NAME=junit.xml \
                      node:20-alpine \
                      npm test -- --coverage --reporters=jest-junit
                '''
            }
        }


        /*
         * ==========================================
         * 9. SONARQUBE
         * ==========================================
         */
        stage('SonarQube Analysis') {

            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                    withSonarQubeEnv('SonarQube') {

                        sh '''
                            sh scripts/docker-run.sh \
                              -e SONAR_HOST_URL \
                              -e SONAR_AUTH_TOKEN \
                              -e SONAR_TOKEN="${SONAR_AUTH_TOKEN}" \
                              sonarsource/sonar-scanner-cli:latest \
                              sonar-scanner \
                              -Dsonar.projectKey=taskflow-api \
                              -Dsonar.sources=src \
                              -Dsonar.tests=tests \
                              -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info \
                              -Dsonar.token="${SONAR_AUTH_TOKEN}"
                        '''
                    }
                }
            }
        }


        /*
         * ==========================================
         * 10. SONAR QUALITY GATE
         * ==========================================
         */
        stage('Quality Gate') {

            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                    timeout(time: 10, unit: 'MINUTES') {

                        withSonarQubeEnv('SonarQube') {

                        sh '''
                            set +e

                            echo "Polling SonarQube quality gate..."

                            sleep 20

                            n=0
                            max=60

                            while [ "$n" -lt "$max" ]; do

                                n=$((n + 1))

                                json=$(curl -sf \
                                  -u "${SONAR_AUTH_TOKEN}:" \
                                  "${SONAR_HOST_URL}/api/qualitygates/project_status?projectKey=taskflow-api")

                                rc=$?

                                if [ "$rc" -ne 0 ] || [ -z "$json" ]; then

                                    echo "Attempt $n: API not ready yet..."

                                    sleep 10

                                    continue
                                fi

                                echo "$json"

                                echo "$json" |
                                  grep -q '"status":"OK"' && {

                                    echo "Quality Gate PASSED"

                                    exit 0
                                }

                                echo "$json" |
                                  grep -q '"status":"ERROR"' && {

                                    echo "Quality Gate FAILED"

                                    exit 1
                                }

                                echo "Attempt $n: still processing..."

                                sleep 10

                            done

                            echo "Timed out waiting for quality gate"

                            exit 1
                        '''
                        }
                    }
                }
            }
        }

        /*
         * ==========================================
         * 11. BUILD + PUSH IMAGE (commit SHA tag)
         * ==========================================
         */
        stage('Build Image') {
            steps {
                script {
                    env.IMAGE_TAG = env.GIT_COMMIT.take(7)
                    env.FAIL_HEALTH_ARG = (params.FAIL_HEALTH == true || "${params.FAIL_HEALTH}" == 'true') ? 'true' : 'false'
                    echo "Image tag: ${env.IMAGE_TAG}  FAIL_HEALTH=${env.FAIL_HEALTH_ARG}"
                }
                sh '''
                    sh scripts/docker.sh inspect registry >/dev/null 2>&1 \
                      || sh scripts/docker.sh start registry \
                      || sh scripts/docker.sh run -d -p 5000:5000 --name registry --restart unless-stopped registry:2

                    sh scripts/docker.sh build \
                      --build-arg "FAIL_HEALTH=${FAIL_HEALTH_ARG}" \
                      -t "${REGISTRY}/taskflow-api:${IMAGE_TAG}" \
                      .
                    sh scripts/docker.sh push "${REGISTRY}/taskflow-api:${IMAGE_TAG}"
                '''
            }
        }

        /*
         * ==========================================
         * 12. TRIVY IMAGE SCAN
         * ==========================================
         */
        stage('Container Scan') {
            steps {
                sh '''
                    sh scripts/docker-run.sh \
                      -v /var/run/docker.sock:/var/run/docker.sock \
                      aquasec/trivy:0.56.2 \
                      image \
                      --exit-code 0 \
                      --severity HIGH,CRITICAL \
                      --ignore-unfixed \
                      --format sarif \
                      -o trivy.sarif \
                      "${REGISTRY}/taskflow-api:${IMAGE_TAG}"
                    ls -l trivy.sarif
                    echo "Trivy SARIF written to trivy.sarif"
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy.sarif', allowEmptyArchive: true
                }
            }
        }

        /*
         * ==========================================
         * 13. BLUE / GREEN DEPLOY + ROLLBACK
         * ==========================================
         */
        stage('Blue/Green Deploy') {
            steps {
                script {
                    sh '''
                        mkdir -p k8s
                        sh scripts/docker.sh network connect kind "$(hostname)" 2>/dev/null || true
                        sh scripts/docker.sh exec taskflow-control-plane cat /etc/kubernetes/admin.conf \
                          | sed -E "s#https://127.0.0.1:[0-9]+#https://taskflow-control-plane:6443#" \
                          | sed -E "s#https://0.0.0.0:[0-9]+#https://taskflow-control-plane:6443#" \
                          > k8s/kubeconfig.ci

                        sh scripts/docker.sh save "${REGISTRY}/taskflow-api:${IMAGE_TAG}" \
                          | sh scripts/docker.sh exec -i taskflow-control-plane ctr -n k8s.io images import -
                    '''

                    env.BG_CURRENT_COLOR = sh(
                        script: "sh scripts/kubectl.sh get svc taskflow -o jsonpath='{.spec.selector.color}'",
                        returnStdout: true
                    ).trim()

                    if (!env.BG_CURRENT_COLOR) {
                        env.BG_CURRENT_COLOR = 'blue'
                    }

                    def next = env.BG_CURRENT_COLOR == 'blue' ? 'green' : 'blue'
                    env.BG_NEXT_COLOR = next

                    echo "Live color=${env.BG_CURRENT_COLOR}  next=${next}"

                    sh "sh scripts/kubectl.sh get svc taskflow -o yaml | tee svc-taskflow-before.yaml"

                    sh "sh scripts/kubectl.sh set image deployment/taskflow-${next} app=${REGISTRY}/taskflow-api:${IMAGE_TAG}"
                    sh "sh scripts/kubectl.sh rollout status deployment/taskflow-${next} --timeout=120s"

                    sh """
                        sh scripts/kubectl.sh run smoke-${BUILD_NUMBER} --rm -i --restart=Never \
                          --image=curlimages/curl:8.10.1 \
                          -- curl -sf http://taskflow-${next}:8080/health
                    """

                    sh """
                        sh scripts/kubectl.sh patch svc taskflow -p '{"spec":{"selector":{"app":"taskflow","color":"${next}"}}}'
                    """

                    sh "sh scripts/kubectl.sh get svc taskflow -o yaml | tee svc-taskflow-after.yaml"
                    echo "Switched traffic from ${env.BG_CURRENT_COLOR} to ${next}"
                }
            }
            post {
                failure {
                    script {
                        if (env.BG_CURRENT_COLOR) {
                            sh """
                                echo "ROLLBACK: restoring selector color=${env.BG_CURRENT_COLOR}"
                                sh scripts/kubectl.sh patch svc taskflow -p '{"spec":{"selector":{"app":"taskflow","color":"${env.BG_CURRENT_COLOR}"}}}'
                                sh scripts/kubectl.sh get svc taskflow -o yaml | tee svc-taskflow-rollback.yaml
                            """
                        }
                    }
                }
                always {
                    archiveArtifacts artifacts: 'svc-taskflow-*.yaml', allowEmptyArchive: true
                }
            }
        }

        /*
         * ==========================================
         * 14. IaC LINT / VALIDATE / SECURITY
         * ==========================================
         */
        stage('IaC Lint & Validate') {
            parallel {
                stage('Terraform Validate') {
                    steps {
                        sh '''
                            sh scripts/docker-run.sh hashicorp/terraform:1.9.8 \
                              -chdir=infra/terraform init -backend=false
                            sh scripts/docker-run.sh hashicorp/terraform:1.9.8 \
                              -chdir=infra/terraform validate
                            sh scripts/docker-run.sh hashicorp/terraform:1.9.8 \
                              fmt -check -recursive infra/terraform
                        '''
                    }
                }
                stage('Ansible Lint') {
                    steps {
                        sh '''
                            sh scripts/docker-run.sh pipelinecomponents/ansible-lint:latest \
                              infra/ansible/playbook.yml
                        '''
                    }
                }
            }
        }

        stage('IaC Security Scan') {
            steps {
                sh '''
                    sh scripts/docker-run.sh aquasec/tfsec:v1.28.10 infra/terraform
                    sh scripts/docker-run.sh bridgecrew/checkov:3.2.334 \
                      -d infra/terraform --compact --soft-fail
                '''
            }
        }

        stage('Terraform Plan') {
            when {
                expression { return params.RUN_IAC == true || "${params.RUN_IAC}" == 'true' }
            }
            steps {
                sh '''
                    sh scripts/docker.sh inspect localstack >/dev/null 2>&1 \
                      || sh scripts/docker.sh start localstack \
                      || sh scripts/docker.sh run -d --name localstack \
                           -p 4566:4566 -e SERVICES=ec2,s3,sts,iam \
                           localstack/localstack:3.8
                    sleep 8
                    sh scripts/docker-run.sh --add-host=host.docker.internal:host-gateway \
                      -e AWS_ACCESS_KEY_ID=test \
                      -e AWS_SECRET_ACCESS_KEY=test \
                      -e AWS_DEFAULT_REGION=us-east-1 \
                      amazon/aws-cli:2.17.54 \
                      --endpoint-url http://host.docker.internal:4566 \
                      s3 mb s3://taskflow-tfstate || true

                    sh scripts/docker-run.sh --add-host=host.docker.internal:host-gateway \
                      hashicorp/terraform:1.9.8 \
                      -chdir=infra/terraform init -input=false
                    sh scripts/docker-run.sh --add-host=host.docker.internal:host-gateway \
                      hashicorp/terraform:1.9.8 \
                      -chdir=infra/terraform plan -input=false -out=tfplan
                    sh scripts/docker-run.sh --add-host=host.docker.internal:host-gateway \
                      hashicorp/terraform:1.9.8 \
                      -chdir=infra/terraform show -no-color tfplan > infra/terraform/tfplan.txt
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'infra/terraform/tfplan.txt', allowEmptyArchive: true
                }
            }
        }

        stage('Approval') {
            when {
                expression { return params.RUN_IAC == true || "${params.RUN_IAC}" == 'true' }
            }
            steps {
                input message: 'Apply this Terraform plan?', ok: 'Apply'
            }
        }

        stage('Terraform Apply') {
            when {
                expression { return params.RUN_IAC == true || "${params.RUN_IAC}" == 'true' }
            }
            steps {
                sh '''
                    sh scripts/docker-run.sh --add-host=host.docker.internal:host-gateway \
                      hashicorp/terraform:1.9.8 \
                      -chdir=infra/terraform apply -auto-approve tfplan
                    sh scripts/docker-run.sh --add-host=host.docker.internal:host-gateway \
                      hashicorp/terraform:1.9.8 \
                      -chdir=infra/terraform output
                '''
            }
        }

        stage('Configure with Ansible') {
            when {
                expression { return params.RUN_IAC == true || "${params.RUN_IAC}" == 'true' }
            }
            steps {
                sh '''
                    sh scripts/docker-run.sh --add-host=host.docker.internal:host-gateway \
                      hashicorp/terraform:1.9.8 \
                      -chdir=infra/terraform output -json > infra/terraform/outputs.json || true
                    sh scripts/tf-to-ansible-inventory.sh || true
                    if [ ! -f infra/ansible/inventory.ini ]; then
                      printf '%s\\n' '[taskflow]' 'taskflow-api ansible_host=localhost ansible_connection=local ansible_python_interpreter=auto_silent' > infra/ansible/inventory.ini
                    fi
                    sh scripts/docker-run.sh \
                      -v /var/run/docker.sock:/var/run/docker.sock \
                      -e TASKFLOW_IMAGE="${REGISTRY}/taskflow-api:${IMAGE_TAG}" \
                      willhallonline/ansible:2.16-alpine \
                      ansible-playbook -i infra/ansible/inventory.ini infra/ansible/playbook.yml
                '''
            }
        }

        /*
         * ==========================================
         * 15. E2E TESTS
         * ==========================================
         */
        stage('E2E Tests') {

            when {
                expression {
                    return env.RUN_E2E == 'true'
                }
            }

            steps {

                sh '''
                    sh scripts/docker.sh compose up -d --build

                    sleep 10
                '''

                sh '''
                    sh scripts/docker-run.sh \
                      --network host \
                      -e PLAYWRIGHT_BASE_URL=http://localhost:8080 \
                      mcr.microsoft.com/playwright:v1.47.0-jammy \
                      sh -c "npm ci && npx playwright test"
                '''
            }

            post {

                always {

                    sh '''
                        sh scripts/docker.sh compose down -v || true
                    '''

                    junit(
                        'reports/e2e-junit.xml'
                    )

                    archiveArtifacts(
                        artifacts: 'playwright-report/**',
                        allowEmptyArchive: true
                    )
                }
            }
        }


        /*
         * ==========================================
         * 12. DEPLOY STAGING
         * ==========================================
         */
        stage('Deploy — Staging') {

            when {
                branch 'develop'
            }

            steps {
                sh 'echo deploying to staging...'
            }
        }


        /*
         * ==========================================
         * 13. DEPLOY PRODUCTION
         * ==========================================
         */
        stage('Deploy — Production') {

            when {

                allOf {

                    branch 'main'

                    expression {
                        return env.RUN_DEPLOY == 'true'
                    }
                }
            }

            input {
                message 'Deploy to production?'
            }

            steps {
                sh 'echo deploying to production...'
            }
        }
    }


    /*
     * ==========================================
     * POST
     * ==========================================
     */
    post {

        success {

            echo "${env.APP_NAME} passed on ${env.NODE_ENV}"
        }

        failure {

            echo "Failed at stage: ${env.STAGE_NAME}"
        }

        always {

            junit(
                allowEmptyResults: true,
                testResults: 'reports/junit.xml'
            )

            publishCoverage(
                adapters: [
                    coberturaAdapter(
                        'coverage/cobertura-coverage.xml'
                    )
                ]
            )

            archiveArtifacts(
                artifacts: 'npm-debug.log*,taskflow-api.cdx.json,taskflow-api.cdx.json.sig,cosign.pub,scan-result.json,trivy.sarif',
                allowEmptyArchive: true
            )
        }
    }
}