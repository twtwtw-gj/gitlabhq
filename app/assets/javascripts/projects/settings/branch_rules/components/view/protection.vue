<script>
import { GlCard, GlLink } from '@gitlab/ui';
import { s__ } from '~/locale';
import ProtectionRow from './protection_row.vue';

export const i18n = {
  rolesTitle: s__('BranchRules|Roles'),
  usersTitle: s__('BranchRules|Users'),
  groupsTitle: s__('BranchRules|Groups'),
};

export default {
  name: 'ProtectionDetail',
  i18n,
  components: { GlCard, GlLink, ProtectionRow },
  props: {
    header: {
      type: String,
      required: true,
    },
    headerLinkTitle: {
      type: String,
      required: true,
    },
    headerLinkHref: {
      type: String,
      required: true,
    },
    roles: {
      type: Array,
      required: false,
      default: () => [],
    },
    users: {
      type: Array,
      required: false,
      default: () => [],
    },
    groups: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  computed: {
    showUsersDivider() {
      return Boolean(this.roles.length);
    },
    showGroupsDivider() {
      return Boolean(this.roles.length || this.users.length);
    },
  },
};
</script>

<template>
  <gl-card class="gl-mb-5" body-class="gl-py-0">
    <template #header>
      <div class="gl-display-flex gl-justify-content-space-between">
        <strong>{{ header }}</strong>
        <gl-link :href="headerLinkHref">{{ headerLinkTitle }}</gl-link>
      </div>
    </template>

    <!-- Roles -->
    <protection-row v-if="roles.length" :title="$options.i18n.rolesTitle" :access-levels="roles" />

    <!-- Users -->
    <protection-row
      v-if="users.length"
      :show-divider="showUsersDivider"
      :users="users"
      :title="$options.i18n.usersTitle"
    />

    <!-- Groups -->
    <protection-row
      v-if="groups.length"
      :show-divider="showGroupsDivider"
      :title="$options.i18n.groupsTitle"
      :access-levels="groups"
    />
  </gl-card>
</template>
