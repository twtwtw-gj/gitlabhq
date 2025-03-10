<script>
import { GlSafeHtmlDirective } from '@gitlab/ui';
import { isEmpty } from 'lodash';
import { registerExtension } from '~/vue_merge_request_widget/components/extensions';
import MrWidgetApprovals from 'ee_else_ce/vue_merge_request_widget/components/approvals/approvals.vue';
import MRWidgetService from 'ee_else_ce/vue_merge_request_widget/services/mr_widget_service';
import MRWidgetStore from 'ee_else_ce/vue_merge_request_widget/stores/mr_widget_store';
import { stateToComponentMap as classState } from 'ee_else_ce/vue_merge_request_widget/stores/state_maps';
import createFlash from '~/flash';
import { secondsToMilliseconds } from '~/lib/utils/datetime_utility';
import notify from '~/lib/utils/notify';
import { sprintf, s__, __ } from '~/locale';
import Project from '~/pages/projects/project';
import SmartInterval from '~/smart_interval';
import { setFaviconOverlay } from '../lib/utils/favicon';
import Loading from './components/loading.vue';
import MrWidgetAlertMessage from './components/mr_widget_alert_message.vue';
import MrWidgetPipelineContainer from './components/mr_widget_pipeline_container.vue';
import WidgetSuggestPipeline from './components/mr_widget_suggest_pipeline.vue';
import SourceBranchRemovalStatus from './components/source_branch_removal_status.vue';
import ArchivedState from './components/states/mr_widget_archived.vue';
import MrWidgetAutoMergeEnabled from './components/states/mr_widget_auto_merge_enabled.vue';
import AutoMergeFailed from './components/states/mr_widget_auto_merge_failed.vue';
import CheckingState from './components/states/mr_widget_checking.vue';
import ClosedState from './components/states/mr_widget_closed.vue';
import ConflictsState from './components/states/mr_widget_conflicts.vue';
import FailedToMerge from './components/states/mr_widget_failed_to_merge.vue';
import MergedState from './components/states/mr_widget_merged.vue';
import MergingState from './components/states/mr_widget_merging.vue';
import MissingBranchState from './components/states/mr_widget_missing_branch.vue';
import NotAllowedState from './components/states/mr_widget_not_allowed.vue';
import PipelineBlockedState from './components/states/mr_widget_pipeline_blocked.vue';
import RebaseState from './components/states/mr_widget_rebase.vue';
import NothingToMergeState from './components/states/nothing_to_merge.vue';
import PipelineFailedState from './components/states/pipeline_failed.vue';
import ReadyToMergeState from './components/states/ready_to_merge.vue';
import ShaMismatch from './components/states/sha_mismatch.vue';
import UnresolvedDiscussionsState from './components/states/unresolved_discussions.vue';
import WorkInProgressState from './components/states/work_in_progress.vue';
import ExtensionsContainer from './components/extensions/container';
import WidgetContainer from './components/widget/app.vue';
import { STATE_MACHINE, stateToComponentMap } from './constants';
import eventHub from './event_hub';
import mergeRequestQueryVariablesMixin from './mixins/merge_request_query_variables';
import getStateQuery from './queries/get_state.query.graphql';
import terraformExtension from './extensions/terraform';
import accessibilityExtension from './extensions/accessibility';
import codeQualityExtension from './extensions/code_quality';
import testReportExtension from './extensions/test_report';

export default {
  // False positive i18n lint: https://gitlab.com/gitlab-org/frontend/eslint-plugin-i18n/issues/25
  // eslint-disable-next-line @gitlab/require-i18n-strings
  name: 'MRWidget',
  directives: {
    SafeHtml: GlSafeHtmlDirective,
  },
  components: {
    Loading,
    ExtensionsContainer,
    WidgetContainer,
    MrWidgetSuggestPipeline: WidgetSuggestPipeline,
    MrWidgetPipelineContainer,
    MrWidgetAlertMessage,
    MrWidgetMerged: MergedState,
    MrWidgetClosed: ClosedState,
    MrWidgetMerging: MergingState,
    MrWidgetFailedToMerge: FailedToMerge,
    MrWidgetWip: WorkInProgressState,
    MrWidgetArchived: ArchivedState,
    MrWidgetConflicts: ConflictsState,
    MrWidgetNothingToMerge: NothingToMergeState,
    MrWidgetNotAllowed: NotAllowedState,
    MrWidgetMissingBranch: MissingBranchState,
    MrWidgetReadyToMerge: () => import('./components/states/new_ready_to_merge.vue'),
    ShaMismatch,
    MrWidgetChecking: CheckingState,
    MrWidgetUnresolvedDiscussions: UnresolvedDiscussionsState,
    MrWidgetPipelineBlocked: PipelineBlockedState,
    MrWidgetPipelineFailed: PipelineFailedState,
    MrWidgetAutoMergeEnabled,
    MrWidgetAutoMergeFailed: AutoMergeFailed,
    MrWidgetRebase: RebaseState,
    SourceBranchRemovalStatus,
    GroupedCodequalityReportsApp: () =>
      import('../reports/codequality_report/grouped_codequality_reports_app.vue'),
    GroupedTestReportsApp: () =>
      import('../reports/grouped_test_report/grouped_test_reports_app.vue'),
    MrWidgetApprovals,
    SecurityReportsApp: () => import('~/vue_shared/security_reports/security_reports_app.vue'),
    MergeChecksFailed: () => import('./components/states/merge_checks_failed.vue'),
    ReadyToMerge: ReadyToMergeState,
  },
  apollo: {
    state: {
      query: getStateQuery,
      manual: true,
      skip() {
        return !this.mr || !window.gon?.features?.mergeRequestWidgetGraphql;
      },
      variables() {
        return this.mergeRequestQueryVariables;
      },
      result({ data: { project } }) {
        if (project) {
          this.mr.setGraphqlData(project);
          this.loading = false;
        }
      },
    },
  },
  mixins: [mergeRequestQueryVariablesMixin],
  props: {
    mrData: {
      type: Object,
      required: false,
      default: null,
    },
  },
  data() {
    const store = this.mrData && new MRWidgetStore(this.mrData);

    return {
      mr: store,
      state: store && store.state,
      service: store && this.createService(store),
      machineState: store?.machineValue || STATE_MACHINE.definition.initial,
      loading: true,
      recomputeComponentName: 0,
    };
  },
  computed: {
    isLoaded() {
      if (window.gon?.features?.mergeRequestWidgetGraphql) {
        return !this.loading;
      }

      return this.mr;
    },
    shouldRenderApprovals() {
      return this.mr.state !== 'nothingToMerge';
    },
    componentName() {
      return stateToComponentMap[this.machineState] || classState[this.mr.state];
    },
    hasPipelineMustSucceedConflict() {
      return !this.mr.hasCI && this.mr.onlyAllowMergeIfPipelineSucceeds;
    },
    shouldRenderPipelines() {
      return this.mr.hasCI || this.hasPipelineMustSucceedConflict;
    },
    shouldSuggestPipelines() {
      const { hasCI, mergeRequestAddCiConfigPath, isDismissedSuggestPipeline } = this.mr;

      return !hasCI && mergeRequestAddCiConfigPath && !isDismissedSuggestPipeline;
    },
    shouldRenderCodeQuality() {
      return this.mr?.codequalityReportsPath;
    },
    shouldRenderSourceBranchRemovalStatus() {
      return (
        !this.mr.canRemoveSourceBranch &&
        this.mr.shouldRemoveSourceBranch &&
        !this.mr.isNothingToMergeState &&
        !this.mr.isMergedState
      );
    },
    shouldRenderCollaborationStatus() {
      return this.mr.allowCollaboration && this.mr.isOpen;
    },
    shouldRenderMergedPipeline() {
      return this.mr.state === 'merged' && !isEmpty(this.mr.mergePipeline);
    },
    showMergePipelineForkWarning() {
      return Boolean(
        this.mr.mergePipelinesEnabled && this.mr.sourceProjectId !== this.mr.targetProjectId,
      );
    },
    shouldRenderSecurityReport() {
      return Boolean(this.mr?.pipeline?.id);
    },
    shouldRenderTerraformPlans() {
      return Boolean(this.mr?.terraformReportsPath);
    },
    shouldRenderTestReport() {
      return Boolean(this.mr?.testResultsPath);
    },
    shouldRenderRefactoredTestReport() {
      return window.gon?.features?.refactorMrWidgetTestSummary;
    },
    mergeError() {
      let { mergeError } = this.mr;

      if (mergeError && mergeError.slice(-1) === '.') {
        mergeError = mergeError.slice(0, -1);
      }

      return sprintf(
        s__('mrWidget|%{mergeError}. Try again.'),
        {
          mergeError,
        },
        false,
      );
    },
    shouldShowAccessibilityReport() {
      return Boolean(this.mr?.accessibilityReportPath);
    },
    formattedHumanAccess() {
      return (this.mr.humanAccess || '').toLowerCase();
    },
    hasMergeError() {
      return this.mr.mergeError && this.state !== 'closed';
    },
    hasAlerts() {
      return this.hasMergeError || this.showMergePipelineForkWarning;
    },
    shouldShowSecurityExtension() {
      return window.gon?.features?.refactorSecurityExtension;
    },
    shouldShowCodeQualityExtension() {
      return window.gon?.features?.refactorCodeQualityExtension;
    },
    shouldShowMergeDetails() {
      if (this.mr.state === 'readyToMerge') return true;

      return !this.mr.mergeDetailsCollapsed;
    },
  },
  watch: {
    'mr.machineValue': {
      handler(newValue) {
        this.machineState = newValue;
      },
    },
    state(newVal, oldVal) {
      if (newVal !== oldVal && this.shouldRenderMergedPipeline) {
        // init polling
        this.initPostMergeDeploymentsPolling();
      }
    },
    shouldRenderTerraformPlans(newVal) {
      if (newVal) {
        this.registerTerraformPlans();
      }
    },
    shouldRenderCodeQuality(newVal) {
      if (newVal) {
        this.registerCodeQualityExtension();
      }
    },
    shouldShowAccessibilityReport(newVal) {
      if (newVal) {
        this.registerAccessibilityExtension();
      }
    },
    shouldRenderTestReport(newVal) {
      if (newVal) {
        this.registerTestReportExtension();
      }
    },
  },
  mounted() {
    MRWidgetService.fetchInitialData()
      .then(({ data, headers }) => {
        this.startingPollInterval = Number(headers['POLL-INTERVAL']);
        this.initWidget(data);
      })
      .catch(() =>
        createFlash({
          message: __('Unable to load the merge request widget. Try reloading the page.'),
        }),
      );
  },
  beforeDestroy() {
    eventHub.$off('mr.discussion.updated', this.checkStatus);
    if (this.pollingInterval) {
      this.pollingInterval.destroy();
    }

    if (this.deploymentsInterval) {
      this.deploymentsInterval.destroy();
    }

    if (this.postMergeDeploymentsInterval) {
      this.postMergeDeploymentsInterval.destroy();
    }
  },
  methods: {
    initWidget(data = {}) {
      if (this.mr) {
        this.mr.setData({ ...window.gl.mrWidgetData, ...data });
      } else {
        this.mr = new MRWidgetStore({ ...window.gl.mrWidgetData, ...data });
      }

      this.machineState = this.mr.machineValue;

      if (!this.state) {
        this.state = this.mr.state;
      }

      if (!this.service) {
        this.service = this.createService(this.mr);
      }

      this.setFaviconHelper();
      this.initDeploymentsPolling();

      if (this.shouldRenderMergedPipeline) {
        this.initPostMergeDeploymentsPolling();
      }

      this.initPolling();
      this.bindEventHubListeners();
      eventHub.$on('mr.discussion.updated', this.checkStatus);

      window.addEventListener('resize', () => {
        if (window.innerWidth >= 768) {
          this.mr.toggleMergeDetails(false);
        }
      });
    },
    getServiceEndpoints(store) {
      return {
        mergePath: store.mergePath,
        mergeCheckPath: store.mergeCheckPath,
        cancelAutoMergePath: store.cancelAutoMergePath,
        removeWIPPath: store.removeWIPPath,
        sourceBranchPath: store.sourceBranchPath,
        ciEnvironmentsStatusPath: store.ciEnvironmentsStatusPath,
        mergeRequestBasicPath: store.mergeRequestBasicPath,
        mergeRequestWidgetPath: store.mergeRequestWidgetPath,
        mergeRequestCachedWidgetPath: store.mergeRequestCachedWidgetPath,
        mergeActionsContentPath: store.mergeActionsContentPath,
        rebasePath: store.rebasePath,
        apiApprovalsPath: store.apiApprovalsPath,
        apiApprovePath: store.apiApprovePath,
        apiUnapprovePath: store.apiUnapprovePath,
      };
    },
    createService(store) {
      return new MRWidgetService(this.getServiceEndpoints(store));
    },
    checkStatus(cb, isRebased) {
      if (window.gon?.features?.mergeRequestWidgetGraphql) {
        this.$apollo.queries.state.refetch();
      }

      return this.service
        .checkStatus()
        .then(({ data }) => {
          this.handleNotification(data);
          this.mr.setData(data, isRebased);
          this.setFaviconHelper();

          if (cb) {
            cb.call(null, data);
          }
        })
        .catch(() =>
          createFlash({
            message: __('Something went wrong. Please try again.'),
          }),
        );
    },
    setFaviconHelper() {
      if (this.mr.ciStatusFaviconPath) {
        return setFaviconOverlay(this.mr.ciStatusFaviconPath);
      }
      return Promise.resolve();
    },
    initPolling() {
      if (this.startingPollInterval <= 0) return;

      this.pollingInterval = new SmartInterval({
        callback: this.checkStatus,
        startingInterval: this.startingPollInterval,
        maxInterval: this.startingPollInterval + secondsToMilliseconds(4 * 60),
        hiddenInterval: secondsToMilliseconds(6 * 60),
        incrementByFactorOf: 2,
      });
    },
    initDeploymentsPolling() {
      this.deploymentsInterval = this.deploymentsPoll(this.fetchPreMergeDeployments);
    },
    initPostMergeDeploymentsPolling() {
      this.postMergeDeploymentsInterval = this.deploymentsPoll(this.fetchPostMergeDeployments);
    },
    deploymentsPoll(callback) {
      return new SmartInterval({
        callback,
        startingInterval: 30 * 1000,
        maxInterval: 240 * 1000,
        incrementByFactorOf: 4,
        immediateExecution: true,
      });
    },
    fetchDeployments(target) {
      return this.service.fetchDeployments(target);
    },
    fetchPreMergeDeployments() {
      return this.fetchDeployments()
        .then(({ data }) => {
          if (data.length) {
            this.mr.deployments = data;
          }
        })
        .catch(() => this.throwDeploymentsError());
    },
    fetchPostMergeDeployments() {
      return this.fetchDeployments('merge_commit')
        .then(({ data }) => {
          if (data.length) {
            this.mr.postMergeDeployments = data;
          }
        })
        .catch(() => this.throwDeploymentsError());
    },
    throwDeploymentsError() {
      createFlash({
        message: __(
          'Something went wrong while fetching the environments for this merge request. Please try again.',
        ),
      });
    },
    fetchActionsContent() {
      this.service
        .fetchMergeActionsContent()
        .then((res) => {
          if (res.data) {
            const el = document.createElement('div');
            // eslint-disable-next-line no-unsanitized/property
            el.innerHTML = res.data;
            document.body.appendChild(el);
            document.dispatchEvent(new CustomEvent('merged:UpdateActions'));
            Project.initRefSwitcher();
          }
        })
        .catch(() =>
          createFlash({
            message: __('Something went wrong. Please try again.'),
          }),
        );
    },
    handleNotification(data) {
      if (data.ci_status === this.mr.ciStatus) return;
      if (!data.pipeline) return;

      const { label } = data.pipeline.details.status;
      const title = sprintf(__('Pipeline %{label}'), { label });
      const message = sprintf(__('Pipeline %{label} for "%{dataTitle}"'), {
        dataTitle: data.title,
        label,
      });

      notify.notifyMe(title, message, this.mr.gitlabLogo);
    },
    resumePolling() {
      this.pollingInterval?.resume();
    },
    stopPolling() {
      this.pollingInterval?.stopTimer();
    },
    bindEventHubListeners() {
      eventHub.$on('MRWidgetUpdateRequested', (cb) => {
        this.checkStatus(cb);
      });

      eventHub.$on('MRWidgetRebaseSuccess', (cb) => {
        this.checkStatus(cb, true);
      });

      // `params` should be an Array contains a Boolean, like `[true]`
      // Passing parameter as Boolean didn't work.
      eventHub.$on('SetBranchRemoveFlag', (params) => {
        [this.mr.isRemovingSourceBranch] = params;
      });

      eventHub.$on('FailedToMerge', (mergeError) => {
        this.mr.state = 'failedToMerge';
        this.mr.mergeError = mergeError;
      });

      eventHub.$on('UpdateWidgetData', (data) => {
        this.mr.setData(data);
      });

      eventHub.$on('FetchActionsContent', () => {
        this.fetchActionsContent();
      });

      eventHub.$on('EnablePolling', () => {
        this.resumePolling();
      });

      eventHub.$on('DisablePolling', () => {
        this.stopPolling();
      });

      eventHub.$on('FetchDeployments', () => {
        this.fetchPreMergeDeployments();
        if (this.shouldRenderMergedPipeline) {
          this.fetchPostMergeDeployments();
        }
      });
    },
    dismissSuggestPipelines() {
      this.mr.isDismissedSuggestPipeline = true;
    },
    registerTerraformPlans() {
      if (this.shouldRenderTerraformPlans) {
        registerExtension(terraformExtension);
      }
    },
    registerAccessibilityExtension() {
      if (this.shouldShowAccessibilityReport) {
        registerExtension(accessibilityExtension);
      }
    },
    registerCodeQualityExtension() {
      if (this.shouldRenderCodeQuality && this.shouldShowCodeQualityExtension) {
        registerExtension(codeQualityExtension);
      }
    },
    registerTestReportExtension() {
      if (this.shouldRenderTestReport && this.shouldRenderRefactoredTestReport) {
        registerExtension(testReportExtension);
      }
    },
  },
};
</script>
<template>
  <div v-if="isLoaded" class="mr-state-widget gl-mt-3">
    <header
      v-if="shouldRenderCollaborationStatus"
      class="gl-rounded-base gl-border-solid gl-border-1 gl-border-gray-100 gl-overflow-hidden mr-widget-workflow gl-mt-0!"
    >
      <mr-widget-alert-message v-if="shouldRenderCollaborationStatus" type="info">
        {{ s__('mrWidget|Members who can merge are allowed to add commits.') }}
      </mr-widget-alert-message>
    </header>
    <mr-widget-suggest-pipeline
      v-if="shouldSuggestPipelines"
      data-testid="mr-suggest-pipeline"
      class="mr-widget-workflow"
      :pipeline-path="mr.mergeRequestAddCiConfigPath"
      :pipeline-svg-path="mr.pipelinesEmptySvgPath"
      :human-access="formattedHumanAccess"
      :user-callouts-path="mr.userCalloutsPath"
      :user-callout-feature-id="mr.suggestPipelineFeatureId"
      @dismiss="dismissSuggestPipelines"
    />
    <mr-widget-pipeline-container
      v-if="shouldRenderPipelines"
      class="mr-widget-workflow"
      :mr="mr"
    />
    <mr-widget-approvals
      v-if="shouldRenderApprovals"
      class="mr-widget-workflow"
      :mr="mr"
      :service="service"
    />
    <div class="mr-section-container mr-widget-workflow">
      <div v-if="hasAlerts" class="gl-overflow-hidden mr-widget-alert-container">
        <mr-widget-alert-message
          v-if="hasMergeError"
          type="danger"
          dismissible
          data-testid="merge_error"
        >
          <span v-safe-html="mergeError"></span>
        </mr-widget-alert-message>
        <mr-widget-alert-message
          v-if="showMergePipelineForkWarning"
          type="warning"
          :help-path="mr.mergeRequestPipelinesHelpPath"
        >
          {{
            s__(
              'mrWidget|If the last pipeline ran in the fork project, it may be inaccurate. Before merge, we advise running a pipeline in this project.',
            )
          }}
          <template #link-content>
            {{ __('Learn more') }}
          </template>
        </mr-widget-alert-message>
      </div>

      <extensions-container :mr="mr" />

      <widget-container v-if="mr" :mr="mr" />

      <grouped-codequality-reports-app
        v-if="shouldRenderCodeQuality && !shouldShowCodeQualityExtension"
        :head-blob-path="mr.headBlobPath"
        :base-blob-path="mr.baseBlobPath"
        :codequality-reports-path="mr.codequalityReportsPath"
        :codequality-help-path="mr.codequalityHelpPath"
      />

      <security-reports-app
        v-if="shouldRenderSecurityReport && !shouldShowSecurityExtension"
        :pipeline-id="mr.pipeline.id"
        :project-id="mr.sourceProjectId"
        :security-reports-docs-path="mr.securityReportsDocsPath"
        :target-project-full-path="mr.targetProjectFullPath"
        :mr-iid="mr.iid"
      />

      <grouped-test-reports-app
        v-if="shouldRenderTestReport && !shouldRenderRefactoredTestReport"
        class="js-reports-container"
        :endpoint="mr.testResultsPath"
        :head-blob-path="mr.headBlobPath"
        :pipeline-path="mr.pipeline.path"
      />

      <div class="mr-widget-section" data-qa-selector="mr_widget_content">
        <component :is="componentName" :mr="mr" :service="service" />
        <ready-to-merge
          v-if="mr.commitsCount"
          v-show="shouldShowMergeDetails"
          :mr="mr"
          :service="service"
        />
      </div>
    </div>
    <mr-widget-pipeline-container
      v-if="shouldRenderMergedPipeline"
      class="js-post-merge-pipeline mr-widget-workflow"
      :mr="mr"
      :is-post-merge="true"
    />
  </div>
  <loading v-else />
</template>
