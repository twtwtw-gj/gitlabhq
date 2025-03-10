<script>
import {
  GlLink,
  GlDropdown,
  GlDropdownItem,
  GlDropdownText,
  GlSearchBoxByType,
  GlDropdownDivider,
  GlLoadingIcon,
  GlIcon,
  GlTooltipDirective,
  GlPopover,
  GlButton,
} from '@gitlab/ui';
import { kebabCase, snakeCase } from 'lodash';
import { createAlert } from '~/flash';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { IssuableType } from '~/issues/constants';
import { timeFor } from '~/lib/utils/datetime_utility';
import { __ } from '~/locale';
import SidebarEditableItem from '~/sidebar/components/sidebar_editable_item.vue';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import {
  dropdowni18nText,
  Tracking,
  IssuableAttributeState,
  IssuableAttributeType,
  issuableAttributesQueries,
  noAttributeId,
  defaultEpicSort,
  epicIidPattern,
} from 'ee_else_ce/sidebar/constants';

export default {
  noAttributeId,
  i18n: {
    expired: __('(expired)'),
    none: __('None'),
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    SidebarEditableItem,
    GlLink,
    GlDropdown,
    GlDropdownItem,
    GlDropdownText,
    GlDropdownDivider,
    GlSearchBoxByType,
    GlIcon,
    GlLoadingIcon,
    GlPopover,
    GlButton,
  },
  mixins: [glFeatureFlagMixin()],
  inject: {
    isClassicSidebar: {
      default: false,
    },
    issuableAttributesQueries: {
      default: issuableAttributesQueries,
    },
    issuableAttributesState: {
      default: IssuableAttributeState,
    },
    widgetTitleText: {
      default: {
        [IssuableAttributeType.Milestone]: __('Milestone'),
        expired: __('(expired)'),
        none: __('None'),
      },
    },
  },

  props: {
    issuableAttribute: {
      type: String,
      required: true,
    },
    workspacePath: {
      required: true,
      type: String,
    },
    iid: {
      required: true,
      type: String,
    },
    attrWorkspacePath: {
      required: true,
      type: String,
    },
    issuableType: {
      type: String,
      required: true,
      validator(value) {
        return [IssuableType.Issue, IssuableType.MergeRequest].includes(value);
      },
    },
    icon: {
      type: String,
      required: false,
      default: undefined,
    },
  },
  apollo: {
    currentAttribute: {
      query() {
        const { current } = this.issuableAttributeQuery;
        const { query } = current[this.issuableType];

        return query;
      },
      variables() {
        return {
          fullPath: this.workspacePath,
          iid: this.iid,
        };
      },
      update(data) {
        if (this.glFeatures?.epicWidgetEditConfirmation && this.isEpic) {
          this.hasCurrentAttribute = data?.workspace?.issuable.hasEpic;
        }

        return data?.workspace?.issuable.attribute;
      },
      error(error) {
        createAlert({
          message: this.i18n.currentFetchError,
          captureError: true,
          error,
        });
      },
    },
    attributesList: {
      query() {
        const { list } = this.issuableAttributeQuery;
        const { query } = list[this.issuableType];

        return query;
      },
      skip() {
        if (this.isEpic && this.searchTerm.startsWith('&') && this.searchTerm.length < 2) {
          return true;
        }

        return !this.editing;
      },
      debounce: 250,
      variables() {
        if (!this.isEpic) {
          return {
            fullPath: this.attrWorkspacePath,
            title: this.searchTerm,
            state: this.issuableAttributesState[this.issuableAttribute],
          };
        }

        const variables = {
          fullPath: this.attrWorkspacePath,
          state: this.issuableAttributesState[this.issuableAttribute],
          sort: defaultEpicSort,
        };

        if (epicIidPattern.test(this.searchTerm)) {
          const matches = this.searchTerm.match(epicIidPattern);
          variables.iidStartsWith = matches.groups.iid;
        } else if (this.searchTerm !== '') {
          variables.in = 'TITLE';
          variables.title = this.searchTerm;
        }

        return variables;
      },
      update(data) {
        if (data?.workspace) {
          return data?.workspace?.attributes.nodes;
        }
        return [];
      },
      error(error) {
        createAlert({ message: this.i18n.listFetchError, captureError: true, error });
      },
    },
  },
  data() {
    return {
      searchTerm: '',
      editing: false,
      updating: false,
      selectedTitle: null,
      currentAttribute: null,
      hasCurrentAttribute: false,
      editConfirmation: false,
      attributesList: [],
      tracking: {
        event: Tracking.editEvent,
        label: Tracking.rightSidebarLabel,
        property: this.issuableAttribute,
      },
    };
  },
  computed: {
    issuableAttributeQuery() {
      return this.issuableAttributesQueries[this.issuableAttribute];
    },
    attributeTitle() {
      return this.currentAttribute?.title || this.i18n.noAttribute;
    },
    attributeUrl() {
      return this.currentAttribute?.webUrl;
    },
    dropdownText() {
      return this.currentAttribute ? this.currentAttribute?.title : this.attributeTypeTitle;
    },
    loading() {
      return this.$apollo.queries.currentAttribute.loading;
    },
    emptyPropsList() {
      return this.attributesList.length === 0;
    },
    attributeTypeTitle() {
      return this.widgetTitleText[this.issuableAttribute];
    },
    attributeTypeIcon() {
      return this.icon || this.issuableAttribute;
    },
    tooltipText() {
      return timeFor(this.currentAttribute?.dueDate);
    },
    i18n() {
      return dropdowni18nText(this.issuableAttribute, this.issuableType);
    },
    isEpic() {
      // MV to EE https://gitlab.com/gitlab-org/gitlab/-/issues/345311
      return this.issuableAttribute === IssuableType.Epic;
    },
    formatIssuableAttribute() {
      return {
        kebab: kebabCase(this.issuableAttribute),
        snake: snakeCase(this.issuableAttribute),
      };
    },
    shouldShowConfirmationPopover() {
      if (!this.glFeatures?.epicWidgetEditConfirmation) {
        return false;
      }

      return this.isEpic && this.currentAttribute === null && this.hasCurrentAttribute
        ? !this.editConfirmation
        : false;
    },
  },
  methods: {
    updateAttribute(attributeId) {
      if (this.currentAttribute === null && attributeId === null) return;
      if (attributeId === this.currentAttribute?.id) return;

      this.updating = true;

      const selectedAttribute =
        Boolean(attributeId) && this.attributesList.find((p) => p.id === attributeId);
      this.selectedTitle = selectedAttribute ? selectedAttribute.title : this.widgetTitleText.none;

      const { current } = this.issuableAttributeQuery;
      const { mutation } = current[this.issuableType];

      this.$apollo
        .mutate({
          mutation,
          variables: {
            fullPath: this.workspacePath,
            attributeId:
              this.issuableAttribute === IssuableAttributeType.Milestone &&
              this.issuableType === IssuableType.Issue
                ? getIdFromGraphQLId(attributeId)
                : attributeId,
            iid: this.iid,
          },
        })
        .then(({ data }) => {
          if (data.issuableSetAttribute?.errors?.length) {
            createAlert({
              message: data.issuableSetAttribute.errors[0],
              captureError: true,
              error: data.issuableSetAttribute.errors[0],
            });
          } else {
            this.$emit('attribute-updated', data);
          }
        })
        .catch((error) => {
          createAlert({ message: this.i18n.updateError, captureError: true, error });
        })
        .finally(() => {
          this.updating = false;
          this.searchTerm = '';
          this.selectedTitle = null;
        });
    },
    isAttributeChecked(attributeId = undefined) {
      return (
        attributeId === this.currentAttribute?.id || (!this.currentAttribute?.id && !attributeId)
      );
    },
    isAttributeOverdue(attribute) {
      return this.issuableAttribute === IssuableAttributeType.Milestone
        ? attribute?.expired
        : false;
    },
    showDropdown() {
      this.$refs.newDropdown.show();
    },
    handleOpen() {
      this.editing = true;
      this.showDropdown();
    },
    handleClose() {
      this.editing = false;
    },
    setFocus() {
      this.$refs.search.focusInput();
    },
    handlePopoverClose() {
      this.$refs.popover.$emit('close');
    },
    handlePopoverConfirm(cb) {
      this.editConfirmation = true;
      this.handlePopoverClose();
      setTimeout(cb, 0);
    },
    handleEditConfirmation() {
      this.$refs.popover.$emit('open');
    },
  },
};
</script>

<template>
  <sidebar-editable-item
    ref="editable"
    :title="attributeTypeTitle"
    :data-testid="`${formatIssuableAttribute.kebab}-edit`"
    :button-id="`${formatIssuableAttribute.kebab}-edit`"
    :tracking="tracking"
    :should-show-confirmation-popover="shouldShowConfirmationPopover"
    :loading="updating || loading"
    @open="handleOpen"
    @close="handleClose"
    @edit-confirm="handleEditConfirmation"
  >
    <template #collapsed>
      <slot name="value-collapsed" :current-attribute="currentAttribute">
        <div
          v-if="isClassicSidebar"
          v-gl-tooltip.left.viewport
          :title="attributeTypeTitle"
          class="sidebar-collapsed-icon"
        >
          <gl-icon :aria-label="attributeTypeTitle" :name="attributeTypeIcon" />
          <span class="collapse-truncated-title gl-pt-2 gl-px-3 gl-font-sm">
            {{ attributeTitle }}
          </span>
        </div>
      </slot>
      <div
        :data-testid="`select-${formatIssuableAttribute.kebab}`"
        :class="isClassicSidebar ? 'hide-collapsed' : 'gl-mt-3'"
      >
        <span v-if="updating">{{ selectedTitle }}</span>
        <template v-else-if="!currentAttribute && hasCurrentAttribute">
          <gl-icon name="warning" class="gl-text-orange-500" />
          <span class="gl-text-gray-500">{{ i18n.noPermissionToView }}</span>
        </template>
        <span v-else-if="!currentAttribute" class="gl-text-gray-500">
          {{ $options.i18n.none }}
        </span>
        <slot
          v-else
          name="value"
          :attribute-title="attributeTitle"
          :attribute-url="attributeUrl"
          :current-attribute="currentAttribute"
        >
          <gl-link
            v-gl-tooltip="tooltipText"
            class="gl-reset-color gl-hover-text-blue-800"
            :href="attributeUrl"
            :data-qa-selector="`${formatIssuableAttribute.snake}_link`"
          >
            {{ attributeTitle }}
            <span v-if="isAttributeOverdue(currentAttribute)">{{ $options.i18n.expired }}</span>
          </gl-link>
        </slot>
      </div>
    </template>
    <template v-if="shouldShowConfirmationPopover" #default="{ toggle }">
      <gl-popover
        ref="popover"
        :target="`${formatIssuableAttribute.kebab}-edit`"
        placement="bottomleft"
        boundary="viewport"
        triggers="click"
      >
        <div class="gl-mb-4 gl-font-base">
          {{ i18n.editConfirmation }}
        </div>
        <div class="gl-display-flex gl-align-items-center">
          <gl-button
            size="small"
            variant="confirm"
            category="primary"
            data-testid="confirm-edit-cta"
            @click.prevent="() => handlePopoverConfirm(toggle)"
            >{{ i18n.editConfirmationCta }}</gl-button
          >
          <gl-button
            class="gl-ml-auto"
            size="small"
            name="cancel"
            variant="default"
            category="primary"
            data-testid="confirm-edit-cancel"
            @click.prevent="handlePopoverClose"
            >{{ i18n.editConfirmationCancel }}</gl-button
          >
        </div>
      </gl-popover>
    </template>
    <template v-else #default>
      <gl-dropdown
        ref="newDropdown"
        lazy
        :header-text="i18n.assignAttribute"
        :text="dropdownText"
        :loading="loading"
        class="gl-w-full"
        toggle-class="gl-max-w-100"
        block
        @shown="setFocus"
      >
        <gl-search-box-by-type ref="search" v-model="searchTerm" />
        <gl-dropdown-item
          :data-testid="`no-${formatIssuableAttribute.kebab}-item`"
          is-check-item
          :is-checked="isAttributeChecked($options.noAttributeId)"
          @click="updateAttribute($options.noAttributeId)"
        >
          {{ i18n.noAttribute }}
        </gl-dropdown-item>
        <gl-dropdown-divider />
        <gl-loading-icon
          v-if="$apollo.queries.attributesList.loading"
          size="sm"
          class="gl-py-4"
          data-testid="loading-icon-dropdown"
        />
        <template v-else>
          <gl-dropdown-text v-if="emptyPropsList">
            {{ i18n.noAttributesFound }}
          </gl-dropdown-text>
          <slot
            v-else
            name="list"
            :attributes-list="attributesList"
            :is-attribute-checked="isAttributeChecked"
            :update-attribute="updateAttribute"
          >
            <gl-dropdown-item
              v-for="attrItem in attributesList"
              :key="attrItem.id"
              is-check-item
              :is-checked="isAttributeChecked(attrItem.id)"
              :data-testid="`${formatIssuableAttribute.kebab}-items`"
              @click="updateAttribute(attrItem.id)"
            >
              {{ attrItem.title }}
              <span v-if="isAttributeOverdue(attrItem)">{{ $options.i18n.expired }}</span>
            </gl-dropdown-item>
          </slot>
        </template>
      </gl-dropdown>
    </template>
  </sidebar-editable-item>
</template>
