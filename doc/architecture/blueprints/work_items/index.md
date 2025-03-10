---
stage: Plan
group: Project Management
comments: false
description: 'Work Items'
---

# Work Items

DISCLAIMER:
This page may contain information related to upcoming products, features and functionality. It is important to note that the information presented is for informational purposes only, so please do not rely on the information for purchasing or planning purposes. Just like with all projects, the items mentioned on the page are subject to change or delay, and the development, release, and timing of any products, features, or functionality remain at the sole discretion of GitLab Inc.

This document is a work-in-progress. Some aspects are not documented, though we expect to add them in the future.

## Summary

Work Items is a new architecture created to support the various types of built and planned entities throughout the product, such as issues, requirements, and incidents. It will make these types easy to extend and customize while sharing the same core functionality.

## Terminology

We use the following terms to describe components and properties of the Work items architecture.

### Work Item

Base type for issue, requirement, test case, incident and task (this list is planned to extend in the future). Different work items have the same set of base properties but their [widgets](#work-item-widgets) list is different.

### Work Item types

A set of predefined types for different categories of work items. Currently, the available types are:

- Issue
- Incident
- Test case
- Requirement
- Task

#### Work Item properties

Every Work Item type has the following common properties:

- `id` - a unique Work Item global identifier;
- `iid` - internal ID of the Work Item, relative to the parent workspace (currently workspace can only be a project)
- Work Item type;
- properties related to Work Item modification time: `createdAt`, `updatedAt`, `closedAt`;
- title string;
- Work Item confidentiality state;
- Work Item state (can be open or closed);
- lock version, incremented each time the work item is updated;
- permissions for the current user on the resource
- a list of [Work Item widgets](#work-item-widgets)

### Work Item widgets

All Work Item types share the same pool of predefined widgets and are customized by which widgets are active on a specific type. The list of widgets for any certain Work Item type is currently predefined and is not customizable. However, in the future we plan to allow users to create new Work Item types and define a set of widgets for them.

### Work Item widget types (updating)

- assignees
- description
- hierarchy
- iteration
- labels
- start and due date
- verification status
- weight

### Work Item view

The new frontend view that renders Work Items of any type using global Work Item `id` as an identifier.

### Task

Task is a special Work Item type. Tasks can be added to issues as child items and can be displayed in the modal on the issue view.

## Motivation

Work Items main goal is to enhance the planning toolset to become the most popular collaboration tool for knowledge workers in any industry.

- Puts all like-items (issues, incidents, epics, test cases etc.) on a standard platform to simplify maintenance and increase consistency in experience
- Enables first-class support of common planning concepts to lower complexity and allow users to plan without learning GitLab-specific nuances.

## Goals

### Scalability

Currently, different entities like issues, epics, merge requests etc share many similar features but these features are implemented separately for every entity type. This makes implementing new features or refactoring existing ones problematic: for example, if we plan to add new feature to issues and incidents, we would need to implement it separately on issue and incident types respectively. With work items, any new feature is implemented via widgets for all existing types which makes the architecture more scalable.

### Flexibility

With existing implementation, we have a rigid structure for issuables, merge requests, epics etc. This structure is defined on both backend and frontend, so any change requires a coordinated effort. Also, it would be very hard to make this structure customizable for the user without introducing a set of flags to enable/disable any existing feature. Work Item architecture allows frontend to display Work Item widgets in a flexible way: whatever is present in Work Item widgets, will be rendered on the page. This allows us to make changes fast and makes the structure way more flexible. For example, if we want to stop displaying labels on the Incident page, we simply remove labels widget from Incident Work Item type on the backend. Also, in the future this will allow users to define the set of widgets they want to see on custom Work Item types.

### A consistent experience

As much as we try to have consistent behavior for similar features on different entities, we still have differences in the implementation. For example, updating labels on merge request via GraphQL API can be done with dedicated `setMergeRequestLabels` mutation, while for the issue we call more coarse-grained `updateIssue`. This provides inconsistent experience for both frontend and external API users. As a result, epics, issues, requirements, and others all have similar but just subtle enough differences in common interactions that the user needs to hold a complicated mental model of how they each behave.

Work Item architecture is designed with making all the features for all the types consistent, implemented as Work Item widgets.

## High-level architecture problems to solve

- how can we bypass groups and projects consolidation to migrate epics to Work Item type;
- dealing with parent-child relationships for certain Work Item types: epic > issue > task, and to the same Work Item types: issue > issue.
- [implementing custom Work Item types and custom widgets](https://gitlab.com/gitlab-org/gitlab/-/issues/335110)

### Links

- [Work items initiative epic](https://gitlab.com/groups/gitlab-org/-/epics/6033)
- [Tasks roadmap](https://gitlab.com/groups/gitlab-org/-/epics/7103?_gl=1*zqatx*_ga*NzUyOTc3NTc1LjE2NjEzNDcwMDQ.*_ga_ENFH3X7M5Y*MTY2MjU0MDQ0MC43LjEuMTY2MjU0MDc2MC4wLjAuMA..)
- [Work Item "Vision" Prototype](https://gitlab.com/gitlab-org/gitlab/-/issues/368607)
- [Work Item Discussions](https://gitlab.com/groups/gitlab-org/-/epics/7060)

### Who

| Role                         | Who
|------------------------------|-----------------------------|
| Author                       | Natalia Tepluhina           |
| Architecture Evolution Coach | Kamil Trzciński             |
| Engineering Leader           | TBD                         |
| Product Manager              | Gabe Weaver                 |
| Domain Expert / Frontend     | Natalia Tepluhina           |
| Domain Expert / Backend      | Heinrich Lee Yu             |
| Domain Expert / Backend      | Jan Provaznik               |
| Domain Expert / Backend      | Mario Celi                  |

DRIs:

| Role                         | Who
|------------------------------|------------------------|
| Leadership                   | TBD                    |
| Product                      | Gabe Weaver            |
| Engineering                  | TBD                    |
