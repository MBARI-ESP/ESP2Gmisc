=begin
  rbbr/ui/gtk/docviewer.rb 

  $Author$
  $Date$

  Copyright (C) 2002 Ruby-GNOME2 Project

  Copyright (C) 2000-2002 Hiroshi Igarashi <iga@ruby-lang.org>

  This program is free software.
  You can distribute/modify this program under
  the terms of the Ruby Distribute License.

=end

module RBBR
module UI
module GTK

  class DocViewer < Gtk::TextView
    def initialize( database )
      super()
      @database = database
	  @buffer = buffer
    end

    def update(modul, meth)
    end
  end


  class SimpleDocViewer < DocViewer
    def initialize( database )
      super( database )
      self.editable = false

      @font = {}
#      @font[:header] = Gdk::Font.fontset_load('-*-*-bold-r-normal-*-18-*-*-*-m-*-iso8859-1,*')
#      @font[:monospace] = Gdk::Font.fontset_load('-*-*-medium-r-normal-*-12-*-*-*-m-*-iso8859-1,*')
    end

    def update(modul, spec)
      freeze_notify
      @buffer.text = ""
      begin
        desc = @database.lookup_method(spec)
        if desc.size > 0
          @buffer.text = "#{spec}\n" + WindowUtils.conv_utf8(desc)
        else
          @buffer.text = "#{spec}\n(no document)\n"
        end
      rescue RBBR::Doc::LookupError
        @buffer.text = "#{spec}\n(no document)\n"
      ensure
        thaw_notify
      end
    end
  end
end;end;end
