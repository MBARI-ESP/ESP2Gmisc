=begin

  rbbr/doc/source.rb - Display Ruby source text via SourceRef class

  $Author$
  $Date$

  Copyright (C) 2003 MBARI  (brent@mbari.org)
  Copyright (C) 2002 Ruby-GNOME2 Project

  Copyright (C) 2001 Hiroshi Igarashi <iga@ruby-lang.org>

  This program is free software.
  You can distribute/modify this program under
  the terms of the Ruby Distribute License.

=end

require 'rbbr/doc'
require 'sourceref'
require 'observer'

module RBBR
  module Doc

    class Source < Database
      include Observable

      def initialize
	super()
      end

      def lookup_module( modul )
	begin
          result = eval(modul).sources 
          raise LookupError if !(result.kind_of? Array) || result.length == 0
	rescue
          changed; notify_observers nil
	  raise LookupError, "No Ruby Source files for module: "+modul
	end
        changed; notify_observers result
        result.join
      end

      def lookup_const( const )
        changed; notify_observers nil
	raise LookupError, "constant is not supported"
      end
      
      def lookup_method( method )
        #passed either a method specification OR an Exception
	begin
          if method.kind_of? Exception
            srcRef = method.to_srcRef  #extract SourceRef from exception
            return srcRef.list 300
          end
          kname, mname = method.split('#',2)
          methodType = if mname
                         :instance_method
                       else 
                         kname, mname = method.split('.',2)
                         :method
                       end
          srcRef = eval(kname).method(methodType)[mname].source
          srcText = srcRef.list 300
          raise LookupError if srcText=="" 
          changed; notify_observers srcRef
          return "is defined @ #{srcRef} as:\n#{srcText}"
	rescue
          changed; notify_observers nil
	  raise LookupError, "No Ruby Source for method: "+method
	end
      end

      MultiDatabase::DatabaseList << self

    end

  end
end
