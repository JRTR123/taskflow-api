pipeline {
    agent { 
        docker { 
            image 'node:20-alpine' 
        } 
    }

    environment {
        APP_NAME = 'taskflow-api'
        NODE_ENV = 'test'
    }

    options {
        timeout(time: 10, unit: 'MINUTES')
    }

    stages {
        stage('Install') {
            steps {
                sh 'npm ci'
            }
        }

        stage('Lint') {
            steps {
                sh 'npm run lint'
            }
        }

        stage('Unit Test') {
            steps {
                sh 'npm run test:coverage'
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
                sh 'sleep 5'

                sh '''
                    docker run --rm --network host \
                      -v "$WORKSPACE":/work \
                      -w /work \
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
            junit 'reports/junit.xml'

            publishCoverage adapters: [
                coberturaAdapter('coverage/cobertura-coverage.xml')
            ]

            archiveArtifacts artifacts: 'npm-debug.log*', allowEmptyArchive: true
        }
    }
}
