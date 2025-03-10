<script>
/**
 * Renders each stage of the pipeline mini graph.
 *
 * Given the provided endpoint will make a request to
 * fetch the dropdown data when the stage is clicked.
 *
 * Request is made inside this component to make it reusable between:
 * 1. Pipelines main table
 * 2. Pipelines table in commit and Merge request views
 * 3. Merge request widget
 * 4. Commit widget
 */

import { GlDropdown, GlLoadingIcon, GlTooltipDirective } from '@gitlab/ui';
import CiIcon from '~/vue_shared/components/ci_icon.vue';
import { createAlert } from '~/flash';
import axios from '~/lib/utils/axios_utils';
import { __, sprintf } from '~/locale';
import eventHub from '../../event_hub';
import JobItem from './job_item.vue';

export default {
  i18n: {
    stage: __('Stage:'),
    loadingText: __('Loading, please wait.'),
  },
  dropdownPopperOpts: {
    placement: 'bottom',
  },
  components: {
    CiIcon,
    GlLoadingIcon,
    GlDropdown,
    JobItem,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    stage: {
      type: Object,
      required: true,
    },
    updateDropdown: {
      type: Boolean,
      required: false,
      default: false,
    },
    isMergeTrain: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      isDropdownOpen: false,
      isLoading: false,
      dropdownContent: [],
      stageName: '',
    };
  },
  watch: {
    updateDropdown() {
      if (this.updateDropdown && this.isDropdownOpen && !this.isLoading) {
        this.fetchJobs();
      }
    },
  },
  methods: {
    onHideDropdown() {
      this.isDropdownOpen = false;
    },
    onShowDropdown() {
      eventHub.$emit('clickedDropdown');
      this.isDropdownOpen = true;
      this.isLoading = true;
      this.fetchJobs();

      // used for tracking and is separate from event hub
      // to avoid complexity with mixin
      this.$emit('miniGraphStageClick');
    },
    fetchJobs() {
      axios
        .get(this.stage.dropdown_path)
        .then(({ data }) => {
          this.dropdownContent = data.latest_statuses;
          this.stageName = data.name;
          this.isLoading = false;
        })
        .catch(() => {
          this.$refs.dropdown.hide();
          this.isLoading = false;

          createAlert({
            message: __('Something went wrong on our end.'),
          });
        });
    },
    pipelineActionRequestComplete() {
      // close the dropdown in MR widget
      this.$refs.dropdown.hide();

      // warn the pipelines table to update
      this.$emit('pipelineActionRequestComplete');
    },
    stageAriaLabel(title) {
      return sprintf(__('View Stage: %{title}'), { title });
    },
  },
};
</script>

<template>
  <gl-dropdown
    ref="dropdown"
    v-gl-tooltip.hover.ds0
    v-gl-tooltip="stage.title"
    data-testid="mini-pipeline-graph-dropdown"
    variant="link"
    :aria-label="stageAriaLabel(stage.title)"
    :lazy="true"
    :popper-opts="$options.dropdownPopperOpts"
    :toggle-class="['gl-rounded-full!']"
    menu-class="mini-pipeline-graph-dropdown-menu"
    @hide="onHideDropdown"
    @show="onShowDropdown"
  >
    <template #button-content>
      <ci-icon
        is-borderless
        is-interactive
        css-classes="gl-rounded-full"
        :is-active="isDropdownOpen"
        :size="24"
        :status="stage.status"
        class="gl-align-items-center gl-border gl-display-inline-flex gl-z-index-1"
      />
    </template>
    <div
      v-if="isLoading"
      class="gl-display-flex gl-justify-content-center gl-p-2"
      data-testid="pipeline-stage-loading-state"
    >
      <gl-loading-icon size="sm" class="gl-mr-3" />
      <p class="gl-mb-0">{{ $options.i18n.loadingText }}</p>
    </div>
    <ul
      v-else
      class="js-builds-dropdown-list scrollable-menu"
      data-testid="mini-pipeline-graph-dropdown-menu-list"
    >
      <div
        class="gl-align-items-center gl-border-b gl-display-flex gl-font-weight-bold gl-justify-content-center gl-pb-3"
      >
        <span class="gl-mr-1">{{ $options.i18n.stage }}</span>
        <span data-testid="pipeline-stage-dropdown-menu-title">{{ stageName }}</span>
      </div>
      <li v-for="job in dropdownContent" :key="job.id">
        <job-item
          :dropdown-length="dropdownContent.length"
          :job="job"
          css-class-job-name="mini-pipeline-graph-dropdown-item"
          @pipelineActionRequestComplete="pipelineActionRequestComplete"
        />
      </li>
      <template v-if="isMergeTrain">
        <li class="gl-new-dropdown-divider" role="presentation">
          <hr role="separator" aria-orientation="horizontal" class="dropdown-divider" />
        </li>
        <li>
          <div
            class="gl-display-flex gl-align-items-center"
            data-testid="warning-message-merge-trains"
          >
            <div class="menu-item gl-font-sm gl-text-gray-300!">
              {{ s__('Pipeline|Merge train pipeline jobs can not be retried') }}
            </div>
          </div>
        </li>
      </template>
    </ul>
  </gl-dropdown>
</template>
