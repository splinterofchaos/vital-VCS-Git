"******************************************************************************
" A fundemental git manipulation library
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
"
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

" Vital ======================================================================
function! s:_vital_loaded(V) dict abort " {{{
  let s:Dict = a:V.import('Data.Dict')
  let s:List = a:V.import('Data.List')
  let s:Prelude = a:V.import('Prelude')
  let s:Path = a:V.import('System.Filepath')
  let s:Cache = a:V.import('System.Cache.Simple')
  let s:Core = a:V.import('VCS.Git.Core')
  let s:Misc = a:V.import('VCS.Git.Misc')
  let s:Finder = a:V.import('VCS.Git.Finder')

  let s:SEPARATOR = s:Path.separator()
endfunction " }}}
function! s:_vital_depends() abort " {{{
  return [
        \ 'System.Cache.Simple',
        \ 'VCS.Git.Core',
        \ 'VCS.Git.Misc',
        \ 'VCS.Git.Finder',
        \]
endfunction " }}}
function! s:_listalize(val) abort " {{{
  return s:Prelude.is_list(a:val) ? a:val : [a:val]
endfunction " }}}

function! s:_get_finder() abort " {{{
  if !exists('s:finder')
    let s:finder = s:Finder.new(s:_get_finder_cache())
  endif
  return s:finder
endfunction " }}}
function! s:_get_finder_cache() abort " {{{
  if !exists('s:finder_cache')
    let config = s:get_config()
    let s:finder_cache = call(
          \ config.cache.finder.new,
          \ config.cache.finder_args,
          \ config.cache.finder,
          \)
  endif
  return s:finder_cache
endfunction " }}}
function! s:_get_instance_cache() abort " {{{
  if !exists('s:instance_cache')
    let config = s:get_config()
    let s:instance_cache = call(
          \ config.cache.instance.new,
          \ config.cache.instance_args,
          \ config.cache.instance,
          \)
  endif
  return s:instance_cache
endfunction " }}}

let s:config = {}
function! s:get_config() abort " {{{
  let default = {
        \ 'cache': {
        \   'finder':   s:Cache,
        \   'instance': s:Cache,
        \   'repository': s:Cache,
        \   'uptime':   s:Cache,
        \   'finder_args': [],
        \   'instance_args': [],
        \   'repository_args': [],
        \   'uptime_args': [],
        \ },
        \}
  return extend(default, deepcopy(s:config))
endfunction " }}}
function! s:set_config(config) abort " {{{
  let s:config = extend(s:config, a:config)
  " clear settings
  unlet! s:finder_cache
  unlet! s:finder
  unlet! s:instance_cache
  " apply settings
  call s:Core.set_config(s:config)
endfunction " }}}
function! s:new(worktree, repository, ...) abort " {{{
  let opts = extend({ 'no_cache': 0 }, get(a:000, 0, {}))
  let cache = s:_get_instance_cache()
  let git = cache.get(a:worktree, {})
  if !empty(git) && !opts.no_cache
    return git
  endif
  let config = s:get_config()
  let git = extend(deepcopy(s:git), {
        \ 'worktree': a:worktree,
        \ 'repository': a:repository,
        \ 'cache': {
        \   'repository': call(
        \     config.cache.repository.new,
        \     config.cache.repository_args,
        \     config.cache.repository
        \   ),
        \   'uptime': call(
        \     config.cache.uptime.new,
        \     config.cache.uptime_args,
        \     config.cache.uptime
        \   ),
        \ }
        \})
  call cache.set(a:worktree, git)
  return git
endfunction " }}}
function! s:find(path, ...) abort " {{{
  let options = get(a:000, 0, {})
  let finder = s:_get_finder()
  let found = finder.find(a:path, options)
  if empty(found)
    return {}
  endif
  return s:new(found.worktree, found.repository, options)
endfunction " }}}

" Object =====================================================================
let s:git = {}
function! s:git.is_updated(pathspec, ...) abort " {{{
  let pathspec = s:_listalize(a:pathspec)
  let path = s:Path.join(pathspec)
  let name = printf('%s%s%s', path, s:SEPARATOR, get(a:000, 0, ''))
  let cached = self.cache.uptime.get(name, -1)
  let actual = getftime(s:Path.join(self.repository, path))
  call self.cache.uptime.set(name, actual)
  return actual == -1 || actual > cached
endfunction " }}}
function! s:git._get_call_opts(...) abort " {{{
  return extend({
        \ 'cwd': self.worktree,
        \}, get(a:000, 0, {}))
endfunction " }}}

" VCS.Git.Core
function! s:git.get_relative_path(path) abort " {{{
  return s:Core.get_relative_path(self.worktree, a:path)
endfunction " }}}
function! s:git.get_absolute_path(path) abort " {{{
  return s:Core.get_absolute_path(self.worktree, a:path)
endfunction " }}}
function! s:git.get_head(...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let name = 'HEAD'
  let cache = self.cache.repository
  if self.is_updated(name) || options.no_cache || !cache.has(name)
    let result = s:Core.get_head(self.repository)
    call cache.set(name, result)
  endif
  return cache.get(name)
endfunction " }}}
function! s:git.get_fetch_head(...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let name = 'FETCH_HEAD'
  let cache = self.cache.repository
  if self.is_updated(name) || options.no_cache || !cache.has(name)
    let result = s:Core.get_fetch_head(self.repository)
    call cache.set(name, result)
  endif
  return cache.get(name)
endfunction " }}}
function! s:git.get_orig_head(...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let name = 'ORIG_HEAD'
  let cache = self.cache.repository
  if self.is_updated(name) || options.no_cache || !cache.has(name)
    let result = s:Core.get_orig_head(self.repository)
    call cache.set(name, result)
  endif
  return cache.get(name)
endfunction " }}}
function! s:git.get_merge_head(...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let name = 'MERGE_HEAD'
  let cache = self.cache.repository
  if self.is_updated(name) || options.no_cache || !cache.has(name)
    let result = s:Core.get_merge_head(self.repository)
    call cache.set(name, result)
  endif
  return cache.get(name)
endfunction " }}}
function! s:git.get_commit_editmsg(...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let name = 'COMMIT_EDITMSG'
  let cache = self.cache.repository
  if self.is_updated(name) || options.no_cache || !cache.has(name)
    let result = s:Core.get_commit_editmsg(self.repository)
    call cache.set(name, result)
  endif
  return cache.get(name)
endfunction " }}}
function! s:git.get_merge_msg(...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let name = 'MERGE_MSG'
  let cache = self.cache.repository
  if self.is_updated(name) || options.no_cache || !cache.has(name)
    let result = s:Core.get_merge_msg(self.repository)
    call cache.set(name, result)
  endif
  return cache.get(name)
endfunction " }}}
function! s:git.get_local_hash(branch, ...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let name = s:Path.join('refs', 'heads', a:branch)
  let cache = self.cache.repository
  if self.is_updated(name) || options.no_cache || !cache.has(name)
    let result = s:Core.get_local_hash(self.repository, a:branch)
    call cache.set(name, result)
  endif
  return cache.get(name)
endfunction " }}}
function! s:git.get_remote_hash(remote, branch, ...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let name = s:Path.join('refs', 'remotes', a:remote, a:branch)
  let cache = self.cache.repository
  if self.is_updated(name) || options.no_cache || !cache.has(name)
    let result = s:Core.get_remote_hash(self.repository, a:remote, a:branch)
    call cache.set(name, result)
  endif
  return cache.get(name)
endfunction " }}}
function! s:git.get_repository_config(...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let name = 'config'
  let cache = self.cache.repository
  if self.is_updated(name) || options.no_cache || !cache.has(name)
    let result = s:Core.get_repository_config(self.repository)
    call cache.set(name, result)
  endif
  return cache.get(name)
endfunction " }}}
function! s:git.get_branch_remote(branch, ...) abort " {{{
  let config = call(self.get_repository_config, a:000, self)
  return s:Core.get_branch_remote(config, a:branch)
endfunction " }}}
function! s:git.get_branch_merge(branch, ...) abort " {{{
  let config = call(self.get_repository_config, a:000, self)
  return s:Core.get_branch_merge(config, a:branch)
endfunction " }}}
function! s:git.get_remote_fetch(remote, ...) abort " {{{
  let config = call(self.get_repository_config, a:000, self)
  return s:Core.get_remote_fetch(config, a:remote)
endfunction " }}}
function! s:git.get_remote_url(remote, ...) abort " {{{
  let config = call(self.get_repository_config, a:000, self)
  return s:Core.get_remote_url(config, a:remote)
endfunction " }}}
function! s:git.get_comment_char(...) abort " {{{
  let config = call(self.get_repository_config, a:000, self)
  return s:Core.get_comment_char(config)
endfunction " }}}
function! s:git.exec(args, ...) abort " {{{
  let opts = extend(self._get_call_opts(), get(a:000, 0, {}))
  return s:Core.exec(a:args, opts)
endfunction " }}}

" VCS.Git.Misc
function! s:git.get_parsed_status(...) abort " {{{
  let options = self._get_call_opts(extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {})))
  let opts = s:Dict.omit(options, ['no_cache'])
  let name = s:Path.join('index', 'parsed_status', string(opts))
  let cache = self.cache.repository
  let result = (self.is_updated('index', 'status') || options.no_cache)
        \ ? {}
        \ : cache.get(name, {})
  if empty(result)
    let result = s:Misc.get_parsed_status(opts)
    call cache.set(name, result)
  endif
  return result
endfunction " }}}
function! s:git.get_parsed_commit(...) abort " {{{
  let options = self._get_call_opts(extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {})))
  let opts = s:Dict.omit(options, ['no_cache'])
  let name = s:Path.join('index', 'parsed_commit', string(opts))
  let cache = self.cache.repository
  let result = (self.is_updated('index', 'commit') || options.no_cache)
        \ ? {}
        \ : cache.get(name, {})
  if empty(result)
    let result = s:Misc.get_parsed_commit(opts)
    call cache.set(name, result)
  endif
  return result
endfunction " }}}
function! s:git.get_parsed_config(...) abort " {{{
  let options = self._get_call_opts(extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {})))
  let opts = s:Dict.omit(options, ['no_cache'])
  let name = s:Path.join('index', 'parsed_config', string(opts))
  let cache = self.cache.repository
  let result = (self.is_updated('index', 'config') || options.no_cache)
        \ ? {}
        \ : cache.get(name, {})
  if empty(result)
    let result = s:Misc.get_parsed_config(opts)
    call cache.set(name, result)
  endif
  return result
endfunction " }}}
function! s:git.get_last_commitmsg(...) abort " {{{
  let options = self._get_call_opts(extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {})))
  let opts = s:Dict.omit(options, ['no_cache'])
  let name = s:Path.join('index', 'last_commitmsg', string(opts))
  let cache = self.cache.repository
  let result = (self.is_updated('index', 'last_commitmsg') || options.no_cache)
        \ ? []
        \ : cache.get(name, [])
  if empty(result)
    unlet! result
    let result = s:Misc.get_last_commitmsg(opts)
    call cache.set(name, result)
  endif
  return result
endfunction " }}}
function! s:git.count_commits_ahead_of_remote(...) abort " {{{
  let options = self._get_call_opts(extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {})))
  let opts = s:Dict.omit(options, ['no_cache'])
  let name = s:Path.join('index', 'commits_ahead_of_remote', string(opts))
  let cache = self.cache.repository
  let result = (self.is_updated('index', 'commits_ahead_of_remote') || options.no_cache)
        \ ? -1
        \ : cache.get(name, -1)
  if result == -1
    let result = s:Misc.count_commits_ahead_of_remote(opts)
    call cache.set(name, result)
  endif
  return result
endfunction " }}}
function! s:git.count_commits_behind_remote(...) abort " {{{
  let options = self._get_call_opts(extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {})))
  let opts = s:Dict.omit(options, ['no_cache'])
  let name = s:Path.join('index', 'commits_behind_remote', string(opts))
  let cache = self.cache.repository
  let result = (self.is_updated('index', 'commits_behind_remote') || options.no_cache)
        \ ? -1
        \ : cache.get(name, -1)
  if result == -1
    let result = s:Misc.count_commits_behind_remote(opts)
    call cache.set(name, result)
  endif
  return result
endfunction " }}}

" Helper
function! s:git.get_meta() abort " {{{
  let meta = {}
  let meta.head = self.get_head()
  let meta.fetch_head = self.get_fetch_head()
  let meta.orig_head = self.get_orig_head()
  let meta.merge_head = self.get_merge_head()
  let meta.commit_editmsg = self.get_commit_editmsg()
  let meta.last_commitmsg =
        \ empty(meta.commit_editmsg)
        \ ? self.get_last_commitmsg()
        \ : meta.commit_editmsg
  let meta.merge_msg = self.get_merge_msg()
  let meta.current_branch = meta.head =~? 'refs/heads/'
        \ ? matchstr(meta.head, 'refs/heads/\zs.\+$')
        \ : meta.head[:6]
  let meta.current_branch_hash = self.get_local_hash(meta.current_branch)
  let meta.repository_config = self.get_repository_config()
  let meta.current_branch_remote = self.get_branch_remote(meta.current_branch)
  let meta.current_branch_merge = self.get_branch_merge(meta.current_branch)
  let meta.current_remote_fetch = self.get_remote_fetch(meta.current_branch_remote)
  let meta.current_remote_url = self.get_remote_url(meta.current_branch_remote)
  let meta.comment_char = self.get_comment_char()
  let meta.current_remote_branch = matchstr(meta.current_branch_merge, 'refs/heads/\zs.\+$')
  let meta.current_remote_branch_hash = self.get_remote_hash(
        \ meta.current_branch_remote,
        \ meta.current_remote_branch,
        \)
  let meta.commits_ahead_of_remote = self.count_commits_ahead_of_remote()
  let meta.commits_behind_remote = self.count_commits_behind_remote()
  return meta
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
