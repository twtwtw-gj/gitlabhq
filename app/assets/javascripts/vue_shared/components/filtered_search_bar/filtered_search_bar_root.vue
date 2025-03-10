<script>
import {
  GlFilteredSearch,
  GlButtonGroup,
  GlButton,
  GlDropdown,
  GlDropdownItem,
  GlFormCheckbox,
  GlTooltipDirective,
} from '@gitlab/ui';

import RecentSearchesStorageKeys from 'ee_else_ce/filtered_search/recent_searches_storage_keys';
import RecentSearchesService from '~/filtered_search/services/recent_searches_service';
import RecentSearchesStore from '~/filtered_search/stores/recent_searches_store';
import { createAlert } from '~/flash';
import { __ } from '~/locale';

import { SortDirection } from './constants';
import { filterEmptySearchTerm, stripQuotes, uniqueTokens } from './filtered_search_utils';

export default {
  components: {
    GlFilteredSearch,
    GlButtonGroup,
    GlButton,
    GlDropdown,
    GlDropdownItem,
    GlFormCheckbox,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    namespace: {
      type: String,
      required: true,
    },
    recentSearchesStorageKey: {
      type: String,
      required: false,
      default: '',
    },
    tokens: {
      type: Array,
      required: true,
    },
    sortOptions: {
      type: Array,
      default: () => [],
      required: false,
    },
    initialFilterValue: {
      type: Array,
      required: false,
      default: () => [],
    },
    initialSortBy: {
      type: String,
      required: false,
      default: '',
      validator: (value) => value === '' || /(_desc)|(_asc)/gi.test(value),
    },
    showCheckbox: {
      type: Boolean,
      required: false,
      default: false,
    },
    checkboxChecked: {
      type: Boolean,
      required: false,
      default: false,
    },
    searchInputPlaceholder: {
      type: String,
      required: true,
    },
    suggestionsListClass: {
      type: String,
      required: false,
      default: '',
    },
    searchButtonAttributes: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    searchInputAttributes: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    syncFilterAndSort: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      initialRender: true,
      recentSearchesPromise: null,
      recentSearches: [],
      filterValue: this.initialFilterValue,
      selectedSortOption: this.sortOptions[0],
      selectedSortDirection: SortDirection.descending,
    };
  },
  computed: {
    tokenSymbols() {
      return this.tokens.reduce(
        (tokenSymbols, token) => ({
          ...tokenSymbols,
          [token.type]: token.symbol,
        }),
        {},
      );
    },
    tokenTitles() {
      return this.tokens.reduce(
        (tokenSymbols, token) => ({
          ...tokenSymbols,
          [token.type]: token.title,
        }),
        {},
      );
    },
    sortDirectionIcon() {
      return this.selectedSortDirection === SortDirection.ascending
        ? 'sort-lowest'
        : 'sort-highest';
    },
    sortDirectionTooltip() {
      return this.selectedSortDirection === SortDirection.ascending
        ? __('Sort direction: Ascending')
        : __('Sort direction: Descending');
    },
    /**
     * This prop fixes a behaviour affecting GlFilteredSearch
     * where selecting duplicate token values leads to history
     * dropdown also showing that selection.
     */
    filteredRecentSearches() {
      if (this.recentSearchesStorageKey) {
        const knownItems = [];
        return this.recentSearches.reduce((historyItems, item) => {
          // Only include non-string history items (discard items from legacy search)
          if (typeof item !== 'string') {
            const sanitizedItem = uniqueTokens(item);
            const itemString = JSON.stringify(sanitizedItem);
            // Only include items which aren't already part of history
            if (!knownItems.includes(itemString)) {
              historyItems.push(sanitizedItem);
              // We're storing string for comparision as doing direct object compare
              // won't work due to object reference not being the same.
              knownItems.push(itemString);
            }
          }
          return historyItems;
        }, []);
      }
      return undefined;
    },
  },
  watch: {
    initialFilterValue(newValue) {
      if (this.syncFilterAndSort) {
        this.filterValue = newValue;
      }
    },
    initialSortBy(newValue) {
      if (this.syncFilterAndSort) {
        this.updateSelectedSortValues(newValue);
      }
    },
  },
  created() {
    this.updateSelectedSortValues(this.initialSortBy);
    if (this.recentSearchesStorageKey) this.setupRecentSearch();
  },
  methods: {
    /**
     * Initialize service and store instances for
     * getting Recent Search functional.
     */
    setupRecentSearch() {
      this.recentSearchesService = new RecentSearchesService(
        `${this.namespace}-${RecentSearchesStorageKeys[this.recentSearchesStorageKey]}`,
      );

      this.recentSearchesStore = new RecentSearchesStore({
        isLocalStorageAvailable: RecentSearchesService.isAvailable(),
        allowedKeys: this.tokens.map((token) => token.type),
      });

      this.recentSearchesPromise = this.recentSearchesService
        .fetch()
        .catch((error) => {
          if (error.name === 'RecentSearchesServiceError') return undefined;

          createAlert({
            message: __('An error occurred while parsing recent searches'),
          });

          // Gracefully fail to empty array
          return [];
        })
        .then((searches) => {
          if (!searches) return;

          // Put any searches that may have come in before
          // we fetched the saved searches ahead of the already saved ones
          let resultantSearches = this.recentSearchesStore.setRecentSearches(
            this.recentSearchesStore.state.recentSearches.concat(searches),
          );
          // If visited URL has search params, add them to recent search store
          if (filterEmptySearchTerm(this.filterValue).length) {
            resultantSearches = this.recentSearchesStore.addRecentSearch(this.filterValue);
          }

          this.recentSearchesService.save(resultantSearches);
          this.recentSearches = resultantSearches;
        });
    },
    /**
     * When user hits Enter/Return key while typing tokens, we emit `onFilter`
     * event immediately so at that time, we don't want to keep tokens dropdown
     * visible on UI so this is essentially a hack which allows us to do that
     * until `GlFilteredSearch` natively supports this.
     * See this discussion https://gitlab.com/gitlab-org/gitlab/-/merge_requests/36421#note_385729546
     */
    blurSearchInput() {
      const searchInputEl = this.$refs.filteredSearchInput.$el.querySelector(
        '.gl-filtered-search-token-segment-input',
      );
      if (searchInputEl) {
        searchInputEl.blur();
      }
    },
    /**
     * This method removes quotes enclosure from filter values which are
     * done by `GlFilteredSearch` internally when filter value contains
     * spaces.
     */
    removeQuotesEnclosure(filters = []) {
      return filters.map((filter) => {
        if (typeof filter === 'object') {
          const valueString = filter.value.data;
          return {
            ...filter,
            value: {
              data: typeof valueString === 'string' ? stripQuotes(valueString) : valueString,
              operator: filter.value.operator,
            },
          };
        }
        return filter;
      });
    },
    handleSortOptionClick(sortBy) {
      this.selectedSortOption = sortBy;
      this.$emit('onSort', sortBy.sortDirection[this.selectedSortDirection]);
    },
    handleSortDirectionClick() {
      this.selectedSortDirection =
        this.selectedSortDirection === SortDirection.ascending
          ? SortDirection.descending
          : SortDirection.ascending;
      this.$emit('onSort', this.selectedSortOption.sortDirection[this.selectedSortDirection]);
    },
    handleHistoryItemSelected(filters) {
      this.$emit('onFilter', this.removeQuotesEnclosure(filters));
    },
    handleClearHistory() {
      const resultantSearches = this.recentSearchesStore.setRecentSearches([]);
      this.recentSearchesService.save(resultantSearches);
      this.recentSearches = [];
    },
    handleFilterSubmit() {
      const filterTokens = uniqueTokens(this.filterValue);
      this.filterValue = filterTokens;

      if (this.recentSearchesStorageKey) {
        this.recentSearchesPromise
          .then(() => {
            if (filterTokens.length) {
              const resultantSearches = this.recentSearchesStore.addRecentSearch(filterTokens);
              this.recentSearchesService.save(resultantSearches);
              this.recentSearches = resultantSearches;
            }
          })
          .catch(() => {
            // https://gitlab.com/gitlab-org/gitlab-foss/issues/30821
          });
      }
      this.blurSearchInput();
      this.$emit('onFilter', this.removeQuotesEnclosure(filterTokens));
    },
    historyTokenOptionTitle(historyToken) {
      const tokenOption = this.tokens
        .find((token) => token.type === historyToken.type)
        ?.options?.find((option) => option.value === historyToken.value.data);

      if (!tokenOption?.title) {
        return historyToken.value.data;
      }

      return tokenOption.title;
    },
    onClear() {
      const cleared = true;
      this.$emit('onFilter', [], cleared);
    },
    updateSelectedSortValues(sort) {
      if (!sort) {
        return;
      }

      this.selectedSortOption = this.sortOptions.find(
        (sortBy) =>
          sortBy.sortDirection.ascending === sort || sortBy.sortDirection.descending === sort,
      );
      this.selectedSortDirection = Object.keys(this.selectedSortOption.sortDirection).find(
        (key) => this.selectedSortOption.sortDirection[key] === sort,
      );
    },
  },
};
</script>

<template>
  <div class="vue-filtered-search-bar-container gl-md-display-flex">
    <gl-form-checkbox
      v-if="showCheckbox"
      class="gl-align-self-center"
      :checked="checkboxChecked"
      @change="$emit('checked-input', $event)"
    >
      <span class="gl-sr-only">{{ __('Select all') }}</span>
    </gl-form-checkbox>
    <gl-filtered-search
      ref="filteredSearchInput"
      v-model="filterValue"
      :placeholder="searchInputPlaceholder"
      :available-tokens="tokens"
      :history-items="filteredRecentSearches"
      :suggestions-list-class="suggestionsListClass"
      :search-button-attributes="searchButtonAttributes"
      :search-input-attributes="searchInputAttributes"
      class="flex-grow-1"
      @history-item-selected="handleHistoryItemSelected"
      @clear="onClear"
      @clear-history="handleClearHistory"
      @submit="handleFilterSubmit"
    >
      <template #history-item="{ historyItem }">
        <template v-for="(token, index) in historyItem">
          <span v-if="typeof token === 'string'" :key="index" class="gl-px-1">"{{ token }}"</span>
          <span v-else :key="`${index}-${token.type}-${token.value.data}`" class="gl-px-1">
            <span v-if="tokenTitles[token.type]"
              >{{ tokenTitles[token.type] }} :{{ token.value.operator }}</span
            >
            <strong>{{ tokenSymbols[token.type] }}{{ historyTokenOptionTitle(token) }}</strong>
          </span>
        </template>
      </template>
    </gl-filtered-search>
    <gl-button-group v-if="selectedSortOption" class="sort-dropdown-container d-flex">
      <gl-dropdown :text="selectedSortOption.title" :right="true" class="w-100">
        <gl-dropdown-item
          v-for="sortBy in sortOptions"
          :key="sortBy.id"
          is-check-item
          :is-checked="sortBy.id === selectedSortOption.id"
          @click="handleSortOptionClick(sortBy)"
          >{{ sortBy.title }}</gl-dropdown-item
        >
      </gl-dropdown>
      <gl-button
        v-gl-tooltip
        :title="sortDirectionTooltip"
        :aria-label="sortDirectionTooltip"
        :icon="sortDirectionIcon"
        class="flex-shrink-1"
        @click="handleSortDirectionClick"
      />
    </gl-button-group>
  </div>
</template>
