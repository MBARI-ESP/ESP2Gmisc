=begin

  rbbr/ui/gtk/browser.rb 

  $Author$
  $Date$

  Copyright (C) 2003 MBARI (brent@mbari.org)
  Copyright (C) 2002 Ruby-GNOME2 Project

  Copyright (C) 2000-2002 Hiroshi Igarashi <iga@ruby-lang.org>

  This program is free software.
  You can distribute/modify this program under
  the terms of the Ruby Distribute License.

=end

require 'rbbr/ui/gtk/windowutils'
require 'rbbr/ui/gtk/stockbrowser'
require 'rbbr/ui/gtk/aboutdialog'
require 'rbbr/ui/gtk/libselectiondialog'
require 'sourceref'

module RBBR
module UI
module GTK

  class Browser < Gtk::Window
    include WindowUtils

    def create_menubar
      cal_req = Proc.new{ 
        libselection = RBBR::UI::GTK::LibrarySelectionDialog.new(self)

        if libselection.run == Gtk::Dialog::RESPONSE_OK
          feature = libselection.result
          begin
            unless feature.nil?
              Kernel.require(feature) 
              @module_nesting_tree.update
            end
          rescue LoadError
            show_error_message("Ruby Browser", $!)
          end
        end
        libselection.destroy
      }

      cal_load = Proc.new{
        fs = Gtk::FileSelection.new(title)
        fs.set_transient_for(self)
        filename = nil
        fs.show_all
        fs.run
        filename = fs.filename
        begin
          if FileTest.file?(filename)
            load(filename)
            @module_nesting_tree.update
          end
        rescue LoadError, SyntaxError
          show_error_message("Ruby Browser", $!)
        end
        fs.destroy
      }

      cal_quit = Proc.new{ Gtk.main_quit }
      cal_copy = Proc.new{ not_implemented }
      cal_expand = Proc.new{ @module_index.expand_all }
      cal_fold = Proc.new{ @module_index.collapse_all }
      cal_update = Proc.new{ @module_index.update([]) }
      cal_filter = Proc.new{ not_implemented }
      
      cal_edit = Proc.new{ edit @displayedSource }
      cal_view = Proc.new{ view @displayedSource }
      cal_reload = Proc.new{ reload @displayedSource; cal_update.call }
      
      cal_stockbrowser = Proc.new{
        stockbrowser = RBBR::UI::GTK::StockDialog.new(self)
        stockbrowser.run
        stockbrowser.destroy
      }
      cal_about = Proc.new{
        aboutdialog = RBBR::UI::GTK::AboutDialog.new(self)
        aboutdialog.run
        aboutdialog.destroy
      }

      accelgroup = Gtk::AccelGroup.new
      add_accel_group(accelgroup)
      ifp = Gtk::ItemFactory.new(Gtk::ItemFactory::TYPE_MENU_BAR, "<main>", accelgroup)

      ifp.create_items([
                         ["/_File"],
                         ["/_File/Reload Source", "<StockItem>", "<control>R", Gtk::Stock::REFRESH, cal_reload],
                         ["/_File/_Separator", "<Separator>"],
                         ["/_File/_Require Library...", "<StockItem>", "<control>Y", Gtk::Stock::ADD, cal_req],
                         ["/_File/_Load Script...", "<StockItem>", "<control>L", Gtk::Stock::OPEN, cal_load],
                         ["/_File/_Separator", "<Separator>"],
                         ["/_File/_Quit", "<StockItem>", "<control>Q", Gtk::Stock::QUIT, cal_quit],
                         ["/_Edit"],
                         ["/_Edit/Source Code", "<StockItem>", "<control>O", Gtk::Stock::INDEX, cal_edit],
                         ["/_Edit/_Separator", "<Separator>"],
                         ["/_Edit/_Copy", "<StockItem>", "<control>C", Gtk::Stock::COPY, cal_copy],
                         ["/_View"],
                         ["/_View/Source Code", "<StockItem>", "<control>V", Gtk::Stock::JUSTIFY_FILL, cal_view],
                         ["/_View/_Separator", "<Separator>"],
                         ["/_View/_Expand All", "<StockItem>", "<control>E", Gtk::Stock::GOTO_BOTTOM, cal_expand],
                         ["/_View/_Fold All", "<StockItem>", "<control>F", Gtk::Stock::GOTO_TOP, cal_fold],
                         ["/_View/Update Information", "<StockItem>", "<control>U", Gtk::Stock::REFRESH, cal_update],
                         ["/_View/Filter Setting...", "<StockItem>", "<control>S", Gtk::Stock::PREFERENCES, cal_filter],
                         ["/_View/Stock Item and Icon Browser ...", "<Item>", "<control>I", "", cal_stockbrowser],
                         ["/_Help", "<LastBranch>"],
                         ["/_Help/_About", "<StockItem>", "<control>A", Gtk::Stock::HELP, cal_about]
                       ])

      ifp.get_widget("/Edit/Copy").sensitive = false
      ifp.get_widget("/View/Filter Setting...").sensitive = false
      @viewSource = ifp.get_widget("/View/Source Code")
      @editSource = ifp.get_widget("/Edit/Source Code")
      @reloadSource = ifp.get_widget("/File/Reload Source")
      update(nil)  #ghost out source display menu items 

      ifp.get_widget("<main>")
    end

    def initialize      
      super
      
      signal_connect("destroy") do
        quit
      end

      # create vbox
      vbox = Gtk::VBox.new(false, 0)
      add(vbox)

      # create menu
      vbox.pack_start(create_menubar, false, false, 0)

      # create main box
      main_paned = Gtk::HPaned.new
      vbox.pack_start(main_paned, true, true, 0)
      index_paned = Gtk::VPaned.new
      main_paned.add1(index_paned)

      # create module nesting tree
      module_nesting_tree_scwin = Gtk::ScrolledWindow.new
      module_nesting_tree_scwin.set_policy(Gtk::POLICY_AUTOMATIC,
                                           Gtk::POLICY_AUTOMATIC)
      index_paned.add1(module_nesting_tree_scwin)
      @module_nesting_tree = ModuleNestingTree.new
      module_nesting_tree_scwin.add(@module_nesting_tree)

      # create module index
      module_index_scwin = Gtk::ScrolledWindow.new
      module_index_scwin.set_policy(Gtk::POLICY_AUTOMATIC,
                                    Gtk::POLICY_AUTOMATIC)
      index_paned.add2(module_index_scwin)
      @module_index = ModuleIndex.new
      @module_nesting_tree.add_observer(@module_index)
      module_index_scwin.add(@module_index)

      # create document database
      database = Doc::MultiDatabase.new
      sourcebase = database.find_instance_of RBBR::Doc::Source
      sourcebase.add_observer(self) if sourcebase
	
      # create module display
      module_display = ModuleDisplay.new(database)
      @module_index.add_observer(module_display)
      main_paned.add2(module_display)

      # set visibility
      vbox.show_all
      main_paned.show_all
      index_paned.show_all
      module_display.show

      # setting size
      index_paned.set_position(200)
      set_default_size(640, 480)
      module_index_scwin.set_size_request(200, 480)

      # set icon
      set_icon(Gdk::Pixbuf.new(File.join(RBBR::Config::DATA_DIR, "icon.xpm")))

      # initialize contents
      Thread.start do
        @module_nesting_tree.update
      end
    end

    def update (displayed)
    # passed SourceRef being displayed or nil if none
      @displayedSource = displayed
      @viewSource.sensitive = displayed
      @editSource.sensitive = displayed
      @reloadSource.sensitive = displayed
    end
    
    def quit
      Gtk.main_quit
    end

    def not_implemented
      show_error_message("Ruby Browser", "Sorry, not implemented.")
    end
  end
end;end;end
