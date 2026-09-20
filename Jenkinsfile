pipeline {
    // Run on the Jenkins agent that has Docker (not inside node:20-alpine).
    // Per-stage Docker agents use reuseNode true so Sonar, Node, and E2E can all call docker.
    agent { label 'linux-build' }

    environment {
        APP_NAME = 'taskflow-api'
        NODE_ENV = 'test'
    }

    options {
        timeout(time: 10, unit: 'MINUTES')
    }

    stages {
        stage('Install') {
            agent {
                docker {
                    image 'node:20-alpine'
                    reuseNode true
                }
            }
            steps {
                sh 'npm ci'
            }
        }

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

        stage('Unit Test') {
            agent {
                docker {
                    image 'node:20-alpine'
                    reuseNode true
                }
            }
            steps {
                sh 'npm test -- --coverage --reporters=jest-junit'
            }
        }

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

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('E2E Tests') {
            steps {
                sh 'docker compose up -d --build'
                sh 'sleep 10'

                sh '''
                    docker run --rm --network host \
                      -v "$WORKSPACE":/work \
                      -w /work \
                      -e PLAYWRIGHT_BASE_URL=http://localhost:8080 \
                      mcr.microsoft.com/playwright:v1.47.0-jammy \
                      sh -c "npm ci && npx playwright test"
                '''
            }

            post {
                always {
                    sh 'docker compose down -v || true'

                    junit 'reports/e2e-junit.xml'

                    archiveArtifacts artifacts: 'playwright-report/**', allowEmptyArchive: true
                }
            }
        }

        stage('Deploy — Staging') {
            when {
                branch 'develop'
            }
            steps {
                sh 'echo deploying to staging...'
            }
        }

        stage('Deploy — Production') {
            when {
                branch 'main'
            }
            input {
                message 'Deploy to production?'
            }
            steps {
                sh 'echo deploying to production...'
            }
        }
    }

    post {
        success {
            echo "${env.APP_NAME} passed on ${env.NODE_ENV}"
        }

        failure {
            echo "Failed at stage: ${env.STAGE_NAME}"
        }

        always {
            junit allowEmptyResults: true, testResults: 'reports/junit.xml'

            publishCoverage adapters: [
                coberturaAdapter('coverage/cobertura-coverage.xml')
            ], failOnError: false

            archiveArtifacts artifacts: 'npm-debug.log*', allowEmptyArchive: true
        }
    }
}
