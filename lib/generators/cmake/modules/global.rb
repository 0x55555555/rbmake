RbMake.module(:global) do |l, p|
  l.debug_generate = true
  l.type = :dynamic_library
  l.sources = [ 'src/**/*', 'include/**/*' ]
  l.include_paths = [ 'include' ]
end