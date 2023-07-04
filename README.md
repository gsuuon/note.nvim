# note.nvim 📓

A simple Neovim note taking plugin with daily notes, task tracking and syntax highlighting.

https://github.com/gsuuon/note.nvim/assets/6422188/4f186db5-7938-4c45-b791-c1c8fbf88ff7

## Motivation
note.nvim makes it easy to take working notes and track tasks. It adds commands to help manipulate task items, create daily notes, and navigate within (and between) notes.

## Usage
Write indent-scoped ideas / tasks / notes. You can set a template for daily notes (`:Note`) by creating `[note_root]/.note/daily_template`. You can also add spaces (`config.spaces = { '~', '~/myproject' }`) to set up different note root directories.

Upgrades with some simple OpenAI gpt prompts if [llm.nvim](https://github.com/gsuuon/llm.nvim) is installed.

### Items
A marker indicates their type or status. Indented tasks establish scope and indented properties attach to the outer item. Normal text that are't items will just be ignored by the item commands.

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

### Modifiers
Some special symbols will also highlight to help with readability:

`->` — flow -- indicates one thing flowing to another  
`<-` — select -- indicates selecting one of a list  
`(?)` — question -- draw attention to something confusing  
`(!)` — warn -- draw attention to something important  

### Links
Links to items can be created with `[(<file>)<marker>|<body>]`. They're shortcuts that search for a target item, first by searching downwards from the link and then upwards. The file part can point to a specific commit.

- `<body>` behaves like a case-insensitive `string.match` against items.
- `(<file>)` if present links to that file relative to the current file - the path is joined with the current file's directory. If the file part starts with `/` then the path is resolved relative to the note root.
- `(<file>@<commit>)` links to the file at a specific commit. The git root is expected to be the note root.  
- `<marker>` is a specific marker (e.g. `-`, `*`) or one of these special characters:

`s` — section -- matches any number of #'s  
`p` — property -- matches any property marker  
`t` — task -- matches any task marker  

For example:

`[t|clean]` links to a task containing 'clean'  
`[(chores)s|daily]` links to a file in the same directory as the current file named 'chores' and finds the first section with 'daily'  
`[(/budget)t|groceries]` links to the 'budget' file in the note root and finds the first 'groceries' task  


## Examples
![note](https://github.com/gsuuon/note.nvim/assets/6422188/813e74e7-d9dc-4b5f-b433-4ef294491797)

```
- Take out the trash
  [ chore
```
Here `Take out the trash` is labeled as a `[ chore`.

```
- Cleanup house
  - Wash dishes
  > Pick up toys
```
Here `Pick up toys` is the current (`>`) task and is part of `Cleanup house`.

```
[t|monday]
# Gym
- Monday
  - Squats
[(../health)s|goal]
```
Here `[t|monday]` links to the `- Monday` task and `[(../health)s|goal]` links to the the 'health' file up one directory at a section matching `goal`.

# Setup
```lua
use 'gsuuon/note.nvim'
```

## Configuration
```lua
-- These are the defaults
require('note').setup({
  spaces = { -- Spaces are note roots. These should have a `/notes` folder.
    '~',
    -- '~/code/myproject'
  },
  keymap = { -- set this to false to disable keymapping
    prefix = '<leader>n'
  }
})
```

## Commands

### Global
`Note <path>` — Create or open the daily note if no arguments. Tab completes arguments with files from current note root  
`NoteIndex` — Edit the note index of the current space  

### Note buffers
`NoteCurrentItem` — Jump to the current task (`>`)  
`NoteFindItem <marker> <body pattern>` — Jump to a matching item  
`NoteMarkItem <marker>` — Change the marker of the item under cursor. Only for task or property markers  
`NoteMarkItemChildren <marker>` — The cursor item and all children with a matching marker get marked  
`NoteGoLink` — Follow the link under cursor  
`NoteTime <marker?>` — Insert a timestamped item with marker (defaults to `*`)
`NoteReport` — Notify with a summary of the current note  

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
`<prefix>m<marker>` — NoteMarkItem <marker>  
`<prefix>M<marker>` — NoteMarkItemChildren <marker>  
`<prefix>f<marker>` — NoteFindItem <marker> .  

#### Daily notes
`<prefix>n` — NoteNext  
`<prefix>p` — NotePrevious  
