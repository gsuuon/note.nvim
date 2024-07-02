# note.nvim 📓

A Neovim note taking plugin for daily notes, task tracking and easy deep linking across files or git commits.


https://github.com/gsuuon/note.nvim/assets/6422188/4f186db5-7938-4c45-b791-c1c8fbf88ff7

## Motivation
The goal is to reduce the cost of interruptions and make it easy to recontextualize when you return to work in progress. Nested task items, deep links, time-based logging and being able to mark items as current makes it easy to take a fairly detailed snapshot of your 'working heap'.

## Setup
```lua
use 'gsuuon/note.nvim'
```

### Configuration
With lazy.nvim:
```lua
  {
    'gsuuon/note.nvim',
    opts = {
      -- opts.spaces are note workspace parent directories.
      -- These directories contain a `notes` directory which will be created if missing.
      -- `<space path>/notes` acts as the note root, so for space '~' the note root is `~/notes`.
      -- Defaults to { '~' }.
      spaces = {
        '~',
        -- '~/projects/foo'
      },

      -- Set keymap = false to disable keymapping
      -- keymap = { 
      --   prefix = '<leader>n'
      -- }
    },
    cmd = 'Note',
    ft = 'note'
  }
```

### Tree-sitter
A [tree-sitter grammar](https://github.com/gsuuon/tree-sitter-note) can be installed with `:TSInstall note`. The grammar includes markdown style code-fenced injections of other languages and makes it possible to use treesitter based navigation like [tshjkl](https://github.com/gsuuon/tshjkl.nvim) with note items.

https://github.com/gsuuon/note.nvim/assets/6422188/27fbbc66-6a6a-49ef-94ca-25e4e5eeb3b9

> [!NOTE]
> The tree-sitter grammar currently assumes unix newlines, if tree-sitter parser is installed then note will :set ff=unix in note filetype buffers

#### Highlights
The treesitter highlight groups are linked in [ftplugin/note.lua](ftplugin/note.lua) and the group queries are in [queries/note/highlights.scm](queries/note/highlights.scm). You can customize these by overriding the groups with your own links or highlights.

## Usage
Open the daily note with `:Note`. This can be scoped to a workspace root with the `spaces` config option.
```lua
require('note').setup({
  spaces = { '~', '~/myproject' }
})
```
The active space will be the last path which contains the current working directory. Spaces are matched bottom up, so the least specific path should be first. The "note root" is `<space path>/notes/` - all note actions (daily notes, templating, rooted links) are done relative to this directory.

You can create a custom template for daily notes at `<note root>/.note/daily_template`. note comes with [treesitter based highlighting](#tree-sitter) but falls back to a syntax file if the grammar is not installed.

[Keymaps](#keymaps) are added for note.nvim commands with a default prefix of `<leader>n`.

### Items
Items can be properties or tasks. The first character is a marker that indicates the type and status of the item, some examples:
```
- pending task
  * info property
. finished task
  [ label property
  . sub task
```

Items are indentation scoped - a newline and 2 spaces deeper indent followed by a marker starts a child item scope. An item can contain any text on the same line, which becomes the item content. Items can also have a body (any text after the first line) as long as it doesn't start with a marker character or section header. Item bodies can contain code blocks with markdown style codefences.
> [!IMPORTANT]
> Each indent level is 2 spaces and each scope can only be one level deeper than the previous one.

An item with a code block body:
````
- a pending task
```js
const scratchFn = () => {}
```
- other task
````

#### Tasks
`>` — current  
`-` — pending  
`.` — done  
`=` — paused  
`,` — cancelled  

#### Properties
`*` — info  
`[` — label  

#### Sections
`#` — section -- Not indented - the number of #'s mean depth like markdown.  

### Decorators
Decorators are special symbols that help with readability. They have [default highlight group](#highlights) links which can be overriden, or you can set `opts.disable_decorators = true` to disable decorator highlighting.

`  ->  ` — flow -- indicates one thing flowing to another  
` <-` — select -- indicates selecting one of a list  
`(?)` — question -- draw attention to something confusing  
`(!)` — warn -- draw attention to something important  


### Links
> [!WARNING]
> **The link format has changed from `[<link>]` to `{{<link>}}`**. Use `:NoteConvertLinksSquareToCurly` in files with square bracket links to update them.

You can create a link by writing `{{(<file>)<marker>|<content>}}`, where `<thing>` is a thing to be replaced (see below for examples). Follow a link by moving your cursor over it and running `:NoteGoLink`. This will search for a target item first by looking downwards from the link and then upwards. The file part can point to a specific commit.

- `<content>` behaves like a case-insensitive `string.match` against item content.  
- `(<file>)` links to `<file>` relative to the current file. The target path is joined with the current file's directory. If `<file>` starts with `/` then it will resolve relative to the note workspace root (e.g. `~/notes`). A link can just point to a file without specifying a marker or body.  
- `(<file>@<commit>)` links to the file at a specific commit. The git root is assumed to be the same as the note workspace root.  
- `<marker>` is a specific item marker (e.g. `-`, `*`) or one of these special characters:

`s` — section -- matches any number of #'s  
`p` — property -- matches any property marker  
`t` — task -- matches any task marker  

Link examples:

`{{t|clean}}` - a task containing 'clean'  
`{{(chores)s|daily}}` - a file in the same directory as the current file named 'chores', finds the first section header containing 'daily'  
`{{(/budget)t|groceries}}` - the 'budget' file in the note root, finds the first task containing 'groceries'  
`{{(/tasks)}}` - the 'tasks' file in the note root

## Examples
![note](https://github.com/gsuuon/note.nvim/assets/6422188/813e74e7-d9dc-4b5f-b433-4ef294491797)

`Take out the trash` is labeled as a `[ chore`.
```
- Take out the trash
  [ chore
```

`Pick up toys` is the current (`>`) task and is part of `Cleanup house`.
```
- Cleanup house
  - Wash dishes
  > Pick up toys
```

`{{t|monday}}` links to the `- Monday` task and `{{(../health)s|goal}}` links to the the 'health' file up one directory at a section matching `goal`.
```
{{t|monday}}
# Gym
- Monday
  - Squats
{{(../health)s|goal}}
```


## Commands

### Global
`Note <path>` — Create or open the daily note if no arguments. Tab completes arguments with files from current note root  
`NoteIndex` — Edit the note index of the current space  

### Note buffers
`NoteCurrentItem` — Jump to the current task (`>`)  
`NoteFindItem <marker> <body pattern>` — Jump to a matching item. Tab completes if marker is `s` with available sections in file  
`NoteMarkItem <marker>` — Change the marker of the item under cursor. Only for task or property markers. Dot-repeatable.  
`NoteMarkItemChildren <marker>` — The cursor item and all children with a matching marker get marked  
`NoteGoLink` — Follow the link under cursor  
`NoteTime <marker?>` — Insert a timestamped item with marker (defaults to `*`)
`NoteReport` — Notify with a summary of the current note  
`NoteLinkPinCommit` — Modify the link under the cursor to pin it to the current commit and absolute path of current file (if not specified)  

#### Refs
`NoteRefCreate` — Create a ref for the item under the cursor  
`NoteRefPaste` — Paste a link to the last created ref  
`NoteRefYank` — Yank the ref for the item under the cursor to use with `NoteRefPaste`  

`*Linked*` commands add a ref link from the source item to the target and from target to the source  
`NoteItemLinkedYank` — Yank the item under the cursor. Creates a ref if one doesn't exist  
`NoteItemLinkedPaste` — Paste the last LinkedYank item  
`NoteItemLinkToday <marker> <body>` — Yank the item under the cursor and add it as a child item of marker body in the daily note  

#### Daily notes
`NotePrevious` — Edit the previous daily note  
`NoteNext` — Edit the next daily note  

## Keymaps
### Note buffers
`<prefix>t` — NoteTime  
`<prefix>l` — NoteGoLink  
`<prefix>c` — NoteCurrentItem  
`<prefix>m<marker>` — NoteMarkItem <marker>  
`<prefix>M<marker>` — NoteMarkItemChildren <marker>  
`<prefix>f<marker>` — NoteFindItem <marker> .  

#### Daily notes
`<prefix>n` — NoteNext  
`<prefix>p` — NotePrevious  
