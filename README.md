[![CI](https://github.com/yumemi-inc/gradle-dependency-diff-report/actions/workflows/ci.yml/badge.svg)](https://github.com/yumemi-inc/gradle-dependency-diff-report/actions/workflows/ci.yml)

# [BETA] Gradle Dependency Diff Report

A GitHub Action that reports Gradle dependency differences.
The report is displayed in the pull request job summary, like [this](https://github.com/yumemi-inc/gradle-dependency-diff-report/actions/runs/6220601823).

At a minimum, you can simply implement a workflow as follows:

```yaml
name: Dependency Diff Report

on: pull_request

jobs:
  report:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: yumemi-inc/gradle-dependency-diff-report@main
        with:
          modules: 'app'
          configuration: 'releaseRuntimeClasspath'
```

Reports are created with Gradle `dependencies` task, [dependency-diff-tldr](https://github.com/careem/dependency-diff-tldr), and [Dependency Tree Diff](https://github.com/JakeWharton/dependency-tree-diff).

## Usage

See [action.yml](action.yml) for available action inputs and outputs.
Note that this action requires `contents: read` permission.

### Specifying multiple modules

If you specify only the root module of the application, the modules that root depends on will also be reported.
But if there is no root module or if you need to report on individual modules, specify them separated by spaces.

```yaml
- uses: yumemi-inc/gradle-dependency-diff-report@main
  with:
    modules: 'app feature:main feature:login domain'
    configuration: 'releaseRuntimeClasspath'
```

At this time, if you want to apply a different configuration, specify it separated by `|`.

```yaml
- uses: yumemi-inc/gradle-dependency-diff-report@main
  with:
    modules: 'app|productReleaseRuntimeClasspath feature:main feature:login domain|debugRuntimeClasspath'
    configuration: 'releaseRuntimeClasspath'
```

### Specifying the Java version

If not specified, the default version of the runner will be applied.
For `ubuntu-22.04` it is `11`.
If you want to use a different version, specify it using [actions/setup-java](https://github.com/actions/setup-java).

```yaml
- uses: actions/setup-java@v3
  with:
    distribution: 'zulu'
    java-version: 17
- uses: yumemi-inc/gradle-dependency-diff-report@main
  with:
    modules: 'app'
    configuration: 'releaseRuntimeClasspath'
```
### Don't consider base branch

By default, the latest code in the base branch of a pull request is considered.
To report dependency differences only in pull requests without considering the base branch, set `compare-with-base` input to `false`.

```yaml
- uses: yumemi-inc/gradle-dependency-diff-report@main
  with:
    modules: 'app'
    configuration: 'releaseRuntimeClasspath'
    compare-with-base: false
```
Note that `pull-requests: read` permission is required in this case.

### Specifying the application root directory

If the repository root directory and application root directory do not match, specify it with `project-dir` input.

```yaml
- uses: yumemi-inc/gradle-dependency-diff-report@main
  with:
    modules: 'app'
    configuration: 'releaseRuntimeClasspath'
    project-dir: 'my-app'
```

## Tips

### Report only when library changes

To prevent unnecessary workflow runs, run only when the file that contains the library version is changed.

```yaml
on:
  pull_request:
    paths:
      - '**/*.gradle*'
      - '**/libs.versions.toml'
```

### Using this action's output

Use the `exists-diff` output of this action to notify the pull request with a comment if there are any differences in dependencies.

```yaml
- uses: yumemi-inc/gradle-dependency-diff-report@main
  id: report
  with:
    modules: 'app'
    configuration: 'releaseRuntimeClasspath'
- if: steps.report.outputs.exists-diff == 'true'
  uses: yumemi-inc/comment-pull-request@v1 # Note: requires 'pull-requests: write' permission
  with:
    comment: |
      :warning: There are differences in dependencies. See details [here](https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}).
```

### Using Gradle cache

This action uses Gradle `dependencies` task, so you can expect faster processing by using Gradle cache.

```yaml
- uses: gradle/gradle-build-action@v2
- uses: yumemi-inc/gradle-dependency-diff-report@main
  with:
    modules: 'app'
    configuration: 'releaseRuntimeClasspath'
```

> [!NOTE]  
> Since [gradle/gradle-build-action](https://github.com/gradle/gradle-build-action#using-the-cache-read-only) does not generate a cache in the HEAD branch of a pull request, in order to use the cache in a pull request, you must first generate a cache in the default branch with another workflow or something.

### Triggered by push event

This action can be triggered not only by `pull_request` events but also by `push` events.
In this case, the difference from the previous commit.

```yaml
on:
  push:
    branches:
      - 'main'
    paths:
      - '**/*.gradle*'
      - '**/libs.versions.toml'
```

### Process multiple modules in parallel

By processing multiple modules in parallel with multiple jobs, waiting time can be expected to be reduced.

<details>
<summary>example</summary>

```yaml
jobs:
  report-group-a:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    outputs:
      exists-diff: ${{ steps.report.outputs.exists-diff }}
    steps:
      - uses: yumemi-inc/gradle-dependency-diff-report@main
        id: report
        with:
          modules: 'app domain'
          configuration: 'releaseRuntimeClasspath'
  report-group-b:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    outputs:
      exists-diff: ${{ steps.report.outputs.exists-diff }}
    steps:
      - uses: yumemi-inc/gradle-dependency-diff-report@main
        id: report
        with:
          modules: 'feature:main feature:login'
          configuration: 'releaseRuntimeClasspath'
  comment-on-pull-request:
    if: contains(needs.*.outputs.exists-diff, 'true')
    needs: [report-group-a, report-group-b]
    runs-on: ubuntu-latest
    permissions:
      pull-requests: write
    steps:
      - uses: yumemi-inc/comment-pull-request@v1
      ...
```
</details>

### Pass environment variables

If you want to pass some environment variables when running your application's `dependencies` task, specify them with `env`.

```yaml
- uses: yumemi-inc/gradle-dependency-diff-report@main
  with:
    modules: 'app'
    configuration: 'releaseRuntimeClasspath'
  env:
    YOUR_ENV_1: ...
    YOUR_ENV_2: ...
```

### Run bash script

If you want to do some processing before your application's `dependencies` task, specify it with `script` input.

```yaml
- uses: yumemi-inc/gradle-dependency-diff-report@main
  with:
    modules: 'app'
    configuration: 'releaseRuntimeClasspath'
    script: |
      cp .github/ci-gradle.properties ~/.gradle/gradle.properties
      ...
```

At this time, environment variables and `${{ }}` expressions can be used.

```yaml
- uses: yumemi-inc/gradle-dependency-diff-report@main
  with:
    modules: 'app'
    configuration: 'releaseRuntimeClasspath'
    script: |
      echo $GITHUB_REF
      echo ${{ github.actor }}
```

## Examples

<details>
<summary>A workflow I often create</summary>

```yaml
name: Dependency Diff Report

on:
  pull_request:
    paths:
      - '**/*.gradle*'
      - '**/libs.versions.toml'

concurrency:
  group: ${{ github.workflow }}-${{ github.head_ref || github.run_id }}
  cancel-in-progress: true

jobs:
  report:
    name: Report dependency differences
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    env:
      LOG_URL: https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}
    steps:
      - name: Set up JDK
        uses: actions/setup-java@v3
        with:
          distribution: 'zulu'
          java-version: '17'
      - name: Report
        uses: yumemi-inc/gradle-dependency-diff-report@main
        id: report
        with:
          modules: 'app'
          configuration: 'ProductionReleaseRuntimeClasspath'
      - name: Comment
        if: steps.report.outputs.exists-diff == 'true' || failure()
        uses: yumemi-inc/comment-pull-request@v1
        with:
          comment: ':warning: There are differences in dependencies. See details [here](${{ env.LOG_URL }}).'
          comment-if-failure: ':exclamation: Report workflow failed. See details [here](${{ env.LOG_URL }}).'
```
</details>

## Other topics

### Slides related to this action

- (Japanese) [CI でライブラリのバージョンの変化をレポートする](https://speakerdeck.com/hkusu/ci-teraihurarinohasiyonnobian-hua-worehotosuru)
