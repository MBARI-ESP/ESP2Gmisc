# Base class for outputstreams such as Plain and Tagged

class OutputStream
  def initialize(stream, line_len)
    @stream = stream
    @line_len = line_len
  end

  def puts(*msg)
    msg.each do |m|
      @stream << m.chomp << "\n"
    end
  end

  def wrap(prefix, txt, linelen=@line_len)
    work = txt.dup
    textLen = linelen - prefix.length
    patt = Regexp.new("^(.{0,#{textLen}})[ \n]")
    next_prefix = prefix.tr "^ ", " "

    res = []

    while work.length > textLen
      if work =~ patt
        res << $1
        work.slice!(0, $&.length)
      else
        res << work.slice!(0, textLen)
      end
    end
    res << work if work.length.nonzero?
    prefix +  res.join("\n" + next_prefix)
  end

  ##
  # Remove the simple HTML markup in the text.
  #
  def stripFormatting(str)
    res = str.gsub("<br></br>", "\n")
    1 while res.gsub!(/<([^>]+)>(.*?)<\/\1>/m, '\2')
    res
  end


end
    
