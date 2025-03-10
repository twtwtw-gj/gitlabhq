---
stage: Systems
group: Distribution
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/product/ux/technical-writing/#assignments
---

# Upgrading GitLab **(FREE SELF)**

Upgrading GitLab is a relatively straightforward process, but the complexity
can increase based on the installation method you have used, how old your
GitLab version is, if you're upgrading to a major version, and so on.

Make sure to read the whole page as it contains information related to every upgrade method.

The [maintenance policy documentation](../policy/maintenance.md)
has additional information about upgrading, including:

- How to interpret GitLab product versioning.
- Recommendations on the what release to run.
- How we use patch and security patch releases.
- When we backport code changes.

## Upgrade based on installation method

Depending on the installation method and your GitLab version, there are multiple
official ways to update GitLab:

- [Linux packages (Omnibus GitLab)](#linux-packages-omnibus-gitlab)
- [Source installations](#installation-from-source)
- [Docker installations](#installation-using-docker)
- [Kubernetes (Helm) installations](#installation-using-helm)

### Linux packages (Omnibus GitLab)

The [package upgrade guide](package/index.md)
contains the steps needed to update a package installed by official GitLab
repositories.

There are also instructions when you want to
[update to a specific version](package/index.md#upgrade-to-a-specific-version-using-the-official-repositories).

### Installation from source

- [Upgrading Community Edition and Enterprise Edition from source](upgrading_from_source.md) -
  The guidelines for upgrading Community Edition and Enterprise Edition from source.
- [Patch versions](patch_versions.md) guide includes the steps needed for a
  patch version, such as 13.2.0 to 13.2.1, and apply to both Community and Enterprise
  Editions.

In the past we used separate documents for the upgrading instructions, but we
have switched to using a single document. The old upgrading guidelines
can still be found in the Git repository:

- [Old upgrading guidelines for Community Edition](https://gitlab.com/gitlab-org/gitlab-foss/tree/11-8-stable/doc/update)
- [Old upgrading guidelines for Enterprise Edition](https://gitlab.com/gitlab-org/gitlab/-/tree/11-8-stable-ee/doc/update)

### Installation using Docker

GitLab provides official Docker images for both Community and Enterprise
editions, and they are based on the Omnibus package. See how to
[install GitLab using Docker](../install/docker.md).

### Installation using Helm

GitLab can be deployed into a Kubernetes cluster using Helm.
Instructions on how to update a cloud-native deployment are in
[a separate document](https://docs.gitlab.com/charts/installation/upgrade.html).

Use the [version mapping](https://docs.gitlab.com/charts/installation/version_mappings.html)
from the chart version to GitLab version to determine the [upgrade path](#upgrade-paths).

## Plan your upgrade

See the guide to [plan your GitLab upgrade](plan_your_upgrade.md).

## Checking for background migrations before upgrading

Certain releases may require different migrations to be
finished before you update to the newer version.

[Batched migrations](#batched-background-migrations) are a migration type available in GitLab 14.0 and later.
Background migrations and batched migrations are not the same, so you should check that both are
complete before updating.

Decrease the time required to complete these migrations by increasing the number of
[Sidekiq workers](../administration/sidekiq/extra_sidekiq_processes.md)
that can process jobs in the `background_migration` queue.

### Background migrations

#### Pending migrations

**For Omnibus installations:**

```shell
sudo gitlab-rails runner -e production 'puts Gitlab::BackgroundMigration.remaining'
sudo gitlab-rails runner -e production 'puts Gitlab::Database::BackgroundMigration::BatchedMigration.queued.count'
```

**For installations from source:**

```shell
cd /home/git/gitlab
sudo -u git -H bundle exec rails runner -e production 'puts Gitlab::BackgroundMigration.remaining'
sudo -u git -H bundle exec rails runner -e production 'puts Gitlab::Database::BackgroundMigration::BatchedMigration.queued.count'
```

#### Failed migrations

**For Omnibus installations:**

For GitLab 14.0-14.9:

```shell
sudo gitlab-rails runner -e production 'puts Gitlab::Database::BackgroundMigration::BatchedMigration.failed.count'
```

For GitLab 14.10 and later:

```shell
sudo gitlab-rails runner -e production 'puts Gitlab::Database::BackgroundMigration::BatchedMigration.with_status(:failed).count'
```

**For installations from source:**

For GitLab 14.0-14.9:

```shell
cd /home/git/gitlab
sudo -u git -H bundle exec rails runner -e production 'puts Gitlab::Database::BackgroundMigration::BatchedMigration.failed.count'
```

For GitLab 14.10 and later:

```shell
cd /home/git/gitlab
sudo -u git -H bundle exec rails runner -e production 'puts Gitlab::Database::BackgroundMigration::BatchedMigration.with_status(:failed).count'
```

### Batched background migrations

GitLab 14.0 introduced [batched background migrations](../user/admin_area/monitoring/background_migrations.md).

Some installations [may need to run GitLab 14.0 for at least a day](#1400) to complete the database changes introduced by that upgrade.

#### Check the status of batched background migrations

To check the status of batched background migrations:

1. On the top bar, select **Main menu > Admin**.
1. On the left sidebar, select **Monitoring > Background Migrations**.

   ![queued batched background migrations table](img/batched_background_migrations_queued_v14_0.png)

All migrations must have a `Finished` status before you upgrade GitLab.

The status of batched background migrations can also be queried directly in the database.

1. Log into a `psql` prompt according to the directions for your instance's installation method
(for example, `sudo gitlab-psql` for Omnibus installations).
1. Run the following query in the `psql` session to see details on incomplete batched background migrations:

   ```sql
   select job_class_name, table_name, column_name, job_arguments from batched_background_migrations where status <> 3;
   ```

If the migrations are not finished and you try to update to a later version,
GitLab prompts you with an error:

```plaintext
Expected batched background migration for the given configuration to be marked as 'finished', but it is 'active':
```

If you get this error, [check the batched background migration options](../user/admin_area/monitoring/background_migrations.md#database-migrations-failing-because-of-batched-background-migration-not-finished) to complete the upgrade.

### What do you do if your background migrations are stuck?

WARNING:
The following operations can disrupt your GitLab performance. They run a number of Sidekiq jobs that perform various database or file updates.

#### Background migrations remain in the Sidekiq queue

Run the following check. If it returns non-zero and the count does not decrease over time, follow the rest of the steps in this section.

```shell
# For Omnibus installations:
sudo gitlab-rails runner -e production 'puts Gitlab::BackgroundMigration.remaining'

# For installations from source:
cd /home/git/gitlab
sudo -u git -H bundle exec rails runner -e production 'puts Gitlab::BackgroundMigration.remaining'
```

It is safe to re-execute the following commands, especially if you have 1000+ pending jobs which would likely overflow your runtime memory.

**For Omnibus installations**

```shell
# Start the rails console
sudo gitlab-rails c

# Execute the following in the rails console
scheduled_queue = Sidekiq::ScheduledSet.new
pending_job_classes = scheduled_queue.select { |job| job["class"] == "BackgroundMigrationWorker" }.map { |job| job["args"].first }.uniq
pending_job_classes.each { |job_class| Gitlab::BackgroundMigration.steal(job_class) }
```

**For installations from source**

```shell
# Start the rails console
sudo -u git -H bundle exec rails RAILS_ENV=production

# Execute the following in the rails console
scheduled_queue = Sidekiq::ScheduledSet.new
pending_job_classes = scheduled_queue.select { |job| job["class"] == "BackgroundMigrationWorker" }.map { |job| job["args"].first }.uniq
pending_job_classes.each { |job_class| Gitlab::BackgroundMigration.steal(job_class) }
```

#### Background migrations stuck in 'pending' state

GitLab 13.6 introduced an issue where a background migration named `BackfillJiraTrackerDeploymentType2` can be permanently stuck in a **pending** state across upgrades. To clean up this stuck migration, see the [13.6.0 version-specific instructions](#1360).

GitLab 14.2 introduced an issue where a background migration named `BackfillDraftStatusOnMergeRequests` can be permanently stuck in a **pending** state across upgrades when the instance lacks records that match the migration's target. To clean up this stuck migration, see the [14.2.0 version-specific instructions](#1420).

GitLab 14.4 introduced an issue where a background migration named `PopulateTopicsTotalProjectsCountCache` can be permanently stuck in a **pending** state across upgrades when the instance lacks records that match the migration's target. To clean up this stuck migration, see the [14.4.0 version-specific instructions](#1440).

GitLab 14.5 introduced an issue where a background migration named `UpdateVulnerabilityOccurrencesLocation` can be permanently stuck in a **pending** state across upgrades when the instance lacks records that match the migration's target. To clean up this stuck migration, see the [14.5.0 version-specific instructions](#1450).

GitLab 14.8 introduced an issue where a background migration named `PopulateTopicsNonPrivateProjectsCount` can be permanently stuck in a **pending** state across upgrades. To clean up this stuck migration, see the [14.8.0 version-specific instructions](#1480).

GitLab 14.9 introduced an issue where a background migration named `ResetDuplicateCiRunnersTokenValuesOnProjects` can be permanently stuck in a **pending** state across upgrades when the instance lacks records that match the migration's target. To clean up this stuck migration, see the [14.9.0 version-specific instructions](#1490).

For other background migrations stuck in pending, run the following check. If it returns non-zero and the count does not decrease over time, follow the rest of the steps in this section.

```shell
# For Omnibus installations:
sudo gitlab-rails runner -e production 'puts Gitlab::Database::BackgroundMigrationJob.pending.count'

# For installations from source:
cd /home/git/gitlab
sudo -u git -H bundle exec rails runner -e production 'puts Gitlab::Database::BackgroundMigrationJob.pending.count'
```

It is safe to re-attempt these migrations to clear them out from a pending status:

**For Omnibus installations**

```shell
# Start the rails console
sudo gitlab-rails c

# Execute the following in the rails console
Gitlab::Database::BackgroundMigrationJob.pending.find_each do |job|
  puts "Running pending job '#{job.class_name}' with arguments #{job.arguments}"
  result = Gitlab::BackgroundMigration.perform(job.class_name, job.arguments)
  puts "Result: #{result}"
end
```

**For installations from source**

```shell
# Start the rails console
sudo -u git -H bundle exec rails RAILS_ENV=production

# Execute the following in the rails console
Gitlab::Database::BackgroundMigrationJob.pending.find_each do |job|
  puts "Running pending job '#{job.class_name}' with arguments #{job.arguments}"
  result = Gitlab::BackgroundMigration.perform(job.class_name, job.arguments)
  puts "Result: #{result}"
end
```

#### Batched migrations (GitLab 14.0 and later)

See [troubleshooting batched background migrations](../user/admin_area/monitoring/background_migrations.md#troubleshooting).

## Dealing with running CI/CD pipelines and jobs

If you upgrade your GitLab instance while the GitLab Runner is processing jobs, the trace updates fail. When GitLab is back online, the trace updates should self-heal. However, depending on the error, the GitLab Runner either retries, or eventually terminates, job handling.

As for the artifacts, the GitLab Runner attempts to upload them three times, after which the job eventually fails.

To address the above two scenarios, it is advised to do the following prior to upgrading:

1. Plan your maintenance.
1. Pause your runners or block new jobs from starting by adding following to your `/etc/gitlab/gitlab.rb`:

   ```ruby
   nginx['custom_gitlab_server_config'] = "location /api/v4/jobs/request {\n deny all;\n return 503;\n}\n"
   ```

   And reconfigure GitLab with:

   ```shell
   sudo gitlab-ctl reconfigure
   ```

1. Wait until all jobs are finished.
1. Upgrade GitLab.
1. [Update GitLab Runner](https://docs.gitlab.com/runner/install/index.html) to the same version
   as your GitLab version. Both versions [should be the same](https://docs.gitlab.com/runner/#gitlab-runner-versions).
1. Unpause your runners and unblock new jobs from starting by reverting the previous `/etc/gitlab/gitlab.rb` change.

## Checking for pending Advanced Search migrations **(PREMIUM SELF)**

This section is only applicable if you have enabled the [Elasticsearch integration](../integration/advanced_search/elasticsearch.md) **(PREMIUM SELF)**.

Major releases require all [Advanced Search migrations](../integration/advanced_search/elasticsearch.md#advanced-search-migrations)
to be finished from the most recent minor release in your current version
before the major version upgrade. You can find pending migrations by
running the following command:

**For Omnibus installations**

```shell
sudo gitlab-rake gitlab:elastic:list_pending_migrations
```

**For installations from source**

```shell
cd /home/git/gitlab
sudo -u git -H bundle exec rake gitlab:elastic:list_pending_migrations
```

### What do you do if your Advanced Search migrations are stuck?

In GitLab 15.0, an Advanced Search migration named `DeleteOrphanedCommit` can be permanently stuck
in a pending state across upgrades. This issue
[is corrected in GitLab 15.1](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/89539).

If you are a self-managed customer who uses GitLab 15.0 with Advanced Search, you will experience performance degradation.
To clean up the migration, upgrade to 15.1 or later.

For other Advanced Search migrations stuck in pending, see [how to retry a halted migration](../integration/advanced_search/elasticsearch.md#retry-a-halted-migration).

### What do you do for the error `Elasticsearch version not compatible`

Confirm that your version of Elasticsearch or OpenSearch is [compatible with your version of GitLab](../integration/advanced_search/elasticsearch.md#version-requirements).

## Upgrading without downtime

Read how to [upgrade without downtime](zero_downtime.md).

## Upgrading to a new major version

Upgrading the *major* version requires more attention.
Backward-incompatible changes and migrations are reserved for major versions.
Follow the directions carefully as we
cannot guarantee that upgrading between major versions is seamless.

A *major* upgrade requires the following steps:

1. Start by identifying a [supported upgrade path](#upgrade-paths). This is essential for a successful *major* version upgrade.
1. Upgrade to the latest minor version of the preceding major version.
1. Upgrade to the "dot zero" release of the next major version (`X.0.Z`).
1. Optional. Follow the [upgrade path](#upgrade-paths), and proceed with upgrading to newer releases of that major version.

It's also important to ensure that any [background migrations have been fully completed](#checking-for-background-migrations-before-upgrading)
before upgrading to a new major version.

If you have enabled the [Elasticsearch integration](../integration/advanced_search/elasticsearch.md) **(PREMIUM SELF)**, then
[ensure all Advanced Search migrations are completed](#checking-for-pending-advanced-search-migrations) in the last minor version in
your current version
before proceeding with the major version upgrade.

If your GitLab instance has any runners associated with it, it is very
important to upgrade GitLab Runner to match the GitLab minor version that was
upgraded to. This is to ensure [compatibility with GitLab versions](https://docs.gitlab.com/runner/#gitlab-runner-versions).

## Upgrade paths

Upgrading across multiple GitLab versions in one go is *only possible by accepting downtime*.
The following examples assume downtime is acceptable while upgrading.
If you don't want any downtime, read how to [upgrade with zero downtime](zero_downtime.md).

Find where your version sits in the upgrade path below, and upgrade GitLab
accordingly, while also consulting the
[version-specific upgrade instructions](#version-specific-upgrading-instructions):

`8.11.Z` -> `8.12.0` -> `8.17.7` -> `9.5.10` -> `10.8.7` -> [`11.11.8`](#1200) -> `12.0.12` -> [`12.1.17`](#1210) -> [`12.10.14`](#12100) -> `13.0.14` -> [`13.1.11`](#1310) -> [`13.8.8`](#1388) -> [`13.12.15`](#13120) -> [`14.0.12`](#1400) -> [`14.3.6`](#1430) -> [`14.9.5`](#1490) -> [`14.10.Z`](#14100) -> [`15.0.Z`](#1500) -> [`15.4.0`](#1540) -> [latest `15.Y.Z`](https://gitlab.com/gitlab-org/gitlab/-/releases)

NOTE:
When not explicitly specified, upgrade GitLab to the latest available patch
release rather than the first patch release, for example `13.8.8` instead of `13.8.0`.
This includes versions you must stop at on the upgrade path as there may
be fixes for issues relating to the upgrade process.

The following table, while not exhaustive, shows some examples of the supported
upgrade paths.
Additional steps between the mentioned versions are possible. We list the minimally necessary steps only.

For a dynamic view of examples of supported upgrade paths, try the [Upgrade Path tool](https://gitlab-com.gitlab.io/support/toolbox/upgrade-path/). The Upgrade Path tool is maintained by the [GitLab Support team](https://about.gitlab.com/handbook/support/#about-the-support-team). Share feedback and help improve the tool by raising an issue or MR in the [upgrade-path project](https://gitlab.com/gitlab-com/support/toolbox/upgrade-path).

| Target version | Your version | Supported upgrade path                                                                               | Note                                                                                                                              |
| -------------- | ------------ | ---------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `15.1.0`       | `14.6.2`     | `14.6.2` -> `14.9.5` -> `14.10.5` -> `15.0.2` -> `15.1.0`                                            | Three intermediate versions are required: `14.9` and `14.10`, `15.0`, then `15.1.0`.                                              |
| `15.0.0`       | `14.6.2`     | `14.6.2` -> `14.9.5` -> `14.10.5` -> `15.0.2`                                                        | Two intermediate versions are required: `14.9` and `14.10`, then `15.0.0`.                                                        |
| `14.6.2`       | `13.10.2`    | `13.10.2` -> `13.12.15` -> `14.0.12` -> `14.3.6` => `14.6.2`                                         | Three intermediate versions are required: `13.12` and `14.0`, `14.3`, then `14.6.2`.                                                        |
| `14.1.8`       | `13.9.2`     | `13.9.2` -> `13.12.15` -> `14.0.12` -> `14.1.8`                                                      | Two intermediate versions are required: `13.12` and `14.0`, then `14.1.8`.                                                        |
| `13.12.15`     | `12.9.2`     | `12.9.2` -> `12.10.14` -> `13.0.14`  -> `13.1.11` -> `13.8.8` -> `13.12.15`                          | Four intermediate versions are required: `12.10`, `13.0`, `13.1` and `13.8.8`, then `13.12.15`.                                   |
| `13.2.10`      | `11.5.0`     | `11.5.0` -> `11.11.8` -> `12.0.12` -> `12.1.17` -> `12.10.14` -> `13.0.14` -> `13.1.11` -> `13.2.10` | Six intermediate versions are required: `11.11`, `12.0`, `12.1`, `12.10`, `13.0` and `13.1`, then `13.2.10`.                      |
| `12.10.14`     | `11.3.4`     | `11.3.4` -> `11.11.8` -> `12.0.12` -> `12.1.17` -> `12.10.14`                                        | Three intermediate versions are required: `11.11`, `12.0` and `12.1`, then `12.10.14`.                                            |
| `12.9.5`       | `10.4.5`     | `10.4.5` -> `10.8.7` -> `11.11.8` -> `12.0.12` -> `12.1.17` -> `12.9.5`                              | Four intermediate versions are required: `10.8`, `11.11`, `12.0` and `12.1`, then `12.9.5`.                                       |
| `12.2.5`       | `9.2.6`      | `9.2.6` -> `9.5.10` -> `10.8.7` -> `11.11.8` -> `12.0.12` -> `12.1.17` -> `12.2.5`                   | Five intermediate versions are required: `9.5`, `10.8`, `11.11`, `12.0`, and `12.1`, then `12.2.5`.                               |
| `11.3.4`       | `8.13.4`     | `8.13.4` -> `8.17.7` -> `9.5.10` -> `10.8.7` -> `11.3.4`                                             | `8.17.7` is the last version in version 8, `9.5.10` is the last version in version 9, `10.8.7` is the last version in version 10. |

## Upgrading between editions

GitLab comes in two flavors: [Community Edition](https://about.gitlab.com/features/#community) which is MIT licensed,
and [Enterprise Edition](https://about.gitlab.com/features/#enterprise) which builds on top of the Community Edition and
includes extra features mainly aimed at organizations with more than 100 users.

Below you can find some guides to help you change GitLab editions.

### Community to Enterprise Edition

NOTE:
The following guides are for subscribers of the Enterprise Edition only.

If you wish to upgrade your GitLab installation from Community to Enterprise
Edition, follow the guides below based on the installation method:

- [Source CE to EE update guides](upgrading_from_ce_to_ee.md) - The steps are very similar
  to a version upgrade: stop the server, get the code, update configuration files for
  the new functionality, install libraries and do migrations, update the init
  script, start the application and check its status.
- [Omnibus CE to EE](package/convert_to_ee.md) - Follow this guide to update your Omnibus
  GitLab Community Edition to the Enterprise Edition.
- [Docker CE to EE](../install/docker.md#convert-community-edition-to-enterprise-edition) -
  Follow this guide to update your GitLab Community Edition container to an Enterprise Edition container.

### Enterprise to Community Edition

To downgrade your Enterprise Edition installation back to Community
Edition, you can follow [this guide](../downgrade_ee_to_ce/index.md) to make the process as smooth as
possible.

## Version-specific upgrading instructions

Each month, major, minor, or patch releases of GitLab are published along with a
[release post](https://about.gitlab.com/releases/categories/releases/).
You should read the release posts for all versions you're passing over.
At the end of major and minor release posts, there are three sections to look for specifically:

- Deprecations
- Removals
- Important notes on upgrading

These include:

- Steps you must perform as part of an upgrade.
  For example [8.12](https://about.gitlab.com/releases/2016/09/22/gitlab-8-12-released/#upgrade-barometer)
  required the Elasticsearch index to be recreated. Any older version of GitLab upgrading to 8.12 or later would require this.
- Changes to the versions of software we support such as
  [ceasing support for IE11 in GitLab 13](https://about.gitlab.com/releases/2020/03/22/gitlab-12-9-released/#ending-support-for-internet-explorer-11).

Apart from the instructions in this section, you should also check the
installation-specific upgrade instructions, based on how you installed GitLab:

- [Linux packages (Omnibus GitLab)](../update/package/index.md#version-specific-changes)
- [Helm charts](https://docs.gitlab.com/charts/installation/upgrade.html)

NOTE:
Specific information that follow related to Ruby and Git versions do not apply to [Omnibus installations](https://docs.gitlab.com/omnibus/)
and [Helm Chart deployments](https://docs.gitlab.com/charts/). They come with appropriate Ruby and Git versions and are not using system binaries for Ruby and Git. There is no need to install Ruby or Git when utilizing these two approaches.

### 15.4.0

- GitLab 15.4.0 includes a [batched background migration](#batched-background-migrations) to [remove incorrect values from `expire_at` in `ci_job_artifacts` table](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/89318).
  This migration might take hours or days to complete on larger GitLab instances.

### 15.3.3

- In GitLab 15.3.3, [SAML Group Links](../api/groups.md#saml-group-links) API `access_level` attribute type changed to `integer`. See
[valid access levels](../api/members.md#valid-access-levels) documentation.

### 15.3.0

- [Incorrect deletion of object storage files on Geo secondary sites](https://gitlab.com/gitlab-org/gitlab/-/issues/371397) can occur in certain situations. See [Geo: Incorrect object storage LFS file deletion on secondary site issue in GitLab 15.0.0 to 15.3.2](#geo-incorrect-object-storage-lfs-file-deletion-on-secondary-sites-in-gitlab-1500-to-1532).
- LFS transfers can [redirect to the primary from secondary site mid-session](https://gitlab.com/gitlab-org/gitlab/-/issues/371571) causing failed pull and clone requests when [Geo proxying](../administration/geo/secondary_proxy/index.md) is enabled. Geo proxying is enabled by default in GitLab 15.1 and later. See [Geo: LFS transfer redirect to primary from secondary site mid-session issue in GitLab 15.1.0 to 15.3.2](#geo-lfs-transfers-redirect-to-primary-from-secondary-site-mid-session-in-gitlab-1510-to-1532) for more details.

### 15.2.0

- GitLab installations that have multiple web nodes should be
  [upgraded to 15.1](#1510) before upgrading to 15.2 (and later) due to a
  configuration change in Rails that can result in inconsistent ETag key
  generation.
- Some Sidekiq workers were renamed in this release. To avoid any disruption, [run the Rake tasks to migrate any pending jobs](../administration/sidekiq/sidekiq_job_migration.md#future-jobs) before starting the upgrade to GitLab 15.2.0.
- Gitaly now executes its binaries in a [runtime location](https://gitlab.com/gitlab-org/gitaly/-/merge_requests/4670). By default on Omnibus GitLab,
  this path is `/var/opt/gitlab/gitaly/run/`. If this location is mounted with `noexec`, merge requests generate the following error:

  ```plaintext
  fork/exec /var/opt/gitlab/gitaly/run/gitaly-<nnnn>/gitaly-git2go-v15: permission denied
  ```

  To resolve this, remove the `noexec` option from the filesystem mount. An alternative is to change the Gitaly runtime directory:

  1. Add `gitaly['runtime_dir'] = '<PATH_WITH_EXEC_PERM>'` to `/etc/gitlab/gitlab.rb` and specify a location without `noexec` set.
  1. Run `sudo gitlab-ctl reconfigure`.
- [Incorrect deletion of object storage files on Geo secondary sites](https://gitlab.com/gitlab-org/gitlab/-/issues/371397) can occur in certain situations. See [Geo: Incorrect object storage LFS file deletion on secondary site issue in GitLab 15.0.0 to 15.3.2](#geo-incorrect-object-storage-lfs-file-deletion-on-secondary-sites-in-gitlab-1500-to-1532).
- LFS transfers can [redirect to the primary from secondary site mid-session](https://gitlab.com/gitlab-org/gitlab/-/issues/371571) causing failed pull and clone requests when [Geo proxying](../administration/geo/secondary_proxy/index.md) is enabled. Geo proxying is enabled by default in GitLab 15.1 and later. See [Geo: LFS transfer redirect to primary from secondary site mid-session issue in GitLab 15.1.0 to 15.3.2](#geo-lfs-transfers-redirect-to-primary-from-secondary-site-mid-session-in-gitlab-1510-to-1532) for more details.

### 15.1.0

- If you run external PostgreSQL, particularly AWS RDS,
  [check you have a PostgreSQL bug fix](#postgresql-segmentation-fault-issue)
  to avoid the database crashing.
- In GitLab 15.1.0, we are switching Rails `ActiveSupport::Digest` to use SHA256 instead of MD5.
  This affects ETag key generation for resources such as raw Snippet file
  downloads. To ensure consistent ETag key generation across multiple
  web nodes when upgrading, all servers must first be upgraded to 15.1.Z before
  upgrading to 15.2.0 or later:

  1. Ensure all GitLab web nodes are running GitLab 15.1.Z.
  1. [Enable the `active_support_hash_digest_sha256` feature flag](../administration/feature_flags.md#how-to-enable-and-disable-features-behind-flags) to switch `ActiveSupport::Digest` to use SHA256:
  1. Only then, continue to upgrade to later versions of GitLab.
- Unauthenticated requests to the [`ciConfig` GraphQL field](../api/graphql/reference/index.md#queryciconfig) are no longer supported.
  Before you upgrade to GitLab 15.1, add an [access token](../api/index.md#authentication) to your requests.
  The user creating the token must have [permission](../user/permissions.md) to create pipelines in the project.
- [Incorrect deletion of object storage files on Geo secondary sites](https://gitlab.com/gitlab-org/gitlab/-/issues/371397) can occur in certain situations. See [Geo: Incorrect object storage LFS file deletion on secondary site issue in GitLab 15.0.0 to 15.3.2](#geo-incorrect-object-storage-lfs-file-deletion-on-secondary-sites-in-gitlab-1500-to-1532).
- LFS transfers can [redirect to the primary from secondary site mid-session](https://gitlab.com/gitlab-org/gitlab/-/issues/371571) causing failed pull and clone requests when [Geo proxying](../administration/geo/secondary_proxy/index.md) is enabled. Geo proxying is enabled by default in GitLab 15.1 and later. See [Geo: LFS transfer redirect to primary from secondary site mid-session issue in GitLab 15.1.0 to 15.3.2](#geo-lfs-transfers-redirect-to-primary-from-secondary-site-mid-session-in-gitlab-1510-to-1532) for more details.

### 15.0.0

- Elasticsearch 6.8 [is no longer supported](../integration/advanced_search/elasticsearch.md#version-requirements). Before you upgrade to GitLab 15.0, [update Elasticsearch to any 7.x version](../integration/advanced_search/elasticsearch.md#upgrade-to-a-new-elasticsearch-major-version).
- If you run external PostgreSQL, particularly AWS RDS,
  [check you have a PostgreSQL bug fix](#postgresql-segmentation-fault-issue)
  to avoid the database crashing.
- The use of encrypted S3 buckets with storage-specific configuration is no longer supported after [removing support for using `background_upload`](removals.md#background-upload-for-object-storage).
- The [certificate-based Kubernetes integration (DEPRECATED)](../user/infrastructure/clusters/index.md#certificate-based-kubernetes-integration-deprecated) is disabled by default, but you can be re-enable it through the [`certificate_based_clusters` feature flag](../administration/feature_flags.md#how-to-enable-and-disable-features-behind-flags) until GitLab 16.0.
- When you use the GitLab Helm Chart project with a custom `serviceAccount`, ensure it has `get` and `list` permissions for the `serviceAccount` and `secret` resources.
- The [`custom_hooks_dir`](../administration/server_hooks.md#create-global-server-hooks-for-all-repositories) setting for configuring global server hooks is now configured in
  Gitaly. The previous implementation in GitLab Shell was removed in GitLab 15.0. With this change, global server hooks are stored only inside a subdirectory named after the
  hook type. Global server hooks can no longer be a single hook file in the root of the custom hooks directory. For example, you must use `<custom_hooks_dir>/<hook_name>.d/*` rather
  than `<custom_hooks_dir>/<hook_name>`.
- [Incorrect deletion of object storage files on Geo secondary sites](https://gitlab.com/gitlab-org/gitlab/-/issues/371397) can occur in certain situations. See [Geo: Incorrect object storage LFS file deletion on secondary site issue in GitLab 15.0.0 to 15.3.2](#geo-incorrect-object-storage-lfs-file-deletion-on-secondary-sites-in-gitlab-1500-to-1532).
- The `FF_GITLAB_REGISTRY_HELPER_IMAGE` [feature flag](../administration/feature_flags.md#enable-or-disable-the-feature) is removed and helper images are always pulled from GitLab Registry.

### 14.10.0

- Before upgrading to GitLab 14.10, you must already have the latest 14.9.Z installed on your instance.
  The upgrade to GitLab 14.10 executes a [concurrent index drop](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/84308) of unneeded
  entries from the `ci_job_artifacts` database table. This could potentially run for multiple minutes, especially if the table has a lot of
  traffic and the migration is unable to acquire a lock. It is advised to let this process finish as restarting may result in data loss.

- If you run external PostgreSQL, particularly AWS RDS,
  [check you have a PostgreSQL bug fix](#postgresql-segmentation-fault-issue)
  to avoid the database crashing.

- Upgrading to patch level 14.10.3 or later might encounter a one-hour timeout due to a long running database data change,
  if it was not completed while running GitLab 14.9.

  ```plaintext
  FATAL: Mixlib::ShellOut::CommandTimeout: rails_migration[gitlab-rails]
  (gitlab::database_migrations line 51) had an error:
  [..]
  Mixlib::ShellOut::CommandTimeout: Command timed out after 3600s:
  ```

  A workaround exists to [complete the data change and the upgrade manually](package/index.md#mixlibshelloutcommandtimeout-rails_migrationgitlab-rails--command-timed-out-after-3600s).

### 14.9.0

- Database changes made by the upgrade to GitLab 14.9 can take hours or days to complete on larger GitLab instances.
  These [batched background migrations](#batched-background-migrations) update whole database tables to ensure corresponding
  records in `namespaces` table for each record in `projects` table.

  After you update to 14.9.0 or a later 14.9 patch version,
  [batched background migrations must finish](#batched-background-migrations)
  before you update to a later version.

  If the migrations are not finished and you try to update to a later version,
  you see errors like:

  ```plaintext
  Expected batched background migration for the given configuration to be marked as 'finished', but it is 'active':
  ```

  Or

  ```plaintext
  Error executing action `run` on resource 'bash[migrate gitlab-rails database]'
  ================================================================================

  Mixlib::ShellOut::ShellCommandFailed
  ------------------------------------
  Command execution failed. STDOUT/STDERR suppressed for sensitive resource
  ```

- GitLab 14.9.0 includes a
  [background migration `ResetDuplicateCiRunnersTokenValuesOnProjects`](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/79140)
  that may remain stuck permanently in a **pending** state.

  To clean up this stuck job, run the following in the [GitLab Rails Console](../administration/operations/rails_console.md):

  ```ruby
  Gitlab::Database::BackgroundMigrationJob.pending.where(class_name: "ResetDuplicateCiRunnersTokenValuesOnProjects").find_each do |job|
    puts Gitlab::Database::BackgroundMigrationJob.mark_all_as_succeeded("ResetDuplicateCiRunnersTokenValuesOnProjects", job.arguments)
  end
  ```

- If you run external PostgreSQL, particularly AWS RDS,
  [check you have a PostgreSQL bug fix](#postgresql-segmentation-fault-issue)
  to avoid the database crashing.

### 14.8.0

- If upgrading from a version earlier than 14.6.5, 14.7.4, or 14.8.2, review the [Critical Security Release: 14.8.2, 14.7.4, and 14.6.5](https://about.gitlab.com/releases/2022/02/25/critical-security-release-gitlab-14-8-2-released/) blog post.
  Updating to 14.8.2 or later resets runner registration tokens for your groups and projects.
- The agent server for Kubernetes [is enabled by default](https://about.gitlab.com/releases/2022/02/22/gitlab-14-8-released/#the-agent-server-for-kubernetes-is-enabled-by-default)
  on Omnibus installations. If you run GitLab at scale,
  such as [the reference architectures](../administration/reference_architectures/index.md),
  you must disable the agent on the following server types, **if the agent is not required**.

  - Praefect
  - Gitaly
  - Sidekiq
  - Redis (if configured using `redis['enable'] = true` and not via `roles`)
  - Container registry
  - Any other server types based on `roles(['application_role'])`, such as the GitLab Rails nodes

  [The reference architectures](../administration/reference_architectures/index.md) have been updated
  with this configuration change and a specific role for standalone Redis servers.

  Steps to disable the agent:

  1. Add `gitlab_kas['enable'] = false` to `gitlab.rb`.
  1. If the server is already upgraded to 14.8, run `gitlab-ctl reconfigure`.
- GitLab 14.8.0 includes a
[background migration `PopulateTopicsNonPrivateProjectsCount`](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/79140)
that may remain stuck permanently in a **pending** state.

    To clean up this stuck job, run the following in the [GitLab Rails Console](../administration/operations/rails_console.md):

    ```ruby
        Gitlab::Database::BackgroundMigrationJob.pending.where(class_name: "PopulateTopicsNonPrivateProjectsCount").find_each do |job|
          puts Gitlab::Database::BackgroundMigrationJob.mark_all_as_succeeded("PopulateTopicsNonPrivateProjectsCount", job.arguments)
        end
    ```

- If upgrading from a version earlier than 14.3.0, to avoid
  [an issue with job retries](https://gitlab.com/gitlab-org/gitlab/-/issues/357822), first upgrade
  to GitLab 14.7.x and make sure all batched migrations have finished.
- If upgrading from version 14.3.0 or later, you might notice a failed
  [batched migration](../user/admin_area/monitoring/background_migrations.md) named
  `BackfillNamespaceIdForNamespaceRoute`. You can [ignore](https://gitlab.com/gitlab-org/gitlab/-/issues/357822)
  this. Retry it after you upgrade to version 14.9.x.
- If you run external PostgreSQL, particularly AWS RDS,
  [check you have a PostgreSQL bug fix](#postgresql-segmentation-fault-issue)
  to avoid the database crashing.

### 14.7.0

- See [LFS objects import and mirror issue in GitLab 14.6.0 to 14.7.2](#lfs-objects-import-and-mirror-issue-in-gitlab-1460-to-1472).
- If upgrading from a version earlier than 14.6.5, 14.7.4, or 14.8.2, review the [Critical Security Release: 14.8.2, 14.7.4, and 14.6.5](https://about.gitlab.com/releases/2022/02/25/critical-security-release-gitlab-14-8-2-released/) blog post.
  Updating to 14.7.4 or later resets runner registration tokens for your groups and projects.
- GitLab 14.7 introduced a change where Gitaly expects persistent files in the `/tmp` directory.
  When using the `noatime` mount option on `/tmp` in a node running Gitaly, most Linux distributions
  run into [an issue with Git server hooks getting deleted](https://gitlab.com/gitlab-org/gitaly/-/issues/4113).
  These conditions are present in the default Amazon Linux configuration.

  If your Linux distribution manages files in `/tmp` with the `tmpfiles.d` service, you
  can override the behavior of `tmpfiles.d` for the Gitaly files and avoid this issue:

  ```shell
  sudo printf "x /tmp/gitaly-%s-*\n" hooks git-exec-path >/etc/tmpfiles.d/gitaly-workaround.conf
  ```

  This issue is fixed in GitLab 14.10 and later when using the [Gitaly runtime directory](https://docs.gitlab.com/omnibus/update/gitlab_14_changes.html#gitaly-runtime-directory)
  to specify a location to store persistent files.

### 14.6.0

- See [LFS objects import and mirror issue in GitLab 14.6.0 to 14.7.2](#lfs-objects-import-and-mirror-issue-in-gitlab-1460-to-1472).
- If upgrading from a version earlier than 14.6.5, 14.7.4, or 14.8.2, review the [Critical Security Release: 14.8.2, 14.7.4, and 14.6.5](https://about.gitlab.com/releases/2022/02/25/critical-security-release-gitlab-14-8-2-released/) blog post.
  Updating to 14.6.5 or later resets runner registration tokens for your groups and projects.

### 14.5.0

- When `make` is run, Gitaly builds are now created in `_build/bin` and no longer in the root directory of the source directory. If you
are using a source install, update paths to these binaries in your [systemd unit files](upgrading_from_source.md#configure-systemd-units)
or [init scripts](upgrading_from_source.md#configure-sysv-init-script) by [following the documentation](upgrading_from_source.md).

- Connections between Workhorse and Gitaly use the Gitaly `backchannel` protocol by default. If you deployed a gRPC proxy between Workhorse and Gitaly,
  Workhorse can no longer connect. As a workaround, [disable the temporary `workhorse_use_sidechannel`](../administration/feature_flags.md#enable-or-disable-the-feature)
  feature flag. If you need a proxy between Workhorse and Gitaly, use a TCP proxy. If you have feedback about this change, go to [this issue](https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/1301).

- In 14.1 we introduced a background migration that changes how we store merge request diff commits,
  to significantly reduce the amount of storage needed.
  In 14.5 we introduce a set of migrations that wrap up this process by making sure
  that all remaining jobs over the `merge_request_diff_commits` table are completed.
  These jobs have already been processed in most cases so that no extra time is necessary during an upgrade to 14.5.
  However, if there are remaining jobs or you haven't already upgraded to 14.1,
  the deployment may take multiple hours to complete.

  All merge request diff commits automatically incorporate these changes, and there are no
  additional requirements to perform the upgrade.
  Existing data in the `merge_request_diff_commits` table remains unpacked until you run `VACUUM FULL merge_request_diff_commits`.
  However, the `VACUUM FULL` operation locks and rewrites the entire `merge_request_diff_commits` table,
  so the operation takes some time to complete and it blocks access to this table until the end of the process.
  We advise you to only run this command while GitLab is not actively used or it is taken offline for the duration of the process.
  The time it takes to complete depends on the size of the table, which can be obtained by using `select pg_size_pretty(pg_total_relation_size('merge_request_diff_commits'));`.

  For more information, refer to [this issue](https://gitlab.com/gitlab-org/gitlab/-/issues/331823).

- GitLab 14.5.0 includes a
  [background migration `UpdateVulnerabilityOccurrencesLocation`](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/72788)
  that may remain stuck permanently in a **pending** state when the instance lacks records that match the migration's target.

  To clean up this stuck job, run the following in the [GitLab Rails Console](../administration/operations/rails_console.md):

    ```ruby
        Gitlab::Database::BackgroundMigrationJob.pending.where(class_name: "UpdateVulnerabilityOccurrencesLocation").find_each do |job|
          puts Gitlab::Database::BackgroundMigrationJob.mark_all_as_succeeded("UpdateVulnerabilityOccurrencesLocation", job.arguments)
        end
    ```

- Upgrading to 14.5 (or later) [might encounter a one hour timeout](https://gitlab.com/gitlab-org/gitlab/-/issues/354211)
  owing to a long running database data change.

  ```plaintext
  FATAL: Mixlib::ShellOut::CommandTimeout: rails_migration[gitlab-rails]
  (gitlab::database_migrations line 51) had an error:
  [..]
  Mixlib::ShellOut::CommandTimeout: Command timed out after 3600s:
  ```

  [There is a workaround to complete the data change and the upgrade manually](package/index.md#mixlibshelloutcommandtimeout-rails_migrationgitlab-rails--command-timed-out-after-3600s)

### 14.4.4

- For [zero-downtime upgrades](zero_downtime.md) on a GitLab cluster with separate Web and API nodes, you must enable the `paginated_tree_graphql_query` [feature flag](../administration/feature_flags.md#enable-or-disable-the-feature) _before_ upgrading GitLab Web nodes to 14.4.
  This is because we [enabled `paginated_tree_graphql_query` by default in 14.4](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/70913/diffs), so if GitLab UI is on 14.4 and its API is on 14.3, the frontend has this feature enabled but the backend has it disabled. This results in the following error:

  ```shell
  bundle.esm.js:63 Uncaught (in promise) Error: GraphQL error: Field 'paginatedTree' doesn't exist on type 'Repository'
  ```

### 14.4.0

- Git 2.33.x and later is required. We recommend you use the
  [Git version provided by Gitaly](../install/installation.md#git).
- See [Maintenance mode issue in GitLab 13.9 to 14.4](#maintenance-mode-issue-in-gitlab-139-to-144).
- After enabling database load balancing by default in 14.4.0, we found an issue where
  [cron jobs would not work if the connection to PostgreSQL was severed](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/73716),
  as Sidekiq would continue using a bad connection. Geo and other features that rely on
  cron jobs running regularly do not work until Sidekiq is restarted. We recommend
  upgrading to GitLab 14.4.3 and later if this issue affects you.
- After enabling database load balancing by default in 14.4.0, we found an issue where
  [Database load balancing does not work with an AWS Aurora cluster](https://gitlab.com/gitlab-org/gitlab/-/issues/220617).
  We recommend moving your databases from Aurora to RDS for PostgreSQL before
  upgrading. Refer to [Moving GitLab databases to a different PostgreSQL instance](../administration/postgresql/moving.md).
- GitLab 14.4.0 includes a
[background migration `PopulateTopicsTotalProjectsCountCache`](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/71033)
that may remain stuck permanently in a **pending** state when the instance lacks records that match the migration's target.

    To clean up this stuck job, run the following in the [GitLab Rails Console](../administration/operations/rails_console.md):

    ```ruby
        Gitlab::Database::BackgroundMigrationJob.pending.where(class_name: "PopulateTopicsTotalProjectsCountCache").find_each do |job|
          puts Gitlab::Database::BackgroundMigrationJob.mark_all_as_succeeded("PopulateTopicsTotalProjectsCountCache", job.arguments)
        end
    ```

### 14.3.0

- [Instances running 14.0.0 - 14.0.4 should not upgrade directly to GitLab 14.2 or later](#upgrading-to-later-14y-releases).
- Ensure [batched background migrations finish](#batched-background-migrations) before upgrading
  to 14.3.Z from earlier GitLab 14 releases.
- Ruby 2.7.4 is required. Refer to [the Ruby installation instructions](../install/installation.md#2-ruby)
for how to proceed.
- GitLab 14.3.0 contains post-deployment migrations to [address Primary Key overflow risk for tables with an integer PK](https://gitlab.com/groups/gitlab-org/-/epics/4785) for the tables listed below:

  - [`ci_builds.id`](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/70245)
  - [`ci_builds.stage_id`](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/66688)
  - [`ci_builds_metadata`](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/65692)
  - [`taggings`](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/66625)
  - [`events`](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/64779)

  If the migrations are executed as part of a no-downtime deployment, there's a risk of failure due to lock conflicts with the application logic, resulting in lock timeout or deadlocks. In each case, these migrations are safe to re-run until successful:

  ```shell
  # For Omnibus GitLab
  sudo gitlab-rake db:migrate

  # For source installations
  sudo -u git -H bundle exec rake db:migrate RAILS_ENV=production
  ```

- After upgrading to 14.3, ensure that all the `MigrateMergeRequestDiffCommitUsers` background
  migration jobs have completed before continuing with upgrading to GitLab 14.5 or later.
  This is especially important if your GitLab instance has a large
  `merge_request_diff_commits` table. Any pending
  `MigrateMergeRequestDiffCommitUsers` background migration jobs are
  foregrounded in GitLab 14.5, and may take a long time to complete.
  You can check the count of pending jobs for
  `MigrateMergeRequestDiffCommitUsers` by using the PostgreSQL console (or `sudo
  gitlab-psql`):

  ```sql
  select count(*) from background_migration_jobs where class_name = 'MigrateMergeRequestDiffCommitUsers' and status = 0;
  ```

- See [Maintenance mode issue in GitLab 13.9 to 14.4](#maintenance-mode-issue-in-gitlab-139-to-144).

### 14.2.0

- [Instances running 14.0.0 - 14.0.4 should not upgrade directly to GitLab 14.2 or later](#upgrading-to-later-14y-releases).
- Ensure [batched background migrations finish](#batched-background-migrations) before upgrading
  to 14.2.Z from earlier GitLab 14 releases.
- GitLab 14.2.0 contains background migrations to [address Primary Key overflow risk for tables with an integer PK](https://gitlab.com/groups/gitlab-org/-/epics/4785) for the tables listed below:
  - [`ci_build_needs`](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/65216)
  - [`ci_build_trace_chunks`](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/66123)
  - [`ci_builds_runner_session`](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/66433)
  - [`deployments`](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/67341)
  - [`geo_job_artifact_deleted_events`](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/66763)
  - [`push_event_payloads`](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/67299)
  - `ci_job_artifacts`:
    - [Finalize `job_id` conversion to `bigint` for `ci_job_artifacts`](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/67774)
    - [Finalize `ci_job_artifacts` conversion to `bigint`](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/65601)

  If the migrations are executed as part of a no-downtime deployment, there's a risk of failure due to lock conflicts with the application logic, resulting in lock timeout or deadlocks. In each case, these migrations are safe to re-run until successful:

  ```shell
  # For Omnibus GitLab
  sudo gitlab-rake db:migrate

  # For source installations
  sudo -u git -H bundle exec rake db:migrate RAILS_ENV=production
  ```

- See [Maintenance mode issue in GitLab 13.9 to 14.4](#maintenance-mode-issue-in-gitlab-139-to-144).
- GitLab 14.2.0 includes a
  [background migration `BackfillDraftStatusOnMergeRequests`](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/67687)
  that may remain stuck permanently in a **pending** state when the instance lacks records that match the migration's target.

  To clean up this stuck job, run the following in the [GitLab Rails Console](../administration/operations/rails_console.md):

  ```ruby
  Gitlab::Database::BackgroundMigrationJob.pending.where(class_name: "BackfillDraftStatusOnMergeRequests").find_each do |job|
    puts Gitlab::Database::BackgroundMigrationJob.mark_all_as_succeeded("BackfillDraftStatusOnMergeRequests", job.arguments)
  end
  ```

### 14.1.0

- [Instances running 14.0.0 - 14.0.4 should not upgrade directly to GitLab 14.2 or later](#upgrading-to-later-14y-releases)
  but can upgrade to 14.1.Z.

  It is not required for instances already running 14.0.5 (or later) to stop at 14.1.Z.
  14.1 is included on the upgrade path for the broadest compatibility
  with self-managed installations, and ensure 14.0.0-14.0.4 installations do not
  encounter issues with [batched background migrations](#batched-background-migrations).

- Upgrading to GitLab [14.5](#1450) (or later) may take a lot longer if you do not upgrade to at least 14.1
  first. The 14.1 merge request diff commits database migration can take hours to run, but runs in the
  background while GitLab is in use. GitLab instances upgraded directly from 14.0 to 14.5 or later must
  run the migration in the foreground and therefore take a lot longer to complete.

- See [Maintenance mode issue in GitLab 13.9 to 14.4](#maintenance-mode-issue-in-gitlab-139-to-144).

### 14.0.0

Prerequisites:

- The [GitLab 14.0 release post contains several important notes](https://about.gitlab.com/releases/2021/06/22/gitlab-14-0-released/#upgrade)
  about pre-requisites including [using Patroni instead of repmgr](../administration/postgresql/replication_and_failover.md#switching-from-repmgr-to-patroni),
  migrating [to hashed storage](../administration/raketasks/storage.md#migrate-to-hashed-storage),
  and [to Puma](../administration/operations/puma.md).
- The support of PostgreSQL 11 [has been dropped](../install/requirements.md#database). Make sure to [update your database](https://docs.gitlab.com/omnibus/settings/database.html#upgrade-packaged-postgresql-server) to version 12 before updating to GitLab 14.0.

Long running batched background database migrations:

- Database changes made by the upgrade to GitLab 14.0 can take hours or days to complete on larger GitLab instances.
  These [batched background migrations](#batched-background-migrations) update whole database tables to mitigate primary key overflow and must be finished before upgrading to GitLab 14.2 or later.
- Due to an issue where `BatchedBackgroundMigrationWorkers` were
  [not working](https://gitlab.com/gitlab-org/charts/gitlab/-/issues/2785#note_614738345)
  for self-managed instances, a [fix was created](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/65106)
  that requires an update to at least 14.0.5. The fix was also released in [14.1.0](#1410).

  After you update to 14.0.5 or a later 14.0 patch version,
  [batched background migrations must finish](#batched-background-migrations)
  before you update to a later version.

  If the migrations are not finished and you try to update to a later version,
  you see an error like:

  ```plaintext
  Expected batched background migration for the given configuration to be marked as 'finished', but it is 'active':
  ```

  See how to [resolve this error](../user/admin_area/monitoring/background_migrations.md#database-migrations-failing-because-of-batched-background-migration-not-finished).

Other issues:

- In GitLab 13.3 some [pipeline processing methods were deprecated](https://gitlab.com/gitlab-org/gitlab/-/issues/218536)
  and this code was completely removed in GitLab 14.0. If you plan to upgrade from
  **GitLab 13.2 or older** directly to 14.0, this is [unsupported](#upgrading-to-a-new-major-version).
  You should instead follow a [supported upgrade path](#upgrade-paths).
- See [Maintenance mode issue in GitLab 13.9 to 14.4](#maintenance-mode-issue-in-gitlab-139-to-144).
- See [Custom Rack Attack initializers](#custom-rack-attack-initializers) if you persist your own custom Rack Attack
  initializers during upgrades.

#### Upgrading to later 14.Y releases

- Instances running 14.0.0 - 14.0.4 should not upgrade directly to GitLab 14.2 or later,
  because of [batched background migrations](#batched-background-migrations).
  1. Upgrade first to either:
     - 14.0.5 or a later 14.0.Z patch release.
     - 14.1.0 or a later 14.1.Z patch release.
  1. [Batched background migrations must finish](#batched-background-migrations)
     before you update to a later version [and may take longer than usual](#1400).

### 13.12.0

- See [Maintenance mode issue in GitLab 13.9 to 14.4](#maintenance-mode-issue-in-gitlab-139-to-144).

- Check the GitLab database [has no references to legacy storage](../administration/raketasks/storage.md#on-legacy-storage).
  The GitLab 14.0 pre-install check causes the package update to fail if unmigrated data exists:

  ```plaintext
  Checking for unmigrated data on legacy storage

  Legacy storage is no longer supported. Please migrate your data to hashed storage.
  ```

### 13.11.0

- Git 2.31.x and later is required. We recommend you use the
  [Git version provided by Gitaly](../install/installation.md#git).

- See [Maintenance mode issue in GitLab 13.9 to 14.4](#maintenance-mode-issue-in-gitlab-139-to-144).

- GitLab 13.11 includes a faulty background migration ([`RescheduleArtifactExpiryBackfillAgain`](https://gitlab.com/gitlab-org/gitlab/-/blob/ccc70031b843ff8cff1185988c2e472a521c2701/db/post_migrate/20210413132500_reschedule_artifact_expiry_backfill_again.rb))
  that incorrectly sets the `expire_at` column in the `ci_job_artifacts` database table.
  Incorrect `expire_at` values can potentially cause data loss.

  To prevent this risk of data loss, you must remove the content of the `RescheduleArtifactExpiryBackfillAgain`
  migration, which makes it a no-op migration. You can repeat the changes from the
  [commit that makes the migration no-op in 14.9 and later](https://gitlab.com/gitlab-org/gitlab/-/blob/42c3dfc5a1c8181767bbb5c76e7c5fa6fefbbc2b/db/post_migrate/20210413132500_reschedule_artifact_expiry_backfill_again.rb).
  For more information, see [how to disable a data migration](../development/database/deleting_migrations.md#how-to-disable-a-data-migration).

### 13.10.0

See [Maintenance mode issue in GitLab 13.9 to 14.4](#maintenance-mode-issue-in-gitlab-139-to-144).

### 13.9.0

- We've detected an issue [with a column rename](https://gitlab.com/gitlab-org/gitlab/-/issues/324160)
  that prevents upgrades to GitLab 13.9.0, 13.9.1, 13.9.2, and 13.9.3 when following the zero-downtime steps. It is necessary
  to perform the following additional steps for the zero-downtime upgrade:

  1. Before running the final `sudo gitlab-rake db:migrate` command on the deploy node,
     execute the following queries using the PostgreSQL console (or `sudo gitlab-psql`)
     to drop the problematic triggers:

     ```sql
     drop trigger trigger_e40a6f1858e6 on application_settings;
     drop trigger trigger_0d588df444c8 on application_settings;
     drop trigger trigger_1572cbc9a15f on application_settings;
     drop trigger trigger_22a39c5c25f3 on application_settings;
     ```

  1. Run the final migrations:

     ```shell
     sudo gitlab-rake db:migrate
     ```

  If you have already run the final `sudo gitlab-rake db:migrate` command on the deploy node and have
  encountered the [column rename issue](https://gitlab.com/gitlab-org/gitlab/-/issues/324160), you
  see the following error:

  ```shell
  -- remove_column(:application_settings, :asset_proxy_whitelist)
  rake aborted!
  StandardError: An error has occurred, all later migrations canceled:
  PG::DependentObjectsStillExist: ERROR: cannot drop column asset_proxy_whitelist of table application_settings because other objects depend on it
  DETAIL: trigger trigger_0d588df444c8 on table application_settings depends on column asset_proxy_whitelist of table application_settings
  ```

  To work around this bug, follow the previous steps to complete the update.
  More details are available [in this issue](https://gitlab.com/gitlab-org/gitlab/-/issues/324160).

- See [Maintenance mode issue in GitLab 13.9 to 14.4](#maintenance-mode-issue-in-gitlab-139-to-144).

- For GitLab Enterprise Edition customers, we noticed an issue when [subscription expiration is upcoming, and you create new subgroups and projects](https://gitlab.com/gitlab-org/gitlab/-/issues/322546). If you fall under that category and get 500 errors, you can work around this issue:

  1. SSH into you GitLab server, and open a Rails console:

     ```shell
     sudo gitlab-rails console
     ```

  1. Disable the following features:

     ```ruby
     Feature.disable(:subscribable_subscription_banner)
     Feature.disable(:subscribable_license_banner)
     ```

  1. Restart Puma or Unicorn:

     ```shell
     #For installations using Puma
     sudo gitlab-ctl restart puma

     #For installations using Unicorn
     sudo gitlab-ctl restart unicorn
     ```

### 13.8.8

GitLab 13.8 includes a background migration to address [an issue with duplicate service records](https://gitlab.com/gitlab-org/gitlab/-/issues/290008). If duplicate services are present, this background migration must complete before a unique index is applied to the services table, which was [introduced in GitLab 13.9](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/52563). Upgrades from GitLab 13.8 and earlier to later versions must include an intermediate upgrade to GitLab 13.8.8 and [must wait until the background migrations complete](#checking-for-background-migrations-before-upgrading) before proceeding.

If duplicate services are still present, an upgrade to 13.9.x or later results in a failed upgrade with the following error:

```console
PG::UniqueViolation: ERROR:  could not create unique index "index_services_on_project_id_and_type_unique"
DETAIL:  Key (project_id, type)=(NNN, ServiceName) is duplicated.
```

### 13.6.0

Ruby 2.7.2 is required. GitLab does not start with Ruby 2.6.6 or older versions.

The required Git version is Git v2.29 or later.

GitLab 13.6 includes a
[background migration `BackfillJiraTrackerDeploymentType2`](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/46368)
that may remain stuck permanently in a **pending** state despite completion of work
due to a bug.

To clean up this stuck job, run the following in the [GitLab Rails Console](../administration/operations/rails_console.md):

```ruby
Gitlab::Database::BackgroundMigrationJob.pending.where(class_name: "BackfillJiraTrackerDeploymentType2").find_each do |job|
  puts Gitlab::Database::BackgroundMigrationJob.mark_all_as_succeeded("BackfillJiraTrackerDeploymentType2", job.arguments)
end
```

### 13.4.0

GitLab 13.4.0 includes a background migration to [move all remaining repositories in legacy storage to hashed storage](../administration/raketasks/storage.md#migrate-to-hashed-storage). There are [known issues with this migration](https://gitlab.com/gitlab-org/gitlab/-/issues/259605) which are fixed in GitLab 13.5.4 and later. If possible, skip 13.4.0 and upgrade to 13.5.4 or later instead. The migration can take quite a while to run, depending on how many repositories must be moved. Be sure to check that all background migrations have completed before upgrading further.

### 13.3.0

The recommended Git version is Git v2.28. The minimum required version of Git
v2.24 remains the same.

### 13.2.0

GitLab installations that have multiple web nodes must be
[upgraded to 13.1](#1310) before upgrading to 13.2 (and later) due to a
breaking change in Rails that can result in authorization issues.

GitLab 13.2.0 [remediates](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/35492) an [email verification bypass](https://about.gitlab.com/releases/2020/05/27/security-release-13-0-1-released/).
After upgrading, if some of your users are unexpectedly encountering 404 or 422 errors when signing in,
or "blocked" messages when using the command line,
their accounts may have been un-confirmed.
In that case, ask them to check their email for a re-confirmation link.
For more information, see our discussion of [Email confirmation issues](../user/upgrade_email_bypass.md).

GitLab 13.2.0 relies on the `btree_gist` extension for PostgreSQL. For installations with an externally managed PostgreSQL setup, make sure to
[install the extension manually](https://www.postgresql.org/docs/11/sql-createextension.html) before upgrading GitLab if the database user for GitLab
is not a superuser. This is not necessary for installations using a GitLab managed PostgreSQL database.

### 13.1.0

In 13.1.0, you must upgrade to either:

- At least Git v2.24 (previously, the minimum required version was Git v2.22).
- The recommended Git v2.26.

Failure to do so results in internal errors in the Gitaly service in some RPCs due
to the use of the new `--end-of-options` Git flag.

Additionally, in GitLab 13.1.0, the version of
[Rails was upgraded from 6.0.3 to 6.0.3.1](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/33454).
The Rails upgrade included a change to CSRF token generation which is
not backwards-compatible - GitLab servers with the new Rails version
generate CSRF tokens that are not recognizable by GitLab servers
with the older Rails version - which could cause non-GET requests to
fail for [multi-node GitLab installations](zero_downtime.md#multi-node--ha-deployment).

So, if you are using multiple Rails servers and specifically upgrading from 13.0,
all servers must first be upgraded to 13.1.Z before upgrading to 13.2.0 or later:

1. Ensure all GitLab web nodes are running GitLab 13.1.Z.
1. Enable the `global_csrf_token` feature flag to enable new
   method of CSRF token generation:

   ```ruby
   Feature.enable(:global_csrf_token)
   ```

1. Only then, continue to upgrade to later versions of GitLab.

#### Custom Rack Attack initializers

From GitLab 13.0.1, custom Rack Attack initializers (`config/initializers/rack_attack.rb`) are replaced with initializers
supplied with GitLab during upgrades. We recommend you use these GitLab-supplied initializers.

If you persist your own Rack Attack initializers between upgrades, you might
[get `500` errors](https://gitlab.com/gitlab-org/gitlab/-/issues/334681) when [upgrading to GitLab 14.0 and later](#1400).

### 12.10.0

- The final patch release (12.10.14)
  [has a regression affecting maven package uploads](https://about.gitlab.com/releases/2020/07/06/critical-security-release-gitlab-13-1-3-released/#maven-package-upload-broken-in-121014).
  If you use this feature and must stay on 12.10 while preparing to upgrade to 13.0:

  - Upgrade to 12.10.13 instead.
  - Upgrade to 13.0.14 as soon as possible.

- [GitLab 13.0 requires PostgreSQL 11](https://about.gitlab.com/releases/2020/05/22/gitlab-13-0-released/#postgresql-11-is-now-the-minimum-required-version-to-install-gitlab).

  - 12.10 is the final release that shipped with PostgreSQL 9.6, 10, and 11.
  - You should make sure that your database is PostgreSQL 11 on GitLab 12.10 before upgrading to 13.0. This upgrade requires downtime.

### 12.2.0

In 12.2.0, we enabled Rails' authenticated cookie encryption. Old sessions are
automatically upgraded.

However, session cookie downgrades are not supported. So after upgrading to 12.2.0,
any downgrades would result to all sessions being invalidated and users are logged out.

### 12.1.0

If you are planning to upgrade from `12.0.Z` to `12.10.Z`, it is necessary to
perform an intermediary upgrade to `12.1.Z` before upgrading to `12.10.Z` to
avoid issues like [#215141](https://gitlab.com/gitlab-org/gitlab/-/issues/215141).

### 12.0.0

In 12.0.0 we made various database related changes. These changes require that
users first upgrade to the latest 11.11 patch release. After upgraded to 11.11.Z,
users can upgrade to 12.0.Z. Failure to do so may result in database migrations
not being applied, which could lead to application errors.

It is also required that you upgrade to 12.0.Z before moving to a later version
of 12.Y.

Example 1: you are currently using GitLab 11.11.8, which is the latest patch
release for 11.11.Z. You can upgrade as usual to 12.0.Z.

Example 2: you are currently using a version of GitLab 10.Y. To upgrade, first
upgrade to the last 10.Y release (10.8.7) then the last 11.Y release (11.11.8).
After upgraded to 11.11.8 you can safely upgrade to 12.0.Z.

See our [documentation on upgrade paths](../policy/maintenance.md#upgrade-recommendations)
for more information.

### Maintenance mode issue in GitLab 13.9 to 14.4

When [Maintenance mode](../administration/maintenance_mode/index.md) is enabled, users cannot sign in with SSO, SAML, or LDAP.

Users who were signed in before Maintenance mode was enabled, continue to be signed in. If the administrator who enabled Maintenance mode loses their session, then they can't disable Maintenance mode via the UI. In that case, you can [disable Maintenance mode via the API or Rails console](../administration/maintenance_mode/index.md#disable-maintenance-mode).

[This bug](https://gitlab.com/gitlab-org/gitlab/-/issues/329261) was fixed in GitLab 14.5.0 and backported into 14.4.3 and 14.3.5.

### LFS objects import and mirror issue in GitLab 14.6.0 to 14.7.2

When Geo is enabled, LFS objects fail to be saved for imported or mirrored projects.

[This bug](https://gitlab.com/gitlab-org/gitlab/-/issues/352368) was fixed in GitLab 14.8.0 and backported into 14.7.3.

### PostgreSQL segmentation fault issue

If you run GitLab with external PostgreSQL, particularly AWS RDS, ensure you upgrade PostgreSQL
to patch levels to a minimum of 12.7 or 13.3 before upgrading to GitLab 14.8 or later.

[In 14.8](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/75511)
for GitLab Enterprise Edition and [in 15.1](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/87983)
for GitLab Community Edition a GitLab feature called Loose Foreign Keys was enabled.

After it was enabled, we have had reports of unplanned PostgreSQL restarts caused
by a database engine bug that causes a segmentation fault.

Read more [in the issue](https://gitlab.com/gitlab-org/gitlab/-/issues/364763).

### Geo: Incorrect object storage LFS file deletion on secondary sites in GitLab 15.0.0 to 15.3.2

[Incorrect deletion of object storage files on Geo secondary sites](https://gitlab.com/gitlab-org/gitlab/-/issues/371397)
can occur in GitLab 15.0.0 to 15.3.2 in the following situations:

- GitLab-managed object storage replication is disabled, and LFS objects are created while importing a project with object storage enabled.
- GitLab-managed replication to sync object storage is enabled and subsequently disabled.

This issue is resolved in 15.3.3. Customers who have both LFS enabled and LFS objects being replicated across Geo sites
should upgrade directly to 15.3.3 to reduce the risk of data loss on secondary sites.

### Geo: LFS transfers redirect to primary from secondary site mid-session in GitLab 15.1.0 to 15.3.2

LFS transfers can [redirect to the primary from secondary site mid-session](https://gitlab.com/gitlab-org/gitlab/-/issues/371571) causing failed pull and clone requests in GitLab 15.1.0 to 15.3.2 when [Geo proxying](../administration/geo/secondary_proxy/index.md) is enabled. Geo proxying is enabled by default in GitLab 15.1 and later.

This issue is resolved in GitLab 15.3.3, so customers with the following configuration should upgrade to 15.3.3 or later:

- LFS is enabled.
- LFS objects are being replicated across Geo sites.
- Repositories are being pulled by using a Geo secondary site.

## Miscellaneous

- [MySQL to PostgreSQL](mysql_to_postgresql.md) guides you through migrating
  your database from MySQL to PostgreSQL.
- [Restoring from backup after a failed upgrade](restore_after_failure.md)
- [Upgrading PostgreSQL Using Slony](upgrading_postgresql_using_slony.md), for
  upgrading a PostgreSQL database with minimal downtime.
- [Managing PostgreSQL extensions](../install/postgresql_extensions.md)
