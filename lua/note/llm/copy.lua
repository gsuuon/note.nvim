local M = {}

M.instructions = [[The note is based on a hierarchical structure containing items. Higher items have slightly higher priority. Each line that starts with a marker character is a new item, and each item can have child items that start at one deeper indentation. The markers signify the state of the item, and include:

> current (actively being worked on)
- pending (not yet active)
= paused (started but no longer active)
_ finished (completed, no longer active)
, cancelled (cancelled and will not be worked on)
* information (information about the task)
[ label (label or category for the task)

A line that starts with any number of # and some text is a new section. Sections can contain child sections if there is a section with more # characters:

# House
## Chores
### Groceries

House is a section that has a Chores section and Groceries section.

This language can be used to represent tasks. Child information items may contribute information about the parent item's state, use all of an items child items to answer questions.]]

return M

