=begin

  rbbr/ui/gtk/stockview.rb 

  $Author$
  $Date$

  Copyright (C) 2002 Ruby-GNOME2 Project

  This program is free software.
  You can distribute/modify this program under
  the terms of the Ruby Distribute License.

=end

require 'gdk_pixbuf2'
require 'gtk2'
require 'observer'

module RBBR
module UI
module GTK
  class StockCont < Gtk::Frame
    def initialize
      super("Selected Item - Gtk::IconSize")
      set_height_request(130)
      box = Gtk::HBox.new
      @image = Hash.new
      @size_type = ["DIALOG", "DND", "LARGE_TOOLBAR", "BUTTON", "SMALL_TOOLBAR", "MENU"]
      table = Gtk::Table.new(2, 6, true)
      cnt = 0
      @size_type.each do |size|
        @image[size] = Gtk::Image.new
        table.attach(@image[size], cnt, cnt + 1, 0, 1)
        table.attach(Gtk::Label.new(@size_type[cnt]), cnt, cnt + 1, 1, 2)
        cnt += 1
      end
      @table = table
      add(table)
    end
    def update(iter)
      if iter.get_value(1)
        stock = eval(iter.get_value(1))
        @size_type.each do |size|
          @image[size].set(stock, Gtk::IconSize.module_eval(size))
        end
      end
    end
  end

  class StockView < Gtk::TreeView
    include Observable
    def initialize
      @model = Gtk::ListStore.new(Gdk::Pixbuf, String, String, String, String)
      super(@model)

      # first column
      pix = Gtk::CellRendererPixbuf.new
      text = Gtk::CellRendererText.new
      @column = Gtk::TreeViewColumn.new
      @column.title = "Constants"
      @column.pack_start(pix, true)
      @column.set_cell_data_func(pix) do |column, cell, model, iter|
        cell.pixbuf = iter.get_value(0) 
      end
      @column.pack_start(text, true)
      @column.set_cell_data_func(text) do |column, cell, model, iter|
        cell.text = iter.get_value(1)
      end
      @column.sort_column_id = 1
      append_column(@column)
      
      # other columns
      renderer = Gtk::CellRendererText.new
      labels = ["Label", "Accel", "ID"]
      labels.each_index do |cnt|
        @column = Gtk::TreeViewColumn.new(labels[cnt], renderer, {:text => cnt + 2})
        @column.sort_column_id = cnt + 2
        append_column(@column)
      end
      selection.mode = Gtk::SELECTION_SINGLE
      selection.signal_connect('changed') do |e|
        iter = selection.selected
        changed
        notify_observers(iter) if iter
      end
      set_height_request(200)
      set_rules_hint(true)
      append_list
    end
      
    def append_list
      freeze_notify
      stocks = [Gtk::Stock]
      if $GNOME_SUPPORTED
        #I shouldn't this here .... FIXME.
        Gnome::Program.new("rbbr", RBBR::VERSION) 
        stocks << Gnome::Stock
      end
      stocks.each do |mod_stock|
        mod_stock.constants.sort.each do |name|
          stock = mod_stock.module_eval(name)
          value = ""
          accel = ""
          begin
            stockinfo = Gtk::Stock.lookup(stock)
            value = stockinfo[1]
            value = "" unless value
            accel = Gtk::Accelerator.to_name(stockinfo[3], stockinfo[2])
            accel = "" unless accel
          rescue ArgumentError
          end
          append([render_icon(stock, Gtk::IconSize::MENU, value), 
                   mod_stock.name + "::" + name, 
                   value, accel, ":" + mod_stock.const_get(name).to_s
                 ])
        end
      end
      thaw_notify
    end

    def append(data)
      iter = @model.append
      iter.set_value(0, data[0]) if data[0]
      iter.set_value(1, data[1])
      iter.set_value(2, data[2])
      iter.set_value(3, data[3])
      iter.set_value(4, data[4])
    end
  end

  class StockDialog < Gtk::Dialog
    def initialize(parent = nil)
      super("Stock Item and Icon Browser", parent, Gtk::Dialog::MODAL, 
            [Gtk::Stock::CLOSE, Gtk::Dialog::RESPONSE_DELETE_EVENT])
      set_default_response(Gtk::Dialog::RESPONSE_DELETE_EVENT)

      stockcont = StockCont.new
      stockview = StockView.new
      stockview.add_observer(stockcont)

      scroll = Gtk::ScrolledWindow.new
      scroll.set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_AUTOMATIC)
      scroll.add(stockview)
      set_border_width(10)
      vbox.pack_start(scroll, true, true, 10)
      vbox.pack_start(stockcont, true, true, 10)
      show_all
    end
  end
     
end;end;end

if __FILE__ == $0 
  Gtk.init
  stockdialog = RBBR::UI::GTK::StockDialog.new
  stockdialog.run
  stockdialog.destroy
end
