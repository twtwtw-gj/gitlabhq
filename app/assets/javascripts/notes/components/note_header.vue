<script>
import {
  GlIcon,
  GlBadge,
  GlLoadingIcon,
  GlTooltipDirective,
  GlSafeHtmlDirective as SafeHtml,
} from '@gitlab/ui';
import { mapActions } from 'vuex';
import { __, s__ } from '~/locale';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';

export default {
  safeHtmlConfig: { ADD_TAGS: ['gl-emoji'] },
  components: {
    TimeAgoTooltip,
    GitlabTeamMemberBadge: () =>
      import('ee_component/vue_shared/components/user_avatar/badges/gitlab_team_member_badge.vue'),
    GlIcon,
    GlBadge,
    GlLoadingIcon,
  },
  directives: {
    SafeHtml,
    GlTooltip: GlTooltipDirective,
  },
  props: {
    author: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    createdAt: {
      type: String,
      required: false,
      default: null,
    },
    actionText: {
      type: String,
      required: false,
      default: '',
    },
    noteId: {
      type: [String, Number],
      required: false,
      default: null,
    },
    noteableType: {
      type: String,
      required: false,
      default: '',
    },
    includeToggle: {
      type: Boolean,
      required: false,
      default: false,
    },
    expanded: {
      type: Boolean,
      required: false,
      default: true,
    },
    showSpinner: {
      type: Boolean,
      required: false,
      default: true,
    },
    isInternalNote: {
      type: Boolean,
      required: false,
      default: false,
    },
    isSystemNote: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      isUsernameLinkHovered: false,
    };
  },
  computed: {
    toggleChevronIconName() {
      return this.expanded ? 'chevron-up' : 'chevron-down';
    },
    noteTimestampLink() {
      return this.noteId ? `#note_${this.noteId}` : undefined;
    },
    hasAuthor() {
      return this.author && Object.keys(this.author).length;
    },
    authorLinkClasses() {
      return {
        hover: this.isUsernameLinkHovered,
        'text-underline': this.isUsernameLinkHovered,
        'author-name-link': true,
        'js-user-link': true,
      };
    },
    authorName() {
      return this.author.name;
    },
    internalNoteTooltip() {
      return s__('Notes|This internal note will always remain confidential');
    },
  },
  methods: {
    ...mapActions(['setTargetNoteHash']),
    handleToggle() {
      this.$emit('toggleHandler');
    },
    updateTargetNoteHash() {
      if (this.$store) {
        this.setTargetNoteHash(this.noteTimestampLink);
      }
    },
    handleUsernameMouseEnter() {
      this.$refs.authorNameLink.dispatchEvent(new Event('mouseenter'));
      this.isUsernameLinkHovered = true;
    },
    handleUsernameMouseLeave() {
      this.$refs.authorNameLink.dispatchEvent(new Event('mouseleave'));
      this.isUsernameLinkHovered = false;
    },
  },
  i18n: {
    showThread: __('Show thread'),
    hideThread: __('Hide thread'),
  },
};
</script>

<template>
  <div class="note-header-info">
    <div v-if="includeToggle" ref="discussionActions" class="discussion-actions">
      <button
        class="note-action-button discussion-toggle-button js-vue-toggle-button"
        type="button"
        data-testid="thread-toggle"
        @click="handleToggle"
      >
        <gl-icon ref="chevronIcon" :name="toggleChevronIconName" />
        <template v-if="expanded">
          {{ $options.i18n.hideThread }}
        </template>
        <template v-else>
          {{ $options.i18n.showThread }}
        </template>
      </button>
    </div>
    <template v-if="hasAuthor">
      <a
        ref="authorNameLink"
        :href="author.path"
        :class="authorLinkClasses"
        :data-user-id="author.id"
        :data-username="author.username"
      >
        <span class="note-header-author-name gl-font-weight-bold">
          {{ authorName }}
        </span>
      </a>
      <span v-if="!isSystemNote" class="text-nowrap author-username">
        <a
          ref="authorUsernameLink"
          class="author-username-link"
          :href="author.path"
          @mouseenter="handleUsernameMouseEnter"
          @mouseleave="handleUsernameMouseLeave"
          ><span class="note-headline-light">@{{ author.username }}</span>
        </a>
        <slot name="note-header-info"></slot>
        <gitlab-team-member-badge v-if="author && author.is_gitlab_employee" />
      </span>
    </template>
    <span v-else>{{ __('A deleted user') }}</span>
    <span class="note-headline-light note-headline-meta">
      <span class="system-note-message" data-qa-selector="system_note_content">
        <slot></slot>
      </span>
      <template v-if="createdAt">
        <span ref="actionText" class="system-note-separator">
          <template v-if="actionText">{{ actionText }}</template>
        </span>
        <a
          v-if="noteTimestampLink"
          ref="noteTimestampLink"
          :href="noteTimestampLink"
          class="note-timestamp system-note-separator"
          @click="updateTargetNoteHash"
        >
          <time-ago-tooltip :time="createdAt" tooltip-placement="bottom" />
        </a>
        <time-ago-tooltip v-else ref="noteTimestamp" :time="createdAt" tooltip-placement="bottom" />
      </template>
      <gl-badge
        v-if="isInternalNote"
        v-gl-tooltip:tooltipcontainer.bottom
        data-testid="internalNoteIndicator"
        variant="warning"
        size="sm"
        class="gl-mb-3 gl-ml-2"
        :title="internalNoteTooltip"
      >
        {{ __('Internal note') }}
      </gl-badge>
      <slot name="extra-controls"></slot>
      <gl-loading-icon
        v-if="showSpinner"
        ref="spinner"
        size="sm"
        class="editing-spinner"
        :label="__('Comment is being updated')"
      />
    </span>
  </div>
</template>
