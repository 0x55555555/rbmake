
module RbMake

def self.module(name, parent=nil, &blk)
  parent_object = $registry.lookup_module(parent)
  impl = Impl::Module.new($registry, name, parent_object)
  impl.build(caller, blk)
end


def self.library(name, parent=nil, &blk)
  parent_object = $registry.lookup_module(parent)
  impl = Impl::Library.new($registry, name, parent_object)
  impl.build(caller, blk)
end

def self.test(name, parent=nil, &blk)
  raise "Invalid module to test '#{name}'" unless $registry.lookup_module(name)
  test_name = (name.to_s + "Test").to_sym
  parent_object = $registry.lookup_module(parent)
  impl = Impl::Library.new($registry, test_name, parent_object)

  full_blk = Proc.new do |l, p|
    blk.call(l, p)  
    impl.type = :test
    impl.dependencies << name
  end

  impl.build(caller, full_blk) 
end

def self.import_module(name, raise_on_fail=true)
  src = name
  if (!File.exist?(src) || Dir.exist?(src))
    file, line = Impl::Utils.caller_file()
    relative_dir = File.dirname(file)
    base = File.basename(name)
    src = "#{relative_dir}/#{name}/#{base}.rb"
  end
  if (File.exist?(src))
    $registry.log "Import #{name}"
    require(src)
  else
    if (raise_on_fail)
      raise "Invalid module #{name} (#{src})"
    end
  end
end

def self.import_modules(pattern)
  file, line = Impl::Utils.caller_file()
  relative_dir = File.dirname(file)
  pattern = "#{relative_dir}/#{pattern}"
  $registry.log "Importing #{pattern}"
  Dir[pattern].each do |e|
    if (!Dir.exist?(e))
      next
    end
    name = File.basename(e)
    path = e + "/#{name}.rb"
    import_module(path, false)
  end
end

end