" renumber.vim
" Author:   Neil Bird <neil@fnxweb.com>
" Version:  $Id: renumber.vim,v 1.4 2002/03/12 12:43:46 nabird Exp $
" Function: Renumber a block of numbers
" Args:     (any order)
"     s<step>  Increment number by 'step'
"     a        Search all of line for number, not just marked block columns
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
  let l = l1 | let cs = c1
  let line=getline(l)

  " Process args
  let step=1 | let all_line=0
  let argno = 1
  while argno <= a:0
    exe 'let arg = a:' . argno
    if arg =~ '^s\d\+$'
      let step = strpart(arg,1,strlen(arg)-1)
    elseif arg == 'a'
      let all_line = 1
    else
      echomsg 'Renumber: invalid argument "'.arg.'"'
      return
    endif
    let argno = argno + 1
  endwhile

  " Locate initial number (start at top-left of selected block)
  let ce = matchend( line, '[0-9]\+', cs ) - 1
  let cs = match( line, '[0-9]\+', cs )
  if cs == -1
    echomsg 'Renumber: no starting number found'
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
  let minsize = ce-cs+1

  " Now chomp zeros to we don't interpret number as octal!
  while strpart(line,cs,1) == '0'
    let cs = cs + 1
  endwhile
  if cs > ce
    let cs = ce
  endif
  let number  = strpart(line,cs,ce-cs+1)
  let endcol  = ce

  " Start cycling through rest of block
  let l = l + 1
  while l <= l2
    let line=getline(l)

    " Locate next number within marked block - try forwards from here
    let numberfound = 1
    let cs = ci
    while cs <= c2  &&  strpart(line,cs,1) !~ '[0-9]'
      let cs = cs + 1
    endwhile
    " See if found
    if cs > c2
      " Not found - try backwards
      let cs = ci
      while cs >= c1  &&  strpart(line,cs,1) !~ '[0-9]'
        let cs = cs - 1
      endwhile
      if cs < c1
        " Not found at all (within block)
        let numberfound = 0
      else
        " Found end - now find beginning
        let ce = cs
        while cs >= 0  &&  strpart(line,cs,1) =~ '[0-9]'
          let cs = cs - 1
        endwhile
        let cs = cs + 1
      endif
    else
      " Found number - make sure it's the start (might have hit the middle)
      while cs >= 0  &&  strpart(line,cs,1) =~ '[0-9]'
        let cs = cs - 1
      endwhile
      let cs = cs + 1
      " Find end
      let ce = cs
      while ce <= strlen(line)  &&  strpart(line,ce,1) =~ '[0-9]'
        let ce = ce + 1
      endwhile
      let ce = ce - 1
    endif

    " If not found, locate next number in whole line - try forwards from here
    if ! numberfound  &&  all_line
      let numberfound = 1
      let cs = ci
      while cs <= strlen(line)  &&  strpart(line,cs,1) !~ '[0-9]'
        let cs = cs + 1
      endwhile
      " See if found
      if cs > strlen(line)
        " Not found - try backwards
        let cs = ci
        while cs >= 0  &&  strpart(line,cs,1) !~ '[0-9]'
          let cs = cs - 1
        endwhile
        if cs < 0
          let numberfound = 0
        else
          " Found end - now find beginning
          let ce = cs
          while cs >= 0  &&  strpart(line,cs,1) =~ '[0-9]'
            let cs = cs - 1
          endwhile
          let cs = cs + 1
        endif
      else
        " Found start - find end
        let ce = cs
        while ce <= strlen(line)  &&  strpart(line,ce,1) =~ '[0-9]'
          let ce = ce + 1
        endwhile
        let ce = ce - 1
      endif
    endif

    " Found number to process?
    if numberfound

      " Now skip leading spaces we may need to change
      let cs = cs - 1
      while cs > 0  &&  strpart(line,cs,1) == ' '
        let cs = cs - 1
      endwhile
      let cs = cs + 1

      " Create number to insert:
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
        while strlen(this) < minsize
          let this = prepad . this
        endwhile
      endif
      let this = neg . this

      " Right-align the numbers
      while cs + strlen(this) <= endcol
        let this = ' ' . this
      endwhile

      " Change current line
      let line = strpart(line,0,cs) . this . strpart(line,ce+1,strlen(line)-ce+1)
      call setline( l, line )
    endif

    let l = l + 1
  endwhile
endfunction
command! -range -nargs=? Renumber  call Renumber(<f-args>)
