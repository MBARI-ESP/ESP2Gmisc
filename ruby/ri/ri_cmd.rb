#
# This is the command line interface to 'ri'. We basically create
# an ri object, set up parameters according to command line
# options, then let it rip.
#
# For usage information, see the top of ri/ri.rb, or install and
# type 'ri'
#

require "ri/ri"
require 'getoptlong'


outputFormat = "Plain"
line_len     = 72
ri = RI.new

begin
  opts = GetoptLong.new(["--version",     "-v", GetoptLong::NO_ARGUMENT],
                        ["--line-length", "-l", GetoptLong::REQUIRED_ARGUMENT],
                        ["--format",      "-f", GetoptLong::REQUIRED_ARGUMENT],
                        ["--synopsis",    "-s", GetoptLong::NO_ARGUMENT])
  
  opts.each do |opt, arg|
    case opt
    when "--version"
      $stderr.puts("ri #{ri.version}")
      exit(0)
    when "--format"
      outputFormat = arg
    when "--synopsis"
      ri.synopsis = true
    when "--line-length"
      line_len = arg.to_i
      if (line_len < 20)
        $stderr.puts "That's not a very good line length :)"
        usage
      end
    else
      $stderr.puts("Internal error: unhandled option #{opt}")
      exit(1)
    end
  end
rescue 
  $stderr.puts($!)
  exit(1)
end

# Load up an output formatter. If the name contains a '/', or ends in .rb
# assume it's a file name and don't prepend the directory prefix

opName = outputFormat
if opName['/'] or opName =~ /\.rb$/
  outputFormat = File.basename(outputFormat, ".rb")
else
  opName = File.join("ri/op", opName) 
end

begin
  require opName
  klass = eval outputFormat
  op = klass.new($stdout, line_len)
  ri.setOutputFormatter(op)
rescue LoadError
  p $!
  $stderr.puts "Cannot load output format `#{outputFormat}'"
  $stderr.puts "Valid formats are:", moduleList()
  exit(1)
end

exit(ri.handle(ARGV))
