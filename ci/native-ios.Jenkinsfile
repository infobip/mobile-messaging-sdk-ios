import org.jenkinsci.plugins.workflow.steps.FlowInterruptedException

def canonicalJob = 'Team_Mobile_Messaging/infobip-mobile-messaging-ios'
properties([
    disableConcurrentBuilds(),
    buildDiscarder(logRotator(daysToKeepStr: '14', numToKeepStr: '30')),
    parameters([
        choice(name: 'CUSTOM_BUILD_TYPE', choices: ['snapshot_build', 'release', 'test', 'release_candidate']),
        choice(name: 'CUSTOM_RELEASE_TYPE', choices: ['patch', 'minor', 'major', 'custom']),
        string(name: 'CUSTOM_VERSION_NUMBER', defaultValue: ''),
        booleanParam(name: 'DONT_RUN_TESTS', defaultValue: false),
        booleanParam(name: 'DONT_PUSH_ON_GITHUB', defaultValue: false),
        text(name: 'RELEASE_NOTES', defaultValue: '', description: 'Required for release builds; Markdown.'),
        string(name: 'BRANCH_NAME_TO_BUILD', defaultValue: 'master', trim: true),
        booleanParam(name: 'DO_POD_LINT', defaultValue: false),
        choice(name: 'MAC_AGENT', choices: ['auto', 'ci-zg-mac-mini-02', 'ci-zg-mac-mini-03'], description: 'Auto selects an online Mac with a free device resource. Release workflows use mini-03.'),
        booleanParam(name: 'SCHEDULER_CHECK_ONLY', defaultValue: false, description: 'Check resource/agent selection only; no SDK build, simulator changes or publishing.')
    ]),
    pipelineTriggers(env.JOB_NAME == canonicalJob ? [cron('0 0 * * *')] : [])
])

def hosts = [
    'ci-zg-mac-mini-03': [resource: 'mmt-mac-mini-03-devices', worker: 'Team_Mobile_Messaging/native-ios-workers/mac-mini-03'],
    'ci-zg-mac-mini-02': [resource: 'mmt-mac-mini-02-devices', worker: 'Team_Mobile_Messaging/native-ios-workers/mac-mini-02']
]
def buildType = params.CUSTOM_BUILD_TYPE ?: 'snapshot_build'
def requestedHost = params.MAC_AGENT ?: 'auto'
def releaseBuild = buildType in ['release', 'release_candidate']
if (releaseBuild && requestedHost == 'ci-zg-mac-mini-02') {
    error('Release workflows remain on mini-03; choose auto or mini-03.')
}
def candidates = releaseBuild ? ['ci-zg-mac-mini-03'] : (requestedHost == 'auto' ? hosts.keySet().toList() : [requestedHost])
if (!candidates.every { hosts.containsKey(it) }) { error('Unknown native iOS agent') }
def completed = false
def metadata = null

timestamps {
    try {
        timeout(time: 4, unit: 'HOURS') {
            stage('Select available Mac') {
                waitUntil(initialRecurrencePeriod: 10000, quiet: true) {
                    def online = nodesByLabel(label: 'ci-zg-mac-mini-02 || ci-zg-mac-mini-03', offline: false)
                    for (host in candidates) {
                        if (completed) { break }
                        if (!online.contains(host)) { continue }
                        def target = hosts[host]
                        lock(resource: target.resource, skipIfLocked: true) {
                            echo('Selected ' + host + ' under ' + target.resource)
                            if (params.SCHEDULER_CHECK_ONLY) {
                                // This short timeout belongs only to a read-only scheduling check.
                                timeout(time: 1, unit: 'MINUTES') {
                                    node(host) {
                                        echo('SCHEDULER_CHECK node=' + env.NODE_NAME + ' resource=' + target.resource)
                                    }
                                }
                                currentBuild.displayName = '#' + env.BUILD_NUMBER + ': scheduler check (' + host + ')'
                                currentBuild.description = 'Scheduling check only. Selected ' + host + ' with ' + target.resource + '.'
                                completed = true
                            } else {
                                def workerRun = null
                                def workerParameters = [
                                    string(name: 'CUSTOM_BUILD_TYPE', value: buildType),
                                    string(name: 'CUSTOM_RELEASE_TYPE', value: params.CUSTOM_RELEASE_TYPE ?: 'patch'),
                                    string(name: 'CUSTOM_VERSION_NUMBER', value: params.CUSTOM_VERSION_NUMBER ?: ''),
                                    booleanParam(name: 'DONT_RUN_TESTS', value: params.DONT_RUN_TESTS ?: false),
                                    booleanParam(name: 'DONT_PUSH_ON_GITHUB', value: params.DONT_PUSH_ON_GITHUB ?: false),
                                    string(name: 'RELEASE_NOTES', value: params.RELEASE_NOTES ?: ''),
                                    string(name: 'BRANCH_NAME_TO_BUILD', value: params.BRANCH_NAME_TO_BUILD ?: 'master'),
                                    booleanParam(name: 'DO_POD_LINT', value: params.DO_POD_LINT ?: false),
                                    string(name: 'CI_PARENT_JOB', value: env.JOB_NAME),
                                    string(name: 'CI_PARENT_BUILD', value: env.BUILD_TAG),
                                    string(name: 'CI_DEVICE_RESOURCE', value: target.resource)
                                ]
                                try {
                                    // Only executor allocation is timed here. Once the worker starts,
                                    // its existing 120-minute build timeout governs actual build work.
                                    timeout(time: releaseBuild ? 120 : 1, unit: 'MINUTES') {
                                        workerRun = build(job: '/' + target.worker, parameters: workerParameters,
                                            quietPeriod: 0, waitForStart: true, propagate: false)
                                    }
                                } catch (FlowInterruptedException interrupted) {
                                    if (interrupted.isActualInterruption() || workerRun != null || releaseBuild) { throw interrupted }
                                    echo('Worker could not start promptly on ' + host + '; trying another available Mac.')
                                }
                                if (workerRun != null) {
                                    stage('Native build on ' + host) {
                                        workerRun = waitForBuild(runId: workerRun.externalizableId, propagate: false, propagateAbort: true)
                                    }
                                    // Never retry a started build, including failed tests or publishing.
                                    completed = true
                                    currentBuild.displayName = '#' + env.BUILD_NUMBER + ': ' + (params.BRANCH_NAME_TO_BUILD ?: 'master') + ' (' + host + ')'
                                    currentBuild.description = 'Built on ' + host + '. <a href="' + workerRun.absoluteUrl + '">Worker #' + workerRun.number + ' and full console</a>.'
                                    currentBuild.result = workerRun.result
                                    stage('Publish native results') {
                                        node(host) {
                                            dir('.ci-dispatch-reports/' + env.BUILD_NUMBER) {
                                                try {
                                                    deleteDir()
                                                    copyArtifacts(projectName: '/' + target.worker, selector: specific(workerRun.number.toString()),
                                                        filter: 'ci-artifacts/**,Example/fastlane/test_output/native-tests.junit,Example/fastlane/report.xml,*_snyk_report.html', optional: true)
                                                    if (fileExists('ci-artifacts/dispatch.json')) {
                                                        metadata = readJSON(file: 'ci-artifacts/dispatch.json', returnPojo: true)
                                                        if (metadata.node != host || metadata.resource != target.resource || metadata.parent != env.BUILD_TAG) {
                                                            error('Worker result does not match the reserved Mac/build')
                                                        }
                                                        if (!(metadata.commit ==~ /[0-9a-f]{40}/)) {
                                                            error('Worker did not identify a valid tested SDK commit')
                                                        }
                                                        currentBuild.description += ' Tested SDK commit: ' + metadata.commit + '.'
                                                    } else if (workerRun.result == 'SUCCESS') {
                                                        error('Successful worker did not publish dispatch metadata')
                                                    }
                                                    archiveArtifacts(artifacts: '**/*', allowEmptyArchive: workerRun.result != 'SUCCESS')
                                                    junit(testResults: 'Example/fastlane/test_output/native-tests.junit',
                                                        allowEmptyResults: params.DONT_RUN_TESTS || workerRun.result != 'SUCCESS')
                                                } finally {
                                                    deleteDir()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    return completed
                }
            }
        }
    } catch (FlowInterruptedException interrupted) {
        currentBuild.result = 'ABORTED'
        throw interrupted
    } catch (Exception failure) {
        currentBuild.result = 'FAILURE'
        throw failure
    } finally {
        if (env.JOB_NAME == canonicalJob && metadata?.commit) {
            notifyBitbucket(commitSha1: metadata.commit)
        }
    }
}
