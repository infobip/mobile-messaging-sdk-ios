// Run through the Job DSL plugin. The template retains Jenkins-managed secrets,
// signing wrappers, publishers and build options; none are exported into Git.
def template = binding.hasVariable('templateJob') ? templateJob : 'Team_Mobile_Messaging/infobip-mobile-messaging-ios'
def allowedParents = 'Team_Mobile_Messaging/infobip-mobile-messaging-ios(-dispatcher)?'
def parentNames = ['Team_Mobile_Messaging/infobip-mobile-messaging-ios',
                   'Team_Mobile_Messaging/infobip-mobile-messaging-ios-dispatcher']
def allocation = [
    '02': '2CDF2406-3D83-418C-B7EC-2B33E055E82C',
    '03': 'A500792F-440B-40C8-AF2C-9DDAE5782F54'
]

folder('Team_Mobile_Messaging/native-ios-workers') {
    description('Internal native iOS workers. Start builds through infobip-mobile-messaging-ios; its Pipeline owns the Mac device lock.')
}

allocation.each { suffix, udid ->
    def host = 'ci-zg-mac-mini-' + suffix
    def resource = 'mmt-mac-mini-' + suffix + '-devices'
    freeStyleJob('Team_Mobile_Messaging/native-ios-workers/mac-mini-' + suffix) {
        using(template)
        // Inspect generated jobs before enabling them for the dispatcher.
        disabled(true)
        label(host)
        concurrentBuild(false)
        customWorkspace('workspace/Team_Mobile_Messaging/native-ios-pool/mac-mini-' + suffix + '/infobip-mobile-messaging-ios')
        description('Internal worker for ' + host + '. The native iOS dispatcher must hold ' + resource + ' for the complete worker run. Direct manual builds are rejected.')
        configure { project ->
            project.triggers[0].children().clear()
            def props = project.properties[0]
            props.children().removeAll {
                it.name() in ['org.jenkins.plugins.lockableresources.RequiredResourcesProperty',
                    'com.synopsys.arc.jenkinsci.plugins.jobrestrictions.jobs.JobRestrictionProperty',
                    'hudson.plugins.copyartifact.CopyArtifactPermissionProperty']
            }
            def restriction = props.appendNode('com.synopsys.arc.jenkinsci.plugins.jobrestrictions.jobs.JobRestrictionProperty').appendNode('config')
            def upstream = restriction.appendNode('upstreamCauseRestriction')
            def regex = upstream.appendNode('jobRestriction', [class: 'com.synopsys.arc.jenkinsci.plugins.jobrestrictions.restrictions.job.RegexNameRestriction'])
            regex.appendNode('regexExpression', allowedParents)
            regex.appendNode('checkShortName', false)
            upstream.appendNode('skipCheckForMissingInfo', false)
            restriction.appendNode('userIdCauseRestriction').appendNode('prohibitManualLaunch', true)

            def copyNames = props.appendNode('hudson.plugins.copyartifact.CopyArtifactPermissionProperty').appendNode('projectNameList')
            parentNames.each { copyNames.appendNode('string', it) }
            def definitions = props.'hudson.model.ParametersDefinitionProperty'[0].parameterDefinitions[0]
            ['CI_PARENT_JOB', 'CI_PARENT_BUILD', 'CI_DEVICE_RESOURCE'].each { name ->
                def parameter = definitions.appendNode('hudson.model.StringParameterDefinition')
                parameter.appendNode('name', name)
                parameter.appendNode('defaultValue', '')
                parameter.appendNode('description', 'Internal dispatcher field. Do not launch this worker directly.')
                parameter.appendNode('trim', true)
            }

            // Only the dispatcher advertises the repository to commit-hook job
            // discovery. These trusted constants are injected before SCM checkout.
            def preEnvironment = props.EnvInjectJobProperty[0].info[0]
            def repoVariables = 'MMT_NATIVE_SCM_URL=ssh://git@git.ib-ci.com:7999/mml/infobip-mobile-messaging-ios.git\nMMT_NATIVE_MIRROR_URL=git@github.com:infobip/mobile-messaging-sdk-ios.git'
            if (preEnvironment.propertiesContent) {
                preEnvironment.propertiesContent[0].setValue(preEnvironment.propertiesContent.text() + '\n' + repoVariables)
            } else {
                preEnvironment.appendNode('propertiesContent', repoVariables)
            }
            def remotes = project.scm[0].userRemoteConfigs[0].children()
            assert remotes.size() == 2: 'Native template repository list changed'
            remotes[0].url[0].setValue('${MMT_NATIVE_SCM_URL}')
            remotes[1].url[0].setValue('${MMT_NATIVE_MIRROR_URL}')
            project.scm[0].extensions[0].appendNode('hudson.plugins.git.extensions.impl.IgnoreNotifyCommit')

            def guard = '''set -eu
case "${CI_PARENT_JOB:-}" in
  Team_Mobile_Messaging/infobip-mobile-messaging-ios|Team_Mobile_Messaging/infobip-mobile-messaging-ios-dispatcher) ;;
  *) echo 'Use the native iOS dispatcher; no build work was started.'; exit 1 ;;
esac
[ -n "${CI_PARENT_BUILD:-}" ] || { echo 'Missing dispatcher build identity'; exit 1; }
[ "$NODE_NAME" = '@HOST@' ] || { echo 'Wrong worker agent'; exit 1; }
[ "$CI_DEVICE_RESOURCE" = '@RESOURCE@' ] || { echo 'Wrong dispatcher device resource'; exit 1; }
'''.replace('@HOST@', host).replace('@RESOURCE@', resource)
            if (suffix == '02') {
                guard += '''case "$CUSTOM_BUILD_TYPE" in
  snapshot_build|test) ;;
  *) echo 'Release workflows remain on mini-03'; exit 1 ;;
esac
'''
            }
            def builders = project.builders[0]
            def copyrightShell = builders.'hudson.tasks.Shell'[0]
            copyrightShell.command[0].setValue(guard + copyrightShell.command.text())
            def mainShell = builders.'hudson.tasks.Shell'.find { it.command.text().contains('CI_IOS_SIMULATOR_UDID=') }
            assert mainShell != null: 'Native template does not contain the isolated build shell'
            def command = mainShell.command.text().replace('A500792F-440B-40C8-AF2C-9DDAE5782F54', udid)
            def analysisStart = command.indexOf('#sonar qube')
            def analysisEnd = command.indexOf('if [ "$DO_POD_LINT"', analysisStart)
            assert analysisStart >= 0 && analysisEnd > analysisStart: 'Native template analysis section changed'
            command = command.substring(0, analysisStart) + '''# Preserve static analysis when XCTest is intentionally skipped.
    if [ "$DONT_RUN_TESTS" != "true" ]; then
        chmod 755 "$WORKSPACE/xccov-to-sonarqube-generic.sh"
        "$WORKSPACE/xccov-to-sonarqube-generic.sh" fastlane/test_output/*.xcresult > "$WORKSPACE/sonarqube-generic-coverage.xml"
    fi
    cd "$WORKSPACE"
    ci_project_version="$(agvtool what-marketing-version -terse1)"
    if [ "$DONT_RUN_TESTS" = "true" ]; then
        sonar-scanner "-Dsonar.projectVersion=$ci_project_version" "-Dsonar.branch.name=$BRANCH_NAME_TO_BUILD" '-Dsonar.coverageReportPaths='
    else
        sonar-scanner "-Dsonar.projectVersion=$ci_project_version" "-Dsonar.branch.name=$BRANCH_NAME_TO_BUILD"
    fi

    ''' + command.substring(analysisEnd)
            def metadata = '''# Keep generated CI output out of release cleanliness checks, including older branches.
printf '%s\n' '/.ci-derived-data/' '/ci-artifacts/' >> .git/info/exclude
mkdir -p ci-artifacts
python3 - <<'PY'
import json, os, pathlib
pathlib.Path('ci-artifacts/dispatch.json').write_text(json.dumps({
    'node': os.environ['NODE_NAME'],
    'resource': os.environ['CI_DEVICE_RESOURCE'],
    'parent': os.environ['CI_PARENT_BUILD'],
    'commit': os.environ['GIT_COMMIT'],
    'branch': os.environ['BRANCH_NAME_TO_BUILD']
}, indent=2))
PY
'''
            mainShell.command[0].setValue(metadata + command)
            def archiver = project.publishers[0].'hudson.tasks.ArtifactArchiver'[0]
            archiver.artifacts[0].setValue(archiver.artifacts.text() + ',ci-artifacts/dispatch.json')

            // The public mirror must also respect the existing opt-out parameter.
            def flexible = project.publishers[0].children().find { it.name().endsWith('.FlexiblePublisher') }
            def mirrorCondition = flexible.depthFirst().find { it.name() == 'condition' && it.attribute('class') == 'org.jenkins_ci.plugins.run_condition.core.ExpressionCondition' }
            assert mirrorCondition != null: 'Native template Git Publisher condition changed'
            mirrorCondition.expression[0].setValue('^(master|rn_expo_rc|6[.]x[.]x_release|7[.]x[.]x_release):false$')
            mirrorCondition.label[0].setValue('${BRANCH_NAME_TO_BUILD}:${DONT_PUSH_ON_GITHUB}')
        }
    }
}
