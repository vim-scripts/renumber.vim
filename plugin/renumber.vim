" renumber.vim
" Author:   Neil Bird <neil@fnxweb.com>
" Version:  $Id: renumber.vim,v 1.12 2004/04/19 08:39:33 nabird Exp $
" Function: Renumber a block of numbers
" Args:     (any order)
"     s<step>   Increment number by 'step'
"     a         Search all of line for number, not just marked block columns
"     d         'Renumber' days of the week
"     m         'Renumber' months of the year
"     r         Reverse - start from bottom of block

" Vim has no way to generate hex?!
if has('perl') && ! exists('*Dec2Hex')
  function! Dec2Hex(val)
    let cmd = "perl VIM::DoCommand(\"let result='\".sprintf(\"%X\"," . a:val . ").\"'\")"
    exe cmd
    if ! exists('result')
      echoerr "Dec2Hex(" . a:val . ") failed with: " . cmd
      return a:val
    else
      return result
    endif
  endfunction
  let s:Dec2Hex = 1
elseif exists('*Dec2Hex')
  let s:Dec2Hex = 1
else
  let s:Dec2Hex = 0
endif

" Looks for match, coping with 'x' which may be part of '0x'
function! s:Matches( line, pos, size, search, hexprefix )
  let matches = strpart(a:line,a:pos,a:size) =~ '^' . a:search
  if ! matches  &&  a:hexprefix != ''  &&  a:pos > 0  &&  strpart(a:line,a:pos,1) =~ '[Xx]'
    let matches = strpart(a:line,a:pos-1,a:size) =~ '^' . a:search
  endif
  return matches
endfunction

" The actual function
function! Renumber(...)
  let initline = line('.') | let initcol = virtcol('.')
  let vc1=virtcol("'<") | let l1=line("'<") | if vc1<0 | let vc1=0x7FFFFFFF | endif
  let vc2=virtcol("'>") | let l2=line("'>") | if vc2<0 | let vc2=0x7FFFFFFF | endif
  if l1 > l2
    let l1=line("'>") | let l2=line("'<")
  endif
  if vc1 > vc2
    let tmpc = vc1 | let vc1=vc2 | let vc2=tmpc | unlet tmpc
  endif
  let l = l1 | let lstep = 1
  exe l
  exe 'normal ' . vc1 . '|'
  let cs = col('.') - 1

  let search = '-\=\(0[Xx][0-9a-fA-F]\+\|[0-9]\+\)'

  " Process args
  let step=1 | let all_line=0 | let days=0 | let months=0
  let argno = 1
  let numbers = 1
  while argno <= a:0
    exe 'let arg = a:' . argno
    if arg =~ '^s-\?\d\+$'
      let step = strpart(arg,1,strlen(arg)-1)
    elseif arg == 'a'
      let all_line = 1
    elseif arg == 'd'
      let days = 1
      let numbers = 0
      let search = '\c\<\(mo\%[nday]\|tu\%[esday]\|we\%[dnesday]\|th\%[ursday]\|fr\%[iday]\|sa\%[turday]\|su\%[nday]\)\>'
    elseif arg == 'm'
      let months = 1
      let numbers = 0
      let search = '\c\<\(jan\%[uary]\|feb\%[ruary]\|mar\%[ch]\|apr\%[il]\|may\|jun\%[e]\|jul\%[y]\|aug\%[ust]\|sep\%[tember]\|oct\%[ober]\|nov\%[ember]\|dec\%[ember]\)\>'
    elseif arg == 'r'
      let reverse = 1
      let l = l2 | let lstep = -1
    else
      echomsg 'Renumber: invalid argument "'.arg.'"'
      return
    endif
    let argno = argno + 1
  endwhile

  " Locate initial number (start at top-left of selected block)
  let line = getline(l)
  let ce = matchend( line, search, cs ) - 1
  let cs = match( line, search, cs )
  if cs == -1
    echomsg 'Renumber: no starting value found'
    return
  endif
  if ce == -1
    let ce = strlen(line) - 1
  endif
  " Find virtcol of initial match
  exe 'normal 0' . cs . 'l'
  let vci = virtcol('.')

  " Handle negative no. specially (make later anti-octal chomp work)
  if strpart(line,cs,1) == '-'
    let negative = 1
    let cs = cs + 1
  else
    let negative = 0
  endif

  " Set hex prefix
  let hexprefix = ''
  if numbers
    let hexprefix = matchstr( line, '^0[Xx]', cs )
    if hexprefix != ''  &&  ! s:Dec2Hex
      echoerr "Renumber: hex renumbering with no Hex2Dec function or perl"
      return
    endif
  endif

  " See if numbers are to be padded with 0s
  if numbers  &&  match( line, '^\(0[Xx]\)\=0', cs )
    let prepad  = '0'
  else
    let prepad  = ' '
  endif

  " Set size of number to pad to with 0s
  let numsize = ce-cs+1 - strlen(hexprefix)
  if negative
    let numsize = numsize + 1
  endif

  " Now chomp zeros so we don't interpret number as octal!
  if numbers && hexprefix == '' 
    while strpart(line,cs,1) == '0'
      let cs = cs + 1
    endwhile
  endif
  if cs > ce
    let cs = ce
  endif
  let number  = 0 + strpart(line,cs,ce-cs+1)
  let endcol  = ce

  " Now fix the sign
  if negative
    let number = -number
  endif

  " Set initial day/month
  let truncate = 1
  if days
    let daynum = (match('motuwethfrsasu','\c'.strpart(number,0,2))) / 2
    let day0='Monday'
    let day1='Tuesday'
    let day2='Wednesday'
    let day3='Thursday'
    let day4='Friday'
    let day5='Saturday'
    let day6='Sunday'
    if number ==? day{daynum}
      let truncate = 0
    endif
  elseif months
    let monthnum = (match('janfebmaraprmayjunjulaugsepoctnovdec','\c'.strpart(number,0,3))) / 3
    let month0='January'
    let month1='February'
    let month2='March'
    let month3='April'
    let month4='May'
    let month5='June'
    let month6='July'
    let month7='August'
    let month8='September'
    let month9='October'
    let month10='November'
    let month11='December'
    if number ==? month{monthnum}
      let truncate = 0
    endif
  endif

  " Start cycling through rest of block
  let l = l + lstep
  while ( lstep < 0 && l >= l1 ) || ( lstep > 0 && l <= l2 )
    let line=getline(l)
    exe l
    exe 'normal ' . vc1 . '|'
    let c1 = col('.') - 1
    exe 'normal ' . vc2 . '|'
    let c2 = col('.') - 1
    exe 'normal ' . vci . '|'
    let ci = col('.') - 1

    " Locate next number within marked block, starting from first value
    let numberfound = 1
    let cs = match( line, search, ci )
    " See if found (in range)
    if cs > c2 || cs == -1
      " Not found - try backwards within block
      let cs = ci
      while cs >= c1  &&  ! s:Matches(line,cs,numsize,search,hexprefix)
        let cs = cs - 1
      endwhile
      if cs < c1
        " Not found at all (within block)
        let numberfound = 0
      else
        " Found something - now find beginning
        while cs >= 0  &&  s:Matches(line,cs,numsize,search,hexprefix)
          let cs = cs - 1
        endwhile
        let cs = cs + 1
        " Re-assert end
        let ce = matchend(line,search,cs) - 1
      endif
    else
      " Found number - make sure it's the start (might have hit the middle)
      while cs >= 0  &&  s:Matches(line,cs,numsize,search,hexprefix)
        let cs = cs - 1
      endwhile
      let cs = cs + 1
      " Find end
      let ce = matchend(line,search,cs) - 1
    endif

    " If not found, locate next number in whole line - try forwards from here
    if ! numberfound  &&  all_line
      let numberfound = 1
      let cs = match( line, search, ci ) + ci
      " See if found
      if cs < ci
        " Not found - try backwards
        let cs = ci
        while cs >= 0  &&  ! s:Matches(line,cs,numsize,search,hexprefix)
          let cs = cs - 1
        endwhile
        if cs < 0
          let numberfound = 0
        else
          " Found something - now find beginning
          while cs >= 0  &&  s:Matches(line,cs,numsize,search,hexprefix)
            let cs = cs - 1
          endwhile
          let cs = cs + 1
          " Re-assert end
          let ce = matchend(line,search,cs) - 1
        endif
      else
        " Found start - find end
        let ce = matchend(line,search,cs) - 1
      endif
    endif

    " Found number to process?
    if numberfound
      " Reset ci - it'll make future searching faster
      let ci = cs

      " Now skip leading spaces we may need to change
      let cs = cs - 1
      while cs >= 0  &&  strpart(line,cs,1) == ' '
        let cs = cs - 1
      endwhile
      let cs = cs + 1

      " Create number to insert:
      if days
        let daynum = ( daynum + step ) % 7
        if truncate
          let this = strpart( day{daynum}, 0, numsize )
        else
          let this = day{daynum}
        endif

      elseif months
        let monthnum = ( monthnum + step ) % 12
        if truncate
          let this = strpart( month{monthnum}, 0, numsize )
        else
          let this = month{monthnum}
        endif

      else
        " Numbers
        let number = number + step
        let this = number

        if number < 0
          let neg = '-'
          let this = -this
        else
          let neg = ''
        endif

        if hexprefix != ''
          let this = Dec2Hex(this)
        endif

        if prepad != ''
          while strlen(this) < numsize
            let this = prepad . this
          endwhile
        endif

        let this = neg . hexprefix . this
      endif

      " Right-align the numbers
      while cs + strlen(this) <= endcol
        let this = ' ' . this
      endwhile

      " Change current line
      let line = strpart(line,0,cs) . this . strpart(line,ce+1,strlen(line)-ce+1)
      call setline( l, line )
    endif

    let l = l + lstep
  endwhile

  exe initline
  exe 'normal ' . initcol . '|'
endfunction
command! -range -nargs=? Renumber  call Renumber(<f-args>)
