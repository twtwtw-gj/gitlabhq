<script>
import { GlButtonGroup, GlButton, GlTooltipDirective, GlSafeHtmlDirective } from '@gitlab/ui';

import CommitPipelineStatus from '~/projects/tree/components/commit_pipeline_status_component.vue';
import ModalCopyButton from '~/vue_shared/components/modal_copy_button.vue';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import UserAvatarLink from '~/vue_shared/components/user_avatar/user_avatar_link.vue';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';

/**
 * CommitItem
 *
 * -----------------------------------------------------------------
 * WARNING: Please keep changes up-to-date with the following files:
 * - `views/projects/commits/_commit.html.haml`
 * -----------------------------------------------------------------
 *
 * This Component was cloned from a HAML view. For the time being they
 * coexist, but there is an issue to remove the duplication.
 * https://gitlab.com/gitlab-org/gitlab-foss/issues/51613
 *
 */

export default {
  components: {
    UserAvatarLink,
    ModalCopyButton,
    TimeAgoTooltip,
    CommitPipelineStatus,
    GlButtonGroup,
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
    SafeHtml: GlSafeHtmlDirective,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    isSelectable: {
      type: Boolean,
      required: false,
      default: false,
    },
    commit: {
      type: Object,
      required: true,
    },
    checked: {
      type: Boolean,
      required: false,
      default: false,
    },
    collapsible: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  computed: {
    author() {
      return this.commit.author || {};
    },
    authorName() {
      return this.author.name || this.commit.author_name;
    },
    authorClass() {
      return this.author.name ? 'js-user-link' : '';
    },
    authorId() {
      return this.author.id ? this.author.id : '';
    },
    authorUrl() {
      return this.author.web_url || `mailto:${this.commit.author_email}`;
    },
    authorAvatar() {
      return this.author.avatar_url || this.commit.author_gravatar_url;
    },
    commitDescription() {
      // Strip the newline at the beginning
      return this.commit.description_html.replace(/^&#x000A;/, '');
    },
  },
  safeHtmlConfig: {
    ADD_TAGS: ['gl-emoji'],
  },
};
</script>

<template>
  <li :class="{ 'js-toggle-container': collapsible }" class="commit">
    <div
      class="d-block d-sm-flex flex-row-reverse justify-content-between align-items-start flex-lg-row-reverse"
    >
      <div
        class="commit-actions flex-row d-none d-sm-flex align-items-start flex-wrap justify-content-end"
      >
        <div
          v-if="commit.signature_html"
          v-html="commit.signature_html /* eslint-disable-line vue/no-v-html */"
        ></div>
        <commit-pipeline-status
          v-if="commit.pipeline_status_path"
          :endpoint="commit.pipeline_status_path"
          class="d-inline-flex mb-2"
        />
        <gl-button-group class="gl-ml-4 gl-mb-4" data-testid="commit-sha-group">
          <gl-button label class="gl-font-monospace" data-testid="commit-sha-short-id">{{
            commit.short_id
          }}</gl-button>
          <modal-copy-button
            :text="commit.id"
            :title="__('Copy commit SHA')"
            class="input-group-text"
          />
        </gl-button-group>
      </div>
      <div>
        <div class="d-flex float-left align-items-center align-self-start">
          <input
            v-if="isSelectable"
            class="gl-mr-3"
            type="checkbox"
            :checked="checked"
            @change="$emit('handleCheckboxChange', $event.target.checked)"
          />
          <user-avatar-link
            :link-href="authorUrl"
            :img-src="authorAvatar"
            :img-alt="authorName"
            :img-size="32"
            class="avatar-cell d-none d-sm-block gl-my-2 gl-mr-4"
          />
        </div>
        <div
          class="commit-detail flex-list gl-display-flex gl-justify-content-space-between gl-align-items-flex-start gl-flex-grow-1 gl-min-w-0"
        >
          <div class="commit-content" data-qa-selector="commit_content">
            <a
              v-safe-html:[$options.safeHtmlConfig]="commit.title_html"
              :href="commit.commit_url"
              class="commit-row-message item-title"
            ></a>

            <span class="commit-row-message d-block d-sm-none">&middot; {{ commit.short_id }}</span>

            <gl-button
              v-if="commit.description_html && collapsible"
              v-gl-tooltip
              class="js-toggle-button"
              size="small"
              icon="ellipsis_h"
              :title="__('Toggle commit description')"
              :aria-label="__('Toggle commit description')"
            />

            <div class="committer">
              <a
                :href="authorUrl"
                :class="authorClass"
                :data-user-id="authorId"
                v-text="authorName"
              ></a>
              {{ s__('CommitWidget|authored') }}
              <time-ago-tooltip :time="commit.authored_date" />
            </div>
          </div>
        </div>
      </div>
    </div>
    <div>
      <pre
        v-if="commit.description_html"
        v-safe-html:[$options.safeHtmlConfig]="commitDescription"
        :class="{ 'js-toggle-content': collapsible, 'd-block': !collapsible }"
        class="commit-row-description gl-mb-3 gl-text-body"
      ></pre>
    </div>
  </li>
</template>
