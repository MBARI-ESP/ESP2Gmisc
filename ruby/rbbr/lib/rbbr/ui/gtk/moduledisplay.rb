=begin

  rbbr/ui/gtk/moduledisplay.rb 

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

  class ModuleDisplay < Gtk::VPaned
    
    def initialize(database, docviewer=SimpleDocViewer.new(database))
      super()

      @database = database
      @docviewer = docviewer

      # create display paned
      display_box = Gtk::VBox.new(false, 0)
      self.add1(display_box)

      docviewer_scwin = Gtk::ScrolledWindow.new 
      docviewer_scwin.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC)
      self.add2(docviewer_scwin)
      docviewer_scwin.add(@docviewer)
      set_position(300)

      # create module label
      @module_label = ModuleLabel.new
      display_box.pack_start(@module_label, false, true, 0)

      # create display option menu
      display_option_menu = Gtk::OptionMenu.new
      display_box.pack_start(display_option_menu, false, false, 0)
      display_option_menu.set_menu(display_menu = Gtk::Menu.new)

      # create notebook
      notebook = Gtk::Notebook.new
      notebook.set_tab_pos(Gtk::POS_TOP)
      notebook.set_scrollable(true)
      notebook.set_homogeneous(false)
      notebook.set_show_tabs(true)
      display_box.pack_start(notebook, true, true, 0)

      # create lists
      singleton_method_list = SingletonMethodList.new
      public_instance_method_list = PublicInstanceMethodList.new
      protected_instance_method_list = ProtectedInstanceMethodList.new
      private_instance_method_list = PrivateInstanceMethodList.new
      constant_list = ConstantList.new
      property_list = PropertyList.new
      signal_list   = SignalList.new
      @lists =
        [ 
        #	[public_instance_method_list, "Public Instance Methods"],
        #	[protected_instance_method_list, "Protected Instance Methods"],
        #	[private_instance_method_list, "Private Instance Methods"],
        #	[singleton_method_list, "Singleton Methods"],
        #	[constant_list, "Constants"],
        [public_instance_method_list, "Public"],
        [protected_instance_method_list, "Protected"],
        [private_instance_method_list, "Private"],
        [singleton_method_list, "Singleton"],
        [constant_list, "Constants"],
        [property_list, "Properties"],
        [signal_list, "Signals"],
      ]
      @lists.each_with_index do |(list, label), index|
        scwin = Gtk::ScrolledWindow.new
        scwin.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC)
        scwin.add(list)
        display_menu.append(menu_item = Gtk::MenuItem.new(label))
        menu_item.signal_connect("activate") do
          notebook.set_page(index)
        end
        notebook.append_page(scwin, Gtk::Label.new(label))
        notebook.set_tab_label_packing(scwin, true, true, Gtk::PACK_START)
        
        list.add_observer(@docviewer)
      end
      display_option_menu.set_history(0)
	  
      @module_label.show
      #display_option_menu.show_all
      display_box.show
      notebook.show_all
      @docviewer.show_all
      docviewer_scwin.show
    end

    def update(*args)
      @module_label.update(*args)
      @lists.each do |list, label|
        list.update(*args)
      end
    end

  end
end;end;end
