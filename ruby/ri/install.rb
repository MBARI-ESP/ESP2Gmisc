require 'rbconfig'
require 'find'
require 'ftools'

include Config

# always use the refdoc.rb in the ri subdirectory in the
# installaton, rather than one that may be in the path.
# That way, if the interface to refdoc changes between releases,
# the installation procedure will find the correct one

myPath = File::dirname(__FILE__)
require File.join(myPath, 'ri', 'refdoc.rb')

#
# This sets up a standard environment for any sub-installs as well

$version = CONFIG["MAJOR"]+"."+CONFIG["MINOR"]
$libdir = File.join(CONFIG["libdir"], "ruby", $version)

$bindir =  CONFIG["bindir"]
$sitedir = CONFIG["sitedir"] || File.join($libdir, "site_ruby")

$realbindir = $bindir

if (destdir = ENV['DESTDIR'])
  $libdir = destdir + $libdir
  $bindir = destdir + $bindir
  $sitedir = destdir + $sitedir
  
  File::makedirs($libdir)
  File::makedirs($bindir)
  File::makedirs($sitedir)
end

$ri_dest = File.join($sitedir, "ri")
$ri_op = File.join($ri_dest, "op")


# This is old stuff, but we need it to get tidy up a previous installation

$site_libdir = $:.find {|x| x =~ /site_ruby$/}

if !$site_libdir
  $site_libdir = File.join($libdir, "site_ruby")
elsif $site_libdir !~ Regexp.quote($version)
  $site_libdir = File.join($site_libdir, $version)
end


##
# Install an output formatter
#

def installOP(name)
  File::install(name, File.join($ri_op, name), 0644, true)
end

##
# Install a binary file. We patch in on the way through to
# insert a #! line. If this is a Unix install, we name
# the command (for example) 'ri' and let the shebang line
# handle running it. Under windows, we add a '.rb' extension
# and let file associations to their stuff
#

def installBIN(from, opfile)
  
  File.open(from) do |ip|
    File.open("ri_tmp", "w") do |op|
      ruby = File.join($realbindir, "ruby")
      op.puts "#!#{ruby}"
      op.write ip.read
    end
  end

  opfile += ".rb" if CONFIG["target_os"] =~ /win/
  File::install("ri_tmp", File.join($bindir, opfile), 0755, true)
  File::unlink("ri_tmp")
end

##
# Standard installation for 'contrib' code. Their install.rb should set up
# the arrays $op_files, $emacs_files, and so on, and we do the actual
# installation

def installContrib

  # Binary files go in bindir
  if $bin_files
    $bin_files.each do |fname, cmd|
      installBIN(fname, cmd)
    end
  end

  # OP files are easy
  if $op_files
    $op_files.each do |fname|
      installOP(fname)
    end
  end

  # Emacs files are a tad trickier
  if $emacs_files
    puts "This contribution includes Emacs lisp files."
    copied = false
    elispdir = nil

    %w{ emacs lisp }.each do |name|
      fullName = File.join(ENV["HOME"], name)
      if File.exist?(fullName) 
        elispdir = fullName
        break
      end
    end
       
    if elispdir
      puts "You seem to have an elisp directory: #{elispdir}"
      print "Shall I copy the elisp code there [yN]: "
      ans = gets.chomp.strip.upcase
      if ans[0] == ?Y
        $emacs_files.each do |fname|
          File::install(fname, File.join(elispdir), 0644, true)
        end
        copied = true
      end
    end
    if !copied
      puts "You'll need to copy the following to an elisp directory: " +
        $emacs_files.join(" ")
    end
  end
end

########################################################################################
#
# Only run this stuff if we're being invoked as the installer
#

if $0 == __FILE__

# Create the Marshaled help documents

$stderr.puts "Generating binary help information"
Dir.mkdir("descriptions") if not File.directory?("descriptions")
dir = Dir.open("srcdesc")
dir.each do |file|
  next unless file =~ /\.rb$/
  root = $`                     # `
  $opfile = File.join("descriptions", root)
  require File.join("srcdesc", file)
end

# Install the help documents


File::makedirs($ri_dest)
File::chmod(0755, $ri_dest, true)

$stderr.puts "Installing reference material"

dir = Dir.open("descriptions")
dir.each do |file|
  next if file[0] == ?. or file[-1] == ?~
  File::install(File.join("descriptions", file), File.join($ri_dest, file), 0644, true)
end

# The library files

for aFile in %w{ ri/ri.rb ri/refdoc.rb ri/outputstream.rb }
  File::install(aFile, File.join($sitedir, aFile), 0644, true)
end

File::makedirs($ri_op)
File::chmod(0755, $ri_op, true)

dir = Dir.open("op")
dir.each do |file|
  next if file[0] == ?.  or file[-1] == ?~ or file == "CVS"
  File::install(File.join("op", file), File.join($ri_op, file), 0644, true)
end


# and the executable

installBIN("ri_cmd.rb", "ri")

# Finally, tidy up any old installation
# (delete this code in a couple of weeks)

olddest = File.join($site_libdir, "ri")

if (olddest != $ri_dest) && (File.directory?(olddest))
  puts "\nI see you have an old installation of 'ri' in #{olddest}."
  puts "We now install in to #{$ri_dest}.\n\n"
  print "Would you like me to remove the old files?"
  resp = gets
  if resp.strip[0] == ?y
    Dir.glob(File.join(olddest, "*")).each do |name|
      File::safe_unlink(name, true)
    end
    Dir.unlink(olddest)
  end
end
    

end
