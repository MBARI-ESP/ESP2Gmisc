=begin

  rbbr/ui/gtk/windowutils.rb 

  $Author$
  $Date$

  Copyright (C) 2002 Ruby-GNOME2 Project

  Copyright (C) 2000-2002 Hiroshi Igarashi <iga@ruby-lang.org>

  This program is free software.
  You can distribute/modify this program under
  the terms of the Ruby Distribute License.

=end

begin
  require 'iconv'
  $__NO_ICONV = false
rescue LoadError
  $__NO_ICONV = true
end

module RBBR
module UI
module GTK
  module WindowUtils
    module_function
    def conv_utf8(str)
      ret = str
      unless $__NO_ICONV
        begin
          ret = Iconv.iconv("UTF-8", RBBR::Config::ICONV_SRC_CHARSET, str).join
        rescue Iconv::IllegalSequence
          if $DEBUG
            print "Iconv::IllegalSequence was occured.\n"
            print "String = #{str}\n"
          end
        end
      end
      ret 
    end

    def show_error_message(title, error)
      ary = error.to_s.split(/\n/)
      if ary.size > 15
        message = ary[0...15].join("\n")
      else
        message = ary.join("\n")
      end

      dialog = Gtk::MessageDialog.new(self, 
                                      Gtk::Dialog::DESTROY_WITH_PARENT,
                                      Gtk::MessageDialog::ERROR,
                                      Gtk::MessageDialog::BUTTONS_CLOSE,
                                      message)
      dialog.show_all
      dialog.run
      dialog.destroy
    end
  end
end;end;end
