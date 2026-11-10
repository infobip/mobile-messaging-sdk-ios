# Native iOS scheduling

`native-ios.Jenkinsfile` is a flyweight dispatcher. It retains the native build parameters, acquires one existing per-Mac device resource, and starts the corresponding worker only after obtaining that resource. It prefers mini-03 when both Macs are available. Snapshot/test builds can use mini-02; release workflows remain on mini-03 because release signing was not validated on mini-02.

Workers keep the existing Jenkins credential bindings, signing setup, build commands, Snyk, Git publishing, Bitbucket reporting and Slack failure notifications. The dispatcher copies their XCTest results and artifacts back to the entry-point build. Each worker rejects direct manual starts and upstream jobs other than the dispatcher. It also checks its assigned node, resource and parent identity before build commands.

The dispatcher holds the device resource through worker completion and artifact capture. A started build is not retried on failure. Offline agents are excluded. Executor-start waiting is bounded separately from the worker's existing build timeout. `disableConcurrentBuilds()` queues subsequent native builds without aborting the current build. The daily trigger remains `0 0 * * *` only at the established job name.

## Provisioning and cutover

1. Run `native-ios-workers.groovy` using Jenkins Job DSL with `sandbox: true`. Pass `templateJob` as the current native Freestyle job. It creates disabled workers in `Team_Mobile_Messaging/native-ios-workers` by copying that job; secrets remain inside Jenkins. Inspect the generated configuration before enabling workers.
2. Create `Team_Mobile_Messaging/infobip-mobile-messaging-ios-dispatcher` as a Pipeline from SCM using `ci/native-ios.Jenkinsfile`. Validate a scheduling-only run and a snapshot build with GitHub publishing disabled. Check fallback to mini-02 while mini-03 is occupied, exact resource ownership, 502 XCTest results and artifact publication.
3. Drain the existing native job without aborting running builds or losing queued parameters. Preserve it as a disabled `infobip-mobile-messaging-ios-legacy` job, retaining its history and original configuration. Rename the validated dispatcher to `infobip-mobile-messaging-ios`; existing callers then use the same entry-point URL. Old individual build URLs move beneath the legacy job; its history remains available there.
4. The first run at the canonical job name installs the original daily schedule. For later worker regeneration, use the legacy job as `templateJob`. Do not regenerate active workers.

The separate manual host preflight and mini-02 validation jobs are not normal CI entry points and remain disabled.

## Rollback

Wait for any dispatcher and worker runs to finish. Disable the dispatcher, rename it out of the canonical name, and restore the legacy job to `infobip-mobile-messaging-ios`. Re-enable the legacy job. Its original mini-03 lock and scheduling settings are preserved. Do not force-unlock resources or stop other jobs to perform migration/rollback.
