<script>
import { GlButton, GlTooltipDirective, GlLoadingIcon } from '@gitlab/ui';
import * as Sentry from '@sentry/browser';
import { normalizeHeaders } from '~/lib/utils/common_utils';
import { sprintf, __ } from '~/locale';
import Poll from '~/lib/utils/poll';
import ActionButtons from '../action_buttons.vue';
import { EXTENSION_ICONS } from '../../constants';
import ContentRow from './widget_content_row.vue';
import DynamicContent from './dynamic_content.vue';
import StatusIcon from './status_icon.vue';

const FETCH_TYPE_COLLAPSED = 'collapsed';
const FETCH_TYPE_EXPANDED = 'expanded';

export default {
  components: {
    ActionButtons,
    StatusIcon,
    GlButton,
    GlLoadingIcon,
    ContentRow,
    DynamicContent,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    /**
     * @param {value.collapsed} Object
     * @param {value.expanded} Object
     */
    value: {
      type: Object,
      required: true,
    },
    loadingText: {
      type: String,
      required: false,
      default: __('Loading'),
    },
    errorText: {
      type: String,
      required: false,
      default: __('Failed to load'),
    },
    fetchCollapsedData: {
      type: Function,
      required: true,
    },
    fetchExpandedData: {
      type: Function,
      required: false,
      default: undefined,
    },
    // If the summary slot is not used, this value will be used as a fallback.
    summary: {
      type: String,
      required: false,
      default: undefined,
    },
    // If the content slot is not used, this value will be used as a fallback.
    content: {
      type: Array,
      required: false,
      default: undefined,
    },
    multiPolling: {
      type: Boolean,
      required: false,
      default: false,
    },
    statusIconName: {
      type: String,
      default: 'neutral',
      required: false,
      validator: (value) => Object.keys(EXTENSION_ICONS).indexOf(value) > -1,
    },
    isCollapsible: {
      type: Boolean,
      required: true,
    },
    actionButtons: {
      type: Array,
      required: false,
      default: () => [],
    },
    widgetName: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      isExpandedForTheFirstTime: true,
      isCollapsed: true,
      isLoading: false,
      isLoadingExpandedContent: false,
      summaryError: null,
      contentError: null,
    };
  },
  computed: {
    collapseButtonLabel() {
      return sprintf(this.isCollapsed ? __('Show details') : __('Hide details'));
    },
    summaryStatusIcon() {
      return this.summaryError ? this.$options.failedStatusIcon : this.statusIconName;
    },
  },
  watch: {
    isLoading(newValue) {
      this.$emit('is-loading', newValue);
    },
  },
  async mounted() {
    this.isLoading = true;

    try {
      await this.fetch(this.fetchCollapsedData, FETCH_TYPE_COLLAPSED);
    } catch {
      this.summaryError = this.errorText;
    }

    this.isLoading = false;
  },
  methods: {
    toggleCollapsed() {
      this.isCollapsed = !this.isCollapsed;

      if (this.isExpandedForTheFirstTime && typeof this.fetchExpandedData === 'function') {
        this.isExpandedForTheFirstTime = false;
        this.fetchExpandedContent();
      }
    },
    async fetchExpandedContent() {
      this.isLoadingExpandedContent = true;
      this.contentError = null;

      try {
        await this.fetch(this.fetchExpandedData, FETCH_TYPE_EXPANDED);
      } catch {
        this.contentError = this.errorText;

        // Reset these values so that we allow refetching
        this.isExpandedForTheFirstTime = true;
        this.isCollapsed = true;
      }

      this.isLoadingExpandedContent = false;
    },
    fetch(handler, dataType) {
      const requests = this.multiPolling ? handler() : [handler];

      const promises = requests.map((request) => {
        return new Promise((resolve, reject) => {
          const poll = new Poll({
            resource: {
              fetchData: () => request(),
            },
            method: 'fetchData',
            successCallback: (response) => {
              const headers = normalizeHeaders(response.headers);

              if (headers['POLL-INTERVAL']) {
                return;
              }

              resolve(response.data);
            },
            errorCallback: (e) => {
              Sentry.captureException(e);
              reject(e);
            },
          });

          poll.makeRequest();
        });
      });

      return Promise.all(promises).then((data) => {
        this.$emit('input', { ...this.value, [dataType]: this.multiPolling ? data : data[0] });
      });
    },
  },
  failedStatusIcon: EXTENSION_ICONS.failed,
};
</script>

<template>
  <section class="media-section" data-testid="widget-extension">
    <div class="gl-p-5 gl-align-items-center gl-display-flex">
      <status-icon
        :level="1"
        :name="widgetName"
        :is-loading="isLoading"
        :icon-name="summaryStatusIcon"
      />
      <div
        class="media-body gl-display-flex gl-flex-direction-row! gl-align-self-center"
        data-testid="widget-extension-top-level"
      >
        <div class="gl-flex-grow-1" data-testid="widget-extension-top-level-summary">
          <span v-if="summaryError">{{ summaryError }}</span>
          <slot v-else name="summary">{{ isLoading ? loadingText : summary }}</slot>
        </div>
        <action-buttons
          v-if="actionButtons.length > 0"
          :widget="widgetName"
          :tertiary-buttons="actionButtons"
        />
        <div
          v-if="isCollapsible"
          class="gl-border-l-1 gl-border-l-solid gl-border-gray-100 gl-ml-3 gl-pl-3 gl-h-6"
        >
          <gl-button
            v-gl-tooltip
            :title="collapseButtonLabel"
            :aria-expanded="`${!isCollapsed}`"
            :aria-label="collapseButtonLabel"
            :icon="isCollapsed ? 'chevron-lg-down' : 'chevron-lg-up'"
            category="tertiary"
            data-testid="toggle-button"
            size="small"
            @click="toggleCollapsed"
          />
        </div>
      </div>
    </div>
    <div
      v-if="!isCollapsed || contentError"
      class="gl-relative gl-bg-gray-10"
      data-testid="widget-extension-collapsed-section"
    >
      <div v-if="isLoadingExpandedContent" class="report-block-container gl-text-center">
        <gl-loading-icon size="sm" inline /> {{ loadingText }}
      </div>
      <div v-else class="gl-px-5 gl-display-flex">
        <content-row
          v-if="contentError"
          :level="2"
          :status-icon-name="$options.failedStatusIcon"
          :widget-name="widgetName"
        >
          <template #body>
            {{ contentError }}
          </template>
        </content-row>
        <slot v-else name="content">
          <div class="gl-w-full">
            <dynamic-content
              v-for="(data, index) in content"
              :key="data.id || index"
              :data="data"
              :widget-name="widgetName"
            />
          </div>
        </slot>
      </div>
    </div>
  </section>
</template>
