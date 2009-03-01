#
# This file is automatically generated. DO NOT MODIFY!
#
# install.rb
#
#   Copyright (c) 2000,2001 Minero Aoki <aamine@loveruby.net>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU Lesser General Public License version 2.
#

unless $".include? 'setup/compat.rb' then
  $".push 'setup/compat.rb'
### begin compat.rb

unless Enumerable.instance_methods.include? 'inject' then
    module Enumerable
      def inject( result )
        each do |i|
          result = yield( result, i )
        end
        result
      end
    end
end

### end compat.rb
end
unless $".include? 'setup/config.rb' then
  $".push 'setup/config.rb'
### begin config.rb

if i = ARGV.index(/\A--rbconfig=/) then
  file = $'
  ARGV.delete_at(i)
  require file
else
  require 'rbconfig'
end


class ConfigTable

  c = ::Config::CONFIG

  rubypath = c['bindir'] + '/' + c['ruby_install_name']

  major = c['MAJOR'].to_i
  minor = c['MINOR'].to_i
  teeny = c['TEENY'].to_i
  version = "#{major}.#{minor}"

  # ruby version >= 3.0.2 ?
  newpath_p = ((major >= 2) or
               ((major == 1) and
                ((minor >= 5) or
                 ((minor == 4) and (teeny >= 4)))))
  
  if c['rubylibdir'] then
    # V > 1.6.3
    stdruby    = c['rubylibdir'] .sub( c['prefix'], '$prefix' )
    siteruby   = c['sitelibdir'] .sub( c['prefix'], '$prefix' )
    sodir      = c['sitearchdir'].sub( c['prefix'], '$prefix' )
  elsif newpath_p then
    # 1.4.4 <= V <= 1.6.3
    stdruby    = "$prefix/lib/ruby/#{version}"
    siteruby   = c['sitedir'].sub( c['prefix'], '$prefix' ) + '/' + version
    sodir      = "$site-ruby/#{c['arch']}"
  else
    # V < 1.4.4
    stdruby    = "$prefix/lib/ruby/#{version}"
    siteruby   = "$prefix/lib/ruby/#{version}/site_ruby"
    sodir      = "$site-ruby/#{c['arch']}"
  end

  DESCRIPTER = [
    [ 'prefix',    [ c['prefix'],
                     'path',
                     'path prefix' ] ],
    [ 'std-ruby',  [ stdruby,
                     'path',
                     'the directory for standard ruby libraries' ] ],
    [ 'site-ruby', [ siteruby,
                     'path',
                     'the directory for non-standard ruby libraries' ] ],
    [ 'bin-dir',   [ '$prefix/bin',
                     'path',
                     'the directory for commands' ] ],
    [ 'rb-dir',    [ '$site-ruby',
                     'path',
                     'the directory for ruby scripts' ] ],
    [ 'so-dir',    [ sodir,
                     'path',
                     'the directory for ruby extentions' ] ],
    [ 'data-dir',  [ '$prefix/share',
                     'path',
                     'the directory for shared data' ] ],
    [ 'ruby-path', [ rubypath,
                     'path',
                     'path to set to #! line' ] ],
    [ 'ruby-prog', [ rubypath,
                     'path',
                     'the ruby program using for installation' ] ],
    [ 'make-prog', [ 'make',
                     'name',
                     'the make program to compile ruby extentions' ] ],
  ]

  def self.each_name( &block )
    keys().each( &block )
  end

  def self.keys
    DESCRIPTER.collect {|k,*dummy| k }
  end


  SAVE_FILE = 'config.save'

  def self.create
    c = new()
    c.init
    c
  end

  def self.load
    c = new()
    File.file? SAVE_FILE or
            raise InstallError, "#{File.basename $0} config first"
    File.foreach( SAVE_FILE ) do |line|
      k, v = line.split( '=', 2 )
      c.noproc_set k, v.strip
    end
    c
  end

  def initialize
    @table = {}
  end

  def init
    DESCRIPTER.each do |k, (default, vname, desc, default2)|
      @table[k] = default
    end
  end

  def save
    File.open( SAVE_FILE, 'w' ) do |f|
      @table.each do |k, v|
        f.printf "%s=%s\n", k, v if v
      end
    end
  end

  def []=( k, v )
    d = DESCRIPTER.assoc(k) or
            raise InstallError, "unknown config option #{k}"
    if d[1][1] == 'path' and v[0,1] != '$' then
      @table[k] = File.expand_path(v)
    else
      @table[k] = v
    end
  end
    
  def []( key )
    @table[key] and @table[key].sub( %r_\$([^/]+)_ ) { self[$1] }
  end

  def noproc_set( key, val )
    @table[key] = val
  end

  def noproc_get( key )
    @table[key]
  end

end

### end config.rb
end
unless $".include? 'setup/fileop.rb' then
  $".push 'setup/fileop.rb'
### begin fileop.rb

module FileOperations

  def isdir( dn )
    mkdir_p dn
    dn
  end

  def mkdir_p( dname )
    $stderr.puts "mkdir -p #{dname}" if verbose?
    return if no_harm?

    # does not check '/'... it's too abnormal case
    dirs = dname.split(%r_(?=/)_)
    if /\A[a-z]:\z/i === dirs[0] then
      disk = dirs.shift
      dirs[0] = disk + dirs[0]
    end
    dirs.each_index do |idx|
      path = dirs[0..idx].join('')
      Dir.mkdir path unless dir? path
    end
  end

  def rm_f( fname )
    $stderr.puts "rm -f #{fname}" if verbose?
    return if no_harm?

    if File.exist? fname or File.symlink? fname then
      File.chmod 0777, fname
      File.unlink fname
    end
  end

  def rm_rf( dn )
    $stderr.puts "rm -rf #{dn}" if verbose?
    return if no_harm?

    Dir.chdir dn
    Dir.foreach('.') do |fn|
      next if fn == '.'
      next if fn == '..'
      if dir? fn then
        verbose_off {
          rm_rf fn
        }
      else
        verbose_off {
          rm_f fn
        }
      end
    end
    Dir.chdir '..'
    Dir.rmdir dn
  end

  def mv( src, dest )
    rm_f dest
    begin
      File.link src, dest
    rescue
      File.open( dest, 'wb' ) {|w|
          File.open(src, 'rb') {|r| w.write r.read }
      }
      File.chmod File.stat(src).mode, dest
    end
    rm_f src
  end

  def install( from, to, mode )
    $stderr.puts "install #{from} #{to}" if verbose?
    return if no_harm?

    if dir? to then
      to = to + '/' + File.basename(from)
    end
    str = nil
    File.open( from, 'rb' ) {|f| str = f.read }
    if diff? str, to then
      verbose_off {
        rm_f to if File.exist? to
      }
      File.open( to, 'wb' ) {|f| f.write str }
      File.chmod mode, to

      File.open( objdir + '/InstalledFiles', 'a' ) {|f| f.puts to }
    end
  end

  def diff?( orig, comp )
    return true unless File.exist? comp
    s2 = nil
    File.open( comp, 'rb' ) {|f| s2 = f.read }
    orig != s2
  end

  def command( str )
    $stderr.puts str if verbose?
    system str or raise RuntimeError, "'system #{str}' failed"
  end

  def ruby( str )
    command config('ruby-prog') + ' ' + str
  end

  def dir?( dname )
    # for corrupted windows stat()
    File.directory?( (dname[-1,1] == '/') ? dname : dname + '/' )
  end

  def all_files( dname )
    Dir.open( dname ) {|d|
      return d.find_all {|n| File.file? "#{dname}/#{n}" }
    }
  end

  def all_dirs( dname )
    Dir.open( dname ) {|d|
      return d.find_all {|n| dir? "#{dname}/#{n}" } - %w(. ..)
    }
  end

end

### end fileop.rb
end
unless $".include? 'setup/base.rb' then
  $".push 'setup/base.rb'
### begin base.rb

class InstallError < StandardError; end


class Installer

  Version   = '3.0.2'
  Copyright = 'Copyright (c) 2000,2001 Minero Aoki'


  @toplevel = nil

  def self.declear_toplevel_installer( inst )
    @toplevel and
        raise ArgumentError, 'more than one toplevel installer decleared'
    @toplevel = inst
  end

  def self.toplevel_installer
    @toplevel
  end


  FILETYPES = %w( bin lib ext data )

  include FileOperations

  def initialize( config, opt, srcroot, objroot )
    @config = config
    @options = opt
    @srcdir = File.expand_path(srcroot)
    @objdir = File.expand_path(objroot)
    @currdir = '.'
  end

  def inspect
    "#<#{type} #{__id__}>"
  end

  #
  # configs/options
  #

  def config( key )
    @config[key]
  end

  def no_harm?
    @options['no-harm']
  end

  def verbose?
    @options['verbose']
  end

  def verbose_off
    save, @options['verbose'] = @options['verbose'], false
    yield
    @options['verbose'] = save
  end

  #
  # srcdir/objdir
  #

  attr_reader :srcdir
  alias srcdir_root srcdir
  alias package_root srcdir

  def curr_srcdir
    "#{@srcdir}/#{@currdir}"
  end

  attr_reader :objdir
  alias objdir_root objdir

  def curr_objdir
    "#{@objdir}/#{@currdir}"
  end

  def srcfile( path )
    curr_srcdir + '/' + path
  end

  def srcexist?( path )
    File.exist? srcfile(path)
  end

  def srcdirectory?( path )
    dir? srcfile(path)
  end
  
  def srcfile?( path )
    File.file? srcfile(path)
  end

  def srcentries( path = '.' )
    Dir.open( curr_srcdir + '/' + path ) {|d|
        return d.to_a - %w(. ..) - hookfilenames
    }
  end

  def srcfiles( path = '.' )
    srcentries(path).find_all {|fname|
        File.file? File.join(curr_srcdir, path, fname)
    }
  end

  def srcdirectories( path = '.' )
    srcentries(path).find_all {|fname|
        dir? File.join(curr_srcdir, path, fname)
    }
  end

  def dive_into( rel )
    return unless dir? "#{@srcdir}/#{rel}"

    dir = File.basename(rel)
    Dir.mkdir dir unless dir? dir
    save = Dir.pwd
    Dir.chdir dir
    $stderr.puts '---> ' + rel if verbose?
    @currdir = rel
    yield
    Dir.chdir save
    $stderr.puts '<--- ' + rel if verbose?
    @currdir = File.dirname(rel)
  end

  #
  # config
  #

  def exec_config
    exec_task_traverse 'config'
  end

  def config_dir_bin( rel )
  end

  def config_dir_lib( rel )
  end

  def config_dir_ext( rel )
    extconf if extdir? curr_srcdir
  end

  def extconf
    opt = @options['config-opt'].join(' ')
    command "#{config('ruby-prog')} #{curr_srcdir}/extconf.rb #{opt}"
  end

  def config_dir_data( rel )
  end

  #
  # setup
  #

  def exec_setup
    exec_task_traverse 'setup'
  end

  def setup_dir_bin( relpath )
    all_files( curr_srcdir ).each do |fname|
      add_rubypath "#{curr_srcdir}/#{fname}"
    end
  end

  SHEBANG_RE = /\A\#!\s*\S*ruby\S*/

  def add_rubypath( path )
    $stderr.puts %Q<set #! line to "\#!#{config('ruby-path')}" for #{path} ...> if verbose?
    return if no_harm?

    tmpfile = File.basename(path) + '.tmp'
    begin
      File.open( path ) {|r|
      File.open( tmpfile, 'w' ) {|w|
        first = r.gets
        return unless SHEBANG_RE === first   # reject '/usr/bin/env ruby'

        w.print first.sub( SHEBANG_RE, '#!' + config('ruby-path') )
        w.write r.read
      } }
      mv tmpfile, File.basename(path)
    ensure
      rm_f tmpfile if File.exist? tmpfile
    end
  end

  def setup_dir_lib( relpath )
  end

  def setup_dir_ext( relpath )
    if extdir? curr_srcdir then
      make
    end
  end

  def make
    command config('make-prog')
  end

  def setup_dir_data( relpath )
  end

  #
  # install
  #

  def exec_install
    exec_task_traverse 'install'
  end

  def install_dir_bin( rel )
    install_files targfiles, config('bin-dir') + '/' + rel, 0755
  end

  def install_dir_lib( rel )
    install_files targfiles, config('rb-dir') + '/' + rel, 0644
  end

  def install_dir_ext( rel )
    if extdir? curr_srcdir then
      install_dir_ext_main File.dirname(rel)
    end
  end

  def install_dir_ext_main( rel )
    install_files allext('.'), config('so-dir') + '/' + rel, 0555
  end

  def install_dir_data( rel )
    install_files targfiles, config('data-dir') + '/' + rel, 0644
  end

  def install_files( list, dest, mode )
    mkdir_p dest
    list.each do |fname|
      install fname, dest, mode
    end
  end
  
  def targfiles
    (targfilenames - hookfilenames).collect {|fname|
        File.exist?(fname) ? fname : File.join(curr_srcdir, fname)
    }
  end

  def targfilenames
    [ curr_srcdir, '.' ].inject([]) {|ret, dir|
        ret | all_files(dir)
    }
  end

  def hookfilenames
    %w( pre-%s post-%s pre-%s.rb post-%s.rb ).collect {|fmt|
        %w( config setup install clean ).collect {|t| sprintf fmt, t }
    }.flatten
  end

  def allext( dir )
    _allext(dir) or raise InstallError,
        "no extention exists: Have you done 'ruby #{$0} setup' ?"
  end

  DLEXT = /\.#{ ::Config::CONFIG['DLEXT'] }\z/

  def _allext( dir )
    Dir.open( dir ) {|d|
      return d.find_all {|fname| DLEXT === fname }
    }
  end

  #
  # clean
  #

  def exec_clean
    exec_task_traverse 'clean'
    rm_f 'config.save'
    rm_f 'InstalledFiles'
  end

  def clean_dir_bin( rel )
  end

  def clean_dir_lib( rel )
  end

  def clean_dir_ext( rel )
    clean
  end
  
  def clean
    command config('make-prog') + ' clean' if File.file? 'Makefile'
  end

  def clean_dir_data( rel )
  end

  #
  # lib
  #

  def exec_task_traverse( task )
    run_hook 'pre-' + task
    FILETYPES.each do |type|
      traverse task, type, task + '_dir_' + type
    end
    run_hook 'post-' + task
  end

  def traverse( task, rel, mid )
    dive_into( rel ) {
      run_hook 'pre-' + task
      __send__ mid, rel.sub( %r_\A.*?(?:/|\z)_, '' )
      all_dirs( curr_srcdir ).each do |d|
        traverse task, rel + '/' + d, mid
      end
      run_hook 'post-' + task
    }
  end

  def run_hook( name )
    try_run_hook curr_srcdir + '/' + name           or
    try_run_hook curr_srcdir + '/' + name + '.rb'
  end

  def try_run_hook( fname )
    return false unless File.file? fname

    env = self.dup
    s = nil
    File.open( fname ) {|f| s = f.read }
    begin
      env.instance_eval s, fname, 1
    rescue
      raise InstallError, "hook #{fname} failed:\n" + $!.message
    end
    true
  end

  def extdir?( dir )
    File.exist? dir + '/MANIFEST'
  end

end

### end base.rb
end
unless $".include? 'setup/toplevel.rb' then
  $".push 'setup/toplevel.rb'
### begin toplevel.rb

class ToplevelInstaller < Installer

  TASKS = [
    [ 'config',   'saves your configurations' ],
    [ 'show',     'shows current configuration' ],
    [ 'setup',    'compiles extention or else' ],
    [ 'install',  'installs files' ],
    [ 'clean',    "does `make clean' for each extention" ]
  ]


  def initialize( argv, root )
    @argv = argv
    super nil, {'verbose' => true}, root, '.'

    Installer.declear_toplevel_installer self
  end


  def execute
    argv = @argv
    @argv = nil
    task = parsearg_global( argv )

    case task
    when 'config'
      @config = ConfigTable.create
    else
      @config = ConfigTable.load
    end
    parsearg_TASK task, argv

    exectask task
  end

  def exectask( task )
    if task == 'show' then
      exec_show
    else
      try task
    end
  end

  def try( task )
    $stderr.printf "#{File.basename $0}: entering %s phase...\n", task if verbose?
    begin
      __send__ 'exec_' + task
    rescue
      $stderr.printf "%s failed\n", task
      raise
    end
    $stderr.printf "#{File.basename $0}: %s done.\n", task if verbose?
  end

  #
  # processing arguments
  #

  def parsearg_global( argv )
    task_re = /\A(?:#{TASKS.collect {|i| i[0] }.join '|'})\z/

    while arg = argv.shift do
      case arg
      when /\A\w+\z/
        task_re === arg or raise InstallError, "wrong task: #{arg}"
        return arg

      when '-q', '--quiet'
        @options['verbose'] = false

      when       '--verbose'
        @options['verbose'] = true

      when '-h', '--help'
        print_usage $stdout
        exit 0

      when '-v', '--version'
        puts "#{File.basename $0} version #{Version}"
        exit 0
      
      when '--copyright'
        puts Copyright
        exit 0

      when nil
        raise InstallError, 'no task given'

      else
        raise InstallError, "unknown global option '#{arg}'"
      end
    end
  end


  def parsearg_TASK( task, argv )
    mid = "parsearg_#{task}"
    if respond_to? mid, true then
      __send__ mid, argv
    else
      argv.empty? or
          raise InstallError, "#{task}:  unknown options: #{argv.join ' '}"
    end
  end

  def parsearg_config( args )
    re = /\A--(#{ConfigTable.keys.join '|'})=/
    @options['config-opt'] = []

    while i = args.shift do
      if /\A--?\z/ === i then
        @options['config-opt'] = args
        break
      end
      m = re.match(i) or raise InstallError, "config: unknown option #{i}"
      @config[ m[1] ] = m.post_match
    end
  end

  def parsearg_install( args )
    @options['no-harm'] = false
    args.each do |i|
      if i == '--no-harm' then
        @options['no-harm'] = true
      else
        raise InstallError, "install: unknown option #{i}"
      end
    end
  end


  def print_usage( out )
    out.puts
    out.puts 'Usage:'
    out.puts "  ruby #{File.basename $0} <global option>"
    out.puts "  ruby #{File.basename $0} <task> [<task options>]"

    fmt = "  %-20s %s\n"
    out.puts
    out.puts 'Global options:'
    out.printf fmt, '-q,--quiet',   'suppress message outputs'
    out.printf fmt, '   --verbose', 'output messages verbosely'
    out.printf fmt, '-h,--help',    'print this message'
    out.printf fmt, '-v,--version', 'print version and quit'
    out.printf fmt, '--copyright',  'print copyright and quit'

    out.puts
    out.puts 'Tasks:'
    TASKS.each do |name, desc|
      out.printf "  %-10s  %s\n", name, desc
    end

    out.puts
    out.puts 'Options for config:'
    ConfigTable::DESCRIPTER.each do |name, (default, arg, desc, default2)|
      default = default2 || default
      out.printf "  %-20s %s [%s]\n", "--#{name}=#{arg}", desc, default
    end
    out.printf "  %-20s %s [%s]\n",
        '--rbconfig=path', 'your rbconfig.rb to load', "running ruby's"

    out.puts
    out.puts 'Options for install:'
    out.printf "  %-20s %s [%s]\n",
        '--no-harm', 'only display what to do if given', 'off'

    out.puts
  end

  #
  # config
  #

  def exec_config
    super
    @config.save
  end

  #
  # show
  #

  def exec_show
    ConfigTable.each_name do |k|
      v = @config.noproc_get(k)
      if not v or v.empty? then
        v = '(not specified)'
      end
      printf "%-10s %s\n", k, v
    end
  end

end

### end toplevel.rb
end

if $0 == __FILE__ then
  begin
    installer = ToplevelInstaller.new( ARGV.dup, File.dirname($0) )
    installer.execute
  rescue
    raise if $DEBUG
    $stderr.puts $!.message
    $stderr.puts "try 'ruby #{$0} --help' for usage"
    exit 1
  end
end