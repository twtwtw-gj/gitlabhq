<script>
import {
  GlAlert,
  GlSkeletonLoader,
  GlLoadingIcon,
  GlIcon,
  GlBadge,
  GlButton,
  GlTooltipDirective,
  GlEmptyState,
} from '@gitlab/ui';
import noAccessSvg from '@gitlab/svgs/dist/illustrations/analytics/no-access.svg';
import { s__ } from '~/locale';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import WorkItemTypeIcon from '~/work_items/components/work_item_type_icon.vue';
import {
  i18n,
  WIDGET_TYPE_ASSIGNEES,
  WIDGET_TYPE_LABELS,
  WIDGET_TYPE_DESCRIPTION,
  WIDGET_TYPE_START_AND_DUE_DATE,
  WIDGET_TYPE_WEIGHT,
  WIDGET_TYPE_HIERARCHY,
  WORK_ITEM_VIEWED_STORAGE_KEY,
} from '../constants';

import workItemQuery from '../graphql/work_item.query.graphql';
import workItemDatesSubscription from '../graphql/work_item_dates.subscription.graphql';
import workItemTitleSubscription from '../graphql/work_item_title.subscription.graphql';
import workItemAssigneesSubscription from '../graphql/work_item_assignees.subscription.graphql';
import updateWorkItemMutation from '../graphql/update_work_item.mutation.graphql';
import updateWorkItemTaskMutation from '../graphql/update_work_item_task.mutation.graphql';

import WorkItemActions from './work_item_actions.vue';
import WorkItemState from './work_item_state.vue';
import WorkItemTitle from './work_item_title.vue';
import WorkItemDescription from './work_item_description.vue';
import WorkItemDueDate from './work_item_due_date.vue';
import WorkItemAssignees from './work_item_assignees.vue';
import WorkItemLabels from './work_item_labels.vue';
import WorkItemInformation from './work_item_information.vue';

export default {
  i18n,
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    GlAlert,
    GlBadge,
    GlButton,
    GlLoadingIcon,
    GlSkeletonLoader,
    GlIcon,
    GlEmptyState,
    WorkItemAssignees,
    WorkItemActions,
    WorkItemDescription,
    WorkItemDueDate,
    WorkItemLabels,
    WorkItemTitle,
    WorkItemState,
    WorkItemWeight: () => import('ee_component/work_items/components/work_item_weight.vue'),
    WorkItemInformation,
    LocalStorageSync,
    WorkItemTypeIcon,
  },
  mixins: [glFeatureFlagMixin()],
  props: {
    isModal: {
      type: Boolean,
      required: false,
      default: false,
    },
    workItemId: {
      type: String,
      required: false,
      default: null,
    },
    workItemParentId: {
      type: String,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      error: undefined,
      updateError: undefined,
      workItem: {},
      showInfoBanner: true,
      updateInProgress: false,
    };
  },
  apollo: {
    workItem: {
      query: workItemQuery,
      variables() {
        return {
          id: this.workItemId,
        };
      },
      skip() {
        return !this.workItemId;
      },
      error() {
        this.error = this.$options.i18n.fetchError;
        document.title = s__('404|Not found');
      },
      result() {
        if (!this.isModal && this.workItem.project) {
          const path = this.workItem.project?.fullPath
            ? ` · ${this.workItem.project.fullPath}`
            : '';

          document.title = `${this.workItem.title} · ${this.workItem?.workItemType?.name}${path}`;
        }
      },
      subscribeToMore: [
        {
          document: workItemTitleSubscription,
          variables() {
            return {
              issuableId: this.workItemId,
            };
          },
        },
        {
          document: workItemDatesSubscription,
          variables() {
            return {
              issuableId: this.workItemId,
            };
          },
          skip() {
            return !this.workItemDueDate;
          },
        },
        {
          document: workItemAssigneesSubscription,
          variables() {
            return {
              issuableId: this.workItemId,
            };
          },
          skip() {
            return !this.workItemAssignees;
          },
        },
      ],
    },
  },
  computed: {
    workItemLoading() {
      return this.$apollo.queries.workItem.loading;
    },
    workItemType() {
      return this.workItem.workItemType?.name;
    },
    canUpdate() {
      return this.workItem?.userPermissions?.updateWorkItem;
    },
    canDelete() {
      return this.workItem?.userPermissions?.deleteWorkItem;
    },
    fullPath() {
      return this.workItem?.project.fullPath;
    },
    workItemsMvc2Enabled() {
      return this.glFeatures.workItemsMvc2;
    },
    hasDescriptionWidget() {
      return this.workItem?.widgets?.find((widget) => widget.type === WIDGET_TYPE_DESCRIPTION);
    },
    workItemAssignees() {
      return this.workItem?.widgets?.find((widget) => widget.type === WIDGET_TYPE_ASSIGNEES);
    },
    workItemLabels() {
      return this.workItem?.mockWidgets?.find((widget) => widget.type === WIDGET_TYPE_LABELS);
    },
    workItemDueDate() {
      return this.workItem?.widgets?.find(
        (widget) => widget.type === WIDGET_TYPE_START_AND_DUE_DATE,
      );
    },
    workItemWeight() {
      return this.workItem?.widgets?.find((widget) => widget.type === WIDGET_TYPE_WEIGHT);
    },
    workItemHierarchy() {
      return this.workItem?.widgets?.find((widget) => widget.type === WIDGET_TYPE_HIERARCHY);
    },
    parentWorkItem() {
      return this.workItemHierarchy?.parent;
    },
    parentWorkItemConfidentiality() {
      return this.parentWorkItem?.confidential;
    },
    parentUrl() {
      return `../../issues/${this.parentWorkItem?.iid}`;
    },
    workItemIconName() {
      return this.workItem?.workItemType?.iconName;
    },
    noAccessSvgPath() {
      return `data:image/svg+xml;utf8,${encodeURIComponent(noAccessSvg)}`;
    },
  },
  beforeDestroy() {
    /** make sure that if the user has not even dismissed the alert ,
     * should no be able to see the information next time and update the local storage * */
    this.dismissBanner();
  },
  methods: {
    dismissBanner() {
      this.showInfoBanner = false;
    },
    toggleConfidentiality(confidentialStatus) {
      this.updateInProgress = true;
      let updateMutation = updateWorkItemMutation;
      let inputVariables = {
        id: this.workItemId,
        confidential: confidentialStatus,
      };

      if (this.parentWorkItem) {
        updateMutation = updateWorkItemTaskMutation;
        inputVariables = {
          id: this.parentWorkItem.id,
          taskData: {
            id: this.workItemId,
            confidential: confidentialStatus,
          },
        };
      }

      this.$apollo
        .mutate({
          mutation: updateMutation,
          variables: {
            input: inputVariables,
          },
        })
        .then(
          ({
            data: {
              workItemUpdate: { errors, workItem, task },
            },
          }) => {
            if (errors?.length) {
              throw new Error(errors[0]);
            }

            this.$emit('workItemUpdated', {
              confidential: workItem?.confidential || task?.confidential,
            });
          },
        )
        .catch((error) => {
          this.updateError = error.message;
        })
        .finally(() => {
          this.updateInProgress = false;
        });
    },
  },
  WORK_ITEM_VIEWED_STORAGE_KEY,
};
</script>

<template>
  <section class="gl-pt-5">
    <gl-alert
      v-if="updateError"
      class="gl-mb-3"
      variant="danger"
      @dismiss="updateError = undefined"
    >
      {{ updateError }}
    </gl-alert>

    <div v-if="workItemLoading" class="gl-max-w-26 gl-py-5">
      <gl-skeleton-loader :height="65" :width="240">
        <rect width="240" height="20" x="5" y="0" rx="4" />
        <rect width="100" height="20" x="5" y="45" rx="4" />
      </gl-skeleton-loader>
    </div>
    <template v-else>
      <div class="gl-display-flex gl-align-items-center" data-testid="work-item-body">
        <ul
          v-if="parentWorkItem"
          class="list-unstyled gl-display-flex gl-mr-auto gl-max-w-26 gl-md-max-w-50p gl-min-w-0 gl-mb-0"
          data-testid="work-item-parent"
        >
          <li class="gl-ml-n4 gl-display-flex gl-align-items-center gl-overflow-hidden">
            <gl-button
              v-gl-tooltip.hover
              class="gl-text-truncate gl-max-w-full"
              icon="issues"
              category="tertiary"
              :href="parentUrl"
              :title="parentWorkItem.title"
              >{{ parentWorkItem.title }}</gl-button
            >
            <gl-icon name="chevron-right" :size="16" class="gl-flex-shrink-0" />
          </li>
          <li
            class="gl-px-4 gl-py-3 gl-line-height-0 gl-display-flex gl-align-items-center gl-overflow-hidden gl-flex-shrink-0"
          >
            <work-item-type-icon
              :work-item-icon-name="workItemIconName"
              :work-item-type="workItemType && workItemType.toUpperCase()"
            />
            {{ workItemType }}
          </li>
        </ul>
        <work-item-type-icon
          v-else-if="!error"
          :work-item-icon-name="workItemIconName"
          :work-item-type="workItemType && workItemType.toUpperCase()"
          show-text
          class="gl-font-weight-bold gl-text-secondary gl-mr-auto"
          data-testid="work-item-type"
        />
        <gl-loading-icon v-if="updateInProgress" :inline="true" class="gl-mr-3" />
        <gl-badge
          v-if="workItem.confidential"
          v-gl-tooltip.bottom
          :title="$options.i18n.confidentialTooltip"
          variant="warning"
          icon="eye-slash"
          class="gl-mr-3 gl-cursor-help"
          >{{ __('Confidential') }}</gl-badge
        >
        <work-item-actions
          v-if="canUpdate || canDelete"
          :work-item-id="workItem.id"
          :work-item-type="workItemType"
          :can-delete="canDelete"
          :can-update="canUpdate"
          :is-confidential="workItem.confidential"
          :is-parent-confidential="parentWorkItemConfidentiality"
          @deleteWorkItem="$emit('deleteWorkItem', workItemType)"
          @toggleWorkItemConfidentiality="toggleConfidentiality"
          @error="updateError = $event"
        />
        <gl-button
          v-if="isModal"
          category="tertiary"
          data-testid="work-item-close"
          icon="close"
          :aria-label="__('Close')"
          @click="$emit('close')"
        />
      </div>
      <local-storage-sync
        v-model="showInfoBanner"
        :storage-key="$options.WORK_ITEM_VIEWED_STORAGE_KEY"
      >
        <work-item-information
          v-if="showInfoBanner && !error"
          :show-info-banner="showInfoBanner"
          @work-item-banner-dismissed="dismissBanner"
        />
      </local-storage-sync>
      <work-item-title
        v-if="workItem.title"
        :work-item-id="workItem.id"
        :work-item-title="workItem.title"
        :work-item-type="workItemType"
        :work-item-parent-id="workItemParentId"
        :can-update="canUpdate"
        @error="updateError = $event"
      />
      <work-item-state
        :work-item="workItem"
        :work-item-parent-id="workItemParentId"
        :can-update="canUpdate"
        @error="updateError = $event"
      />
      <work-item-assignees
        v-if="workItemAssignees"
        :can-update="canUpdate"
        :work-item-id="workItem.id"
        :assignees="workItemAssignees.assignees.nodes"
        :allows-multiple-assignees="workItemAssignees.allowsMultipleAssignees"
        :work-item-type="workItemType"
        :can-invite-members="workItemAssignees.canInviteMembers"
        :full-path="fullPath"
        @error="updateError = $event"
      />
      <template v-if="workItemsMvc2Enabled">
        <work-item-labels
          v-if="workItemLabels"
          :work-item-id="workItem.id"
          :can-update="canUpdate"
          :full-path="fullPath"
          @error="updateError = $event"
        />
        <work-item-due-date
          v-if="workItemDueDate"
          :can-update="canUpdate"
          :due-date="workItemDueDate.dueDate"
          :start-date="workItemDueDate.startDate"
          :work-item-id="workItem.id"
          :work-item-type="workItemType"
          @error="updateError = $event"
        />
      </template>
      <work-item-weight
        v-if="workItemWeight"
        class="gl-mb-5"
        :can-update="canUpdate"
        :weight="workItemWeight.weight"
        :work-item-id="workItem.id"
        :work-item-type="workItemType"
        @error="updateError = $event"
      />
      <work-item-description
        v-if="hasDescriptionWidget"
        :work-item-id="workItem.id"
        :full-path="fullPath"
        class="gl-pt-5"
        @error="updateError = $event"
      />
      <gl-empty-state
        v-if="error"
        :title="$options.i18n.fetchErrorTitle"
        :description="error"
        :svg-path="noAccessSvgPath"
      />
    </template>
  </section>
</template>
