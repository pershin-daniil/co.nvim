" Syntax file for co prompt window
if exists("b:current_syntax")
  finish
endif

syntax clear

syntax match coRuleRef /#\S\+/
syntax match coFileRef /@\S\+/

highlight default coRuleRef guifg=#00FFFF ctermfg=cyan
highlight default coFileRef guifg=#DAA520 ctermfg=178

let b:current_syntax = "coprompt"
