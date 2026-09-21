pipeline {

    agent { label 'linux-build' }

    environment {
        APP_NAME = 'taskflow-api'
        NODE_ENV = 'test'
    }

    options {
        timeout(time: 30, unit: 'MINUTES')
    }

    stages {

        /*
         * ==========================================
         * INSTALL
         * ==========================================
         */
        stage('Install') {
            agent {
                docker {
                    image 'node:20-alpine'
                    reuseNode true
                }
            }

            steps {
                sh '''
                    npm ci
                '''
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
                    docker run --rm \
                      -v "$WORKSPACE:/repo" \
                      zricethezav/gitleaks:latest \
                      detect \
                      --source=/repo \
                      --report-format=sarif \
                      --report-path=/repo/gitleaks.sarif \
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

                    agent {
                        docker {
                            image 'node:20-alpine'
                            reuseNode true
                        }
                    }

                    steps {
                        sh '''
                            npm install --no-save \
                              eslint-plugin-security \
                              @microsoft/eslint-formatter-sarif

                            npx eslint src/ \
                              -f @microsoft/eslint-formatter-sarif \
                              -o eslint-security.sarif || true
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
                            docker run --rm \
                              -v "$WORKSPACE:/src" \
                              semgrep/semgrep \
                              semgrep \
                              --config=p/owasp-top-ten \
                              --config=p/nodejs \
                              --sarif \
                              -o /src/semgrep.sarif \
                              /src || true
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

            agent {
                docker {
                    image 'node:20-alpine'
                    reuseNode true
                }
            }

            steps {
                script {

                    sh '''
                        npm audit --audit-level=high --json > audit.json || true
                    '''

                    def critical = sh(
                        script: '''
                            node -e "
                            const fs = require('fs');
                            const data = JSON.parse(fs.readFileSync('audit.json'));
                            console.log(
                              data.metadata?.vulnerabilities?.critical || 0
                            );
                            "
                        ''',
                        returnStdout: true
                    ).trim().toInteger()

                    def high = sh(
                        script: '''
                            node -e "
                            const fs = require('fs');
                            const data = JSON.parse(fs.readFileSync('audit.json'));
                            console.log(
                              data.metadata?.vulnerabilities?.high || 0
                            );
                            "
                        ''',
                        returnStdout: true
                    ).trim().toInteger()

                    def moderate = sh(
                        script: '''
                            node -e "
                            const fs = require('fs');
                            const data = JSON.parse(fs.readFileSync('audit.json'));
                            console.log(
                              data.metadata?.vulnerabilities?.moderate || 0
                            );
                            "
                        ''',
                        returnStdout: true
                    ).trim().toInteger()

                    def low = sh(
                        script: '''
                            node -e "
                            const fs = require('fs');
                            const data = JSON.parse(fs.readFileSync('audit.json'));
                            console.log(
                              data.metadata?.vulnerabilities?.low || 0
                            );
                            "
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

            agent {
                docker {
                    image 'node:20-alpine'
                    reuseNode true
                }
            }

            steps {

                sh '''
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
                    docker run --rm \
                      -v "$WORKSPACE:/src" \
                      anchore/syft:latest \
                      dir:/src \
                      -o cyclonedx-json=/src/taskflow-api.cdx.json
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
                    docker run --rm \
                      -v "$WORKSPACE:/work" \
                      -w /work \
                      -u "$(id -u):$(id -g)" \
                      -e COSIGN_PASSWORD=lab \
                      -e COSIGN_YES=true \
                      gcr.io/projectsigstore/cosign:v2.4.1 \
                      generate-key-pair

                    docker run --rm \
                      -v "$WORKSPACE:/work" \
                      -w /work \
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
                        docker run --rm \
                          -v "$WORKSPACE:/workspace" \
                          -w /workspace \
                          openpolicyagent/opa:latest \
                          eval \
                          --data policy/security.rego \
                          --input scan-result.json \
                          'data.security.deny' \
                          --format pretty
                    '''

                    def denyCount = sh(
                        script: '''
                            docker run --rm \
                              -v "$WORKSPACE:/workspace" \
                              -w /workspace \
                              openpolicyagent/opa:latest \
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

            agent {
                docker {
                    image 'node:20-alpine'
                    reuseNode true
                }
            }

            steps {
                sh 'npm run lint'
            }
        }


        /*
         * ==========================================
         * 8. UNIT TEST
         * ==========================================
         */
        stage('Unit Test') {

            agent {
                docker {
                    image 'node:20-alpine'
                    reuseNode true
                }
            }

            steps {

                sh '''
                    mkdir -p reports

                    export JEST_JUNIT_OUTPUT_DIR=reports
                    export JEST_JUNIT_OUTPUT_NAME=junit.xml

                    npm test \
                      -- \
                      --coverage \
                      --reporters=jest-junit
                '''
            }
        }


        /*
         * ==========================================
         * 9. SONARQUBE
         * ==========================================
         */
        stage('SonarQube Analysis') {

            agent {
                docker {
                    image 'sonarsource/sonar-scanner-cli:latest'
                    reuseNode true
                }
            }

            steps {

                withSonarQubeEnv('SonarQube') {

                    sh '''
                        sonar-scanner \
                          -Dsonar.projectKey=taskflow-api \
                          -Dsonar.sources=src \
                          -Dsonar.tests=tests \
                          -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info
                    '''
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

        /*
         * ==========================================
         * 11. E2E TESTS
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
                    docker compose up -d --build

                    sleep 10
                '''

                sh '''
                    docker run --rm \
                      --network host \
                      -v "$WORKSPACE":/work \
                      -w /work \
                      -e PLAYWRIGHT_BASE_URL=http://localhost:8080 \
                      mcr.microsoft.com/playwright:v1.47.0-jammy \
                      sh -c "npm ci && npx playwright test"
                '''
            }

            post {

                always {

                    sh '''
                        docker compose down -v || true
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
                artifacts: 'npm-debug.log*,taskflow-api.cdx.json,taskflow-api.cdx.json.sig,cosign.pub,scan-result.json',
                allowEmptyArchive: true
            )
        }
    }
}