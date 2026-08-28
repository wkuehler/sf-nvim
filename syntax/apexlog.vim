" Minimal highlighting for Salesforce Apex debug logs
if exists("b:current_syntax") | finish | endif

syn match apexlogTimestamp  /^\d\d:\d\d:\d\d\.\d\+ (\d\+)/
syn match apexlogEvent      /|[A-Z_]\+|\?/ contained
syn match apexlogLine       /^\d\d:\d\d:\d\d\.\d\+ (\d\+)|[A-Z_]\+/ contains=apexlogTimestamp,apexlogEvent
syn match apexlogDebug      /^.*|USER_DEBUG|.*$/
syn match apexlogError      /^.*|\(EXCEPTION_THROWN\|FATAL_ERROR\|VALIDATION_FAIL\)|.*$/
syn match apexlogSoql       /^.*|\(SOQL_EXECUTE_BEGIN\|SOSL_EXECUTE_BEGIN\|DML_BEGIN\)|.*$/
syn match apexlogLimit      /^.*|\(LIMIT_USAGE_FOR_NS\|CUMULATIVE_LIMIT_USAGE\)|.*$/
syn match apexlogHeader     /^== .*$/
syn match apexlogAnon       /^Execute Anonymous: .*$/

hi def link apexlogTimestamp Comment
hi def link apexlogEvent     Keyword
hi def link apexlogDebug     String
hi def link apexlogError     Error
hi def link apexlogSoql      Statement
hi def link apexlogLimit     Special
hi def link apexlogHeader    Title
hi def link apexlogAnon      PreProc

let b:current_syntax = "apexlog"
