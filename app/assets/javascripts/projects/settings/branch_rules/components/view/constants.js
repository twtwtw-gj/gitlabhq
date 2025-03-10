import { s__ } from '~/locale';

export const I18N = {
  manageProtectionsLinkTitle: s__('BranchRules|Manage in Protected Branches'),
  targetBranch: s__('BranchRules|Target Branch'),
  branchNameOrPattern: s__('BranchRules|Branch name or pattern'),
  branch: s__('BranchRules|Target Branch'),
  allBranches: s__('BranchRules|All branches'),
  protectBranchTitle: s__('BranchRules|Protect branch'),
  protectBranchDescription: s__(
    'BranchRules|Keep stable branches secure and force developers to use merge requests. %{linkStart}What are protected branches?%{linkEnd}',
  ),
  wildcardsHelpText: s__(
    'BranchRules|%{linkStart}Wildcards%{linkEnd} such as *-stable or production/ are supported',
  ),
  forcePushTitle: s__('BranchRules|Force push'),
  allowForcePushDescription: s__(
    'BranchRules|All users with push access are allowed to force push.',
  ),
  disallowForcePushDescription: s__('BranchRules|Force push is not allowed.'),
  approvalsTitle: s__('BranchRules|Approvals'),
  statusChecksTitle: s__('BranchRules|Status checks'),
  allowedToPushHeader: s__('BranchRules|Allowed to push (%{total})'),
  allowedToMergeHeader: s__('BranchRules|Allowed to merge (%{total})'),
  noData: s__('BranchRules|No data to display'),
};

export const BRANCH_PARAM_NAME = 'branch';

export const ALL_BRANCHES_WILDCARD = '*';

export const WILDCARDS_HELP_PATH =
  'user/project/protected_branches#configure-multiple-protected-branches-by-using-a-wildcard';

export const PROTECTED_BRANCHES_HELP_PATH = 'user/project/protected_branches';
