module Kernel
  def singleton_method_added (sym)
    moniker = (kind_of? Module) ? name : "<#{type}:#{id}>"
    top=0
    top+=1 while caller[top].slice(0..6)=="(eval):"
    puts "Method #{moniker}.#{sym.id2name} at #{caller[top]}"
  end
end

class Module
  def method_added (sym)
    return if name==""  #ignore anonymous classes
    top=0
    top+=1 while caller[top].slice(0..6)=="(eval):"
    klass=name
    if false && klass == ""
      klass = "<#{type}:#{id}>"
      t=1
      t+=1 while (klass=ancestors[t].name) == ""
    end
    puts "Method #{klass}\##{sym.id2name} at #{caller[top]}"
  end
end

      
if false
set_trace_func proc {|event, file, line, id, binding, classname|
  printf "%8s %s:%-2d %10s %8s\n", event, file, line, id, classname
}
end
