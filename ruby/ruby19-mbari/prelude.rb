class Mutex
  def synchronize
    self.lock
    begin
      yield
    ensure
      self.unlock
    end
  end
end

class Thread
  def self.exclusive
    return yield if self.critical
    begin
      self.critical = true
      yield
    ensure
      self.critical = false
    end
  end
end
