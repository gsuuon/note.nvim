if exists("b:current_syntax")
    finish
endif

let b:current_syntax = 1

syn match noteItemPending /^\s*- .\+/
syn match noteItemMarkerPending /^\s*-/ containedin=noteItemPending contained

syn match noteItemCurrent /^\s*> .\+/
syn match noteItemMarkerCurrent /^\s*>/ containedin=noteItemCurrent contained

syn match noteItemDone /^\s*\. .\+/
syn match noteItemMarkerDone /^\s*\./ containedin=noteItemDone contained

syn match noteItemCancelled /^\s*, .\+/
syn match noteItemMarkerCancelled /^\s*,/ containedin=noteItemCancelled contained

syn match noteItemPaused /^\s*= .\+/
syn match noteItemMarkerPaused /^\s*=/ containedin=noteItemPaused contained

syn match noteItemInfo /^\s*\* .\+/
syn match noteItemMarkerInfo /^\s*\*/ containedin=noteItemInfo contained

syn match noteItemLabel /^\s*\[ .\+/
syn match noteItemMarkerLabel /^\s*\[/ containedin=noteItemLabel contained

syn match noteSymbolWarn /(!)/ containedin=noteItemPending,noteItemCurrent,noteItemDone,noteItemCancelled,noteItemPaused,noteItemInfo,noteItemLabel
syn match noteSymbolQuestion /(?)/ containedin=noteItemPending,noteItemCurrent,noteItemDone,noteItemCancelled,noteItemPaused,noteItemInfo,noteItemLabel
syn match noteSymbolFlow / -> / containedin=noteItemPending,noteItemCurrent,noteItemDone,noteItemCancelled,noteItemPaused,noteItemInfo,noteItemLabel
syn match noteSymbolSelect / <-$/ containedin=noteItemPending,noteItemCurrent,noteItemDone,noteItemCancelled,noteItemPaused,noteItemInfo,noteItemLabel

syn match noteSectionTitleLine /^#\+ .\+/
syn match noteSectionTitleText1 /^#\( \)\zs.\+/ containedin=noteSectionTitleLine contained
syn match noteSectionTitleText2 /^##\( \)\zs.\+/ containedin=noteSectionTitleLine contained
syn match noteSectionTitleText3 /^###\( \)\zs.\+/ containedin=noteSectionTitleLine contained
syn match noteSectionTitleTextMore /^####\+\( \)\zs.\+/ containedin=noteSectionTitleLine contained

" hi noteItemMarker guibg=#cccccc

hi link noteItemMarkerPending Identifier
hi link noteItemMarkerCurrent QuickFixLine
hi link noteItemMarkerDone Constant
hi link noteItemMarkerCancelled Error
hi link noteItemMarkerPaused StorageClass
hi link noteItemMarkerInfo Comment
hi link noteItemMarkerLabel Tag

hi link noteItemCurrent ModeMsg
hi link noteItemLabel Tag
hi link noteItemDone SpecialComment
hi link noteItemCancelled Conceal
hi link noteItemInfo Comment

hi link noteSymbolWarn YellowSign
hi link noteSymbolQuestion BlueSign
hi link noteSymbolFlow AquaSign
hi link noteSymbolSelect GreenSign


hi link noteSectionTitleLine Comment
if hlexists('TSDanger')
    hi link noteSectionTitleText1 TSDanger
    hi link noteSectionTitleText2 TSWarning
    hi link noteSectionTitleText3 TSNote
else
    hi link noteSectionTitleText1 Title
    hi link noteSectionTitleText2 Title
    hi link noteSectionTitleText3 Title
endif

hi link noteSectionTitleTextMore Title
