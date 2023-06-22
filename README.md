# note.nvim 📓

A simple Neovim note taking plugin with daily notes, task tracking and syntax highlighting.

https://github.com/gsuuon/note.nvim/assets/6422188/4f186db5-7938-4c45-b791-c1c8fbf88ff7

## Motivation
note.nvim makes it easy to take working notes and track tasks. It adds commands to help manipulate task items, create daily notes, and navigate both between and within notes.

## Usage
Write ideas / tasks / notes in a hierarchical way. Spaces `config.spaces = { '~' }` are note root directories. You can set a template for daily notes by creating `[note_root]/.note/daily_template` which will get copied for each new daily note.

### Items
Items are organized hierachically and a marker indicates their type or status. Indented items mean attachment, these can be either sub-tasks or properties.

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
`#` — section -- number of #'s mean depth, like markdown  

### Modifiers
Some special symbols will also highlight to help with readability:

`->` — flow -- indicates one thing flowing to another  
`<-` — select -- indicates selecting one of a list  
`(?)` — question -- draw attention to something confusing  
`(!)` — warn -- draw attention to something important  

### Links
Links to items within the same file can be created with `[<marker>|<body>]`, where marker is either a marker character or one of these:

`s` — section -- matches any number of #'s  
`p` — property -- matches any property marker  
`t` — task -- matches any task marker  

The link body will be matched against item bodies via lua's `string.match`

![note](https://github.com/gsuuon/note.nvim/assets/6422188/813e74e7-d9dc-4b5f-b433-4ef294491797)

### Examples
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
`Note` — Create or open the daily note  
`NoteIndex` — Edit the note index of the current space  

### Note buffers
`NoteCurrentItem` — Jump to the current task (`>`)  
`NoteFindItem <marker> <body pattern>` — Jump to a matching item  
`NoteMarkItem <marker>` — Change the marker of the item under cursor  
`NoteGoLink` — Follow the link under cursor  
`NoteTime <marker?>` — Insert a timestamped item with marker (defaults to `*`)

#### Daily notes
`NotePrevious` — Edit the previous daily note  
`NoteNext` — Edit the next daily note  

## Keymaps
### Note buffers
`<prefix>l` — NoteGoLink  
`<prefix>m<marker>` — NoteMarkItem -- only for item markers  
`<prefix>t` — NoteTime

#### Daily notes
`<prefix>n` — NoteNext  
`<prefix>p` — NotePrevious  