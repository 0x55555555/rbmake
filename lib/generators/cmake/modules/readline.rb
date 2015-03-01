require 'modules/global'

RbMake.library(:readline, :global) do |l|
  l.extend_with(:cpp)

  l.generate = false

  l.export do |l|
    l.libraries = [ '/usr/local/Cellar/readline/6.3.8/lib/libreadline.dylib' ]
    l.include_paths = [ '/usr/local/Cellar/readline/6.3.8/include/' ]
  end
end