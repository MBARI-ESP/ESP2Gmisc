=begin

  rbbr/pre-setup.rb - setup for rbbr library

  $Author$
  $Date$

  Copyright (C) 2002 Ruby-GNOME2 Project

  Copyright (C) 2001-2002 Hiroshi Igarashi <iga@ruby-lang.org>

  This program is free software.
  You can distribute/modify this program under
  the terms of the Ruby Distribute License.

=end

def main
  File.open( 'config.rb', 'w' ) do |f|
    f.print <<"--"
=begin

  rbbr/config.rb

    This file is automatically generated by rbbr installer.

=end

module RBBR
  module Config
    DATA_DIR = '#{config('data-dir')}/rbbr'
    ICONV_SRC_CHARSET = 'EUC-JP'
  end
end
--
  end
end

main