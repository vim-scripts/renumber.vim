" renumber.vim
" Author:   Neil Bird <neil@fnxweb.com>
" Version:  $Id: renumber.vim,v 1.10 2003/05/18 17:10:00 nabird Exp $
" Function: Renumber a block of numbers
" Args:     (any order)
"     s<step>   Increment number by 'step'
"     a         Search all of line for number, not just marked block columns
"     d         'Renumber' days of the week
"     m         'Renumber' months of the year
"     r         Reverse - start from bottom of block
function! Renumber(...)
  let c1=col("'<") | let l1=line("'<") | if c1<0 | let c1=0x7FFFFFFF | endif
  let c2=col("'>") | let l2=line("'>") | if c2<0 | let c2=0x7FFFFFFF | endif
  if l1 > l2
    let l1=line("'>") | let l2=line("'<")
  endif
  if c1 > c2
    let tmpc = c1 | let c1=c2 | let c2=tmpc | unlet tmpc
  endif
  let c1 = c1 - 1 | let c2 = c2 - 1
  let l = l1 | let lstep = 1
  let cs = c1

  let search = '-\=[0-9]\+'
  
  " Process args
  let step=1 | let all_line=0 | let days=0 | let months=0
  let argno = 1
  while argno <= a:0
    exe 'let arg = a:' . argno
    if arg =~ '^s-\?\d\+$'
      let step = strpart(arg,1,strlen(arg)-1)
    elseif arg == 'a'
      let all_line = 1
    elseif arg == 'd'
      let days = 1
      let search = '\c\<\(mo\%[nday]\|tu\%[esday]\|we\%[dnesday]\|th\%[ursday]\|fr\%[iday]\|sa\%[turday]\|su\%[nday]\)\>'
    elseif arg == 'm'
      let months = 1
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
  let ci = cs

  " See if numbers are to be padded with 0s
  if strpart(line,cs,1) == '0'
    let prepad  = '0'
  else
    let prepad  = ' '
  endif

  " Set size of number to pad to with 0s
  let numsize = ce-cs+1

  " Now chomp zeros so we don't interpret number as octal!
  while strpart(line,cs,1) == '0'
    let cs = cs + 1
  endwhile
  if cs > ce
    let cs = ce
  endif
  let number  = strpart(line,cs,ce-cs+1)
  let endcol  = ce

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

    " Locate next number within marked block, starting from first value
    let numberfound = 1
    let cs = match( line, search, ci )
    " See if found
    if cs > c2
      " Not found - try backwards within block
      let cs = ci
      while cs >= c1  &&  strpart(line,cs,numsize) !~ '^' . search
        let cs = cs - 1
      endwhile
      if cs < c1
        " Not found at all (within block)
        let numberfound = 0
      else
        " Found something - now find beginning
        while cs >= 0  &&  strpart(line,cs,numsize) =~ '^' . search
          let cs = cs - 1
        endwhile
        let cs = cs + 1
        " Re-assert end
        let ce = matchend(line,search,cs) - 1
      endif
    else
      " Found number - make sure it's the start (might have hit the middle)
      while cs >= 0  &&  strpart(line,cs,numsize) =~ '^' . search
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
        while cs >= 0  &&  strpart(line,cs,numsize) !~ '^' . search
          let cs = cs - 1
        endwhile
        if cs < 0
          let numberfound = 0
        else
          " Found end - now find beginning
          while cs >= 0  &&  strpart(line,cs,numsize) =~ '^' . search
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
        " Pad with leading zeros if required
        let number = number + step
        let this = number
        if number < 0
          let neg = '-'
          let this = -this
        else
          let neg = ''
        endif
        if prepad == '0'
          while strlen(this) < numsize
            let this = prepad . this
          endwhile
        endif
        let this = neg . this
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
endfunction
command! -range -nargs=? Renumber  call Renumber(<f-args>)
