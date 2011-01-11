# source: rubyquiz.com
# ruby scheduler.rb workers
# find in Documents/ruby-apps/ruby-quiz/scheduling

require "yaml"

class Worker
  def initialize( name )
  @name = name

  @avail = Hash.new
  @prefers = Hash.new
  end

  attr_reader :name

  # input: day and times
  # output: @avail - each day's hour obj ranges avail
  #         @perfers - each day's, hour obj ranges of prefer ( whole day, if none provided )
  def can_work( day, times )
    @avail[day] = parse_times(times)

    @prefers[day] = if times =~ /\((?:prefers )?([^)]+)\s*\)/
      parse_times($1)
    else
      Hour.new("12 AM")..Hour.new("11 PM")
    end
  end


  def available?( day, hour )
    if @avail[day].nil?
      false
    else
      @avail[day].include?(hour)
    end
  end


  def prefers?( day, hour )
    return false unless available? day, hour

    if @prefers[day].nil?
      false
    else
      @prefers[day].include?(hour)
    end
  end

  def ==( other )
    @name == other.name
  end

  def to_s
    @name.to_s
  end

  private
  
  # converts input-time to hour objects
  # input user-provided time string value
  # output range of hour objects
  def parse_times( times )
    case times
    when /^\s*any\b/i
      Hour.new("12 AM")..Hour.new("11 PM")
    when /^\s*before (\d+ [AP]M)\b/i
      Hour.new("12 AM")..Hour.new($1)
    when /^\s*after (\d+ [AP]M)\b/i
      Hour.new($1)..Hour.new("11 PM")
    when /^\s*(\d+ [AP]M) to (\d+ [AP]M)\b/i
      Hour.new($1)..Hour.new($2)
    when /^\s*not available\b/i
      nil
    else
      raise "Unexpected availability format."
    end
  end
end


class Hour
  def initialize( text )
    @hour = case text
    when "12 AM"
      0
    when "12 PM"
      12
    when /(\d+) PM/
      $1.to_i + 12
    else
      text[/\d+/].to_i
    end
  end

  include Comparable
  def <=>( other )
    @hour <=> other.instance_eval { @hour }
  end

  # need this for hour range's "each" block
  # with this, it knows everything between "start" and "finish"
  # eg: (start..finish).each do |hour|
  def succ
    next_hour = Hour.new("12 AM")

    next_time = (@hour + 1) % 24
    next_hour.instance_eval { @hour = next_time }
    #puts "      succ called: next_hour is #{next_hour}, #{@hour}, #{next_time}"
    next_hour
  end

  def to_s
    str = case @hour
      when 0
        "12 AM"
      when 12
        "12 PM"
      when 13..23
        "#{@hour - 12} PM"
      else
        "#{@hour} AM"
      end
      "%5s" % str
    end
end

puts "collect - worker prefs -------------------------------------- [#{__FILE__}]:[#{$0}]"
if __FILE__ == $0
  #puts "===> 1. #{ARGV.size} 3. #{ARGV.first}"
  unless ARGV.size == 1 and File.exists?(ARGV.first)
    puts "Usage: #{File.basename($0)} SCHEDULE_FILE"
    exit
  end

  # load the data
  data = File.open(ARGV.shift) { |file| YAML.load(file) }

  # build worker list from yaml file
  workers = Array.new
  data["Workers"].each do |name, avail|
    #puts "===> data: [#{name}]"
    worker = Worker.new(name)
    avail.each { |day, times| worker.can_work(day, times) 
      #puts "===> avail: [#{day}] [#{times}]"
    }
    workers << worker
  end
end

puts "build - schedule -------------------------------------- "
# create a legal schedule, respecting availability
schedule = Hash.new
data["Schedule"].each do |day, times|
  #puts "    ---> day: #{day}"
  schedule[day] = Array.new
  if times =~ /^\s*(\d+ [AP]M) to (\d+ [AP]M)\b/i
    start, finish = Hour.new($1), Hour.new($2)
    #puts "    ---> good time: [#{start}] to [#{finish}]" 
  else
    raise "Unexpected schedule format."
  end

  (start..finish).each do |hour|

    started_with = workers.first
    #puts "    ---> hour: #{hour}...started_with: #{started_with}"

    loop do
      if workers.first.available? day, hour
        schedule[day] << [hour, workers.first]
        #puts " ---> schedule[#{day}]: #{schedule[day]}"
        break
      else
        workers << workers.shift
        if workers.first == started_with
          schedule[day] << [hour, "No workers available!"]
          break
        end
      end
    end
  end
  workers << workers.shift
end

#schedule.each_key do |k,v|
#  puts "schedule[#{k}]: #{schedule}"
#end

schedule.each do |day, hours|
  hours.each_with_index do |(hour, worker), index|
    next unless worker.is_a?(Worker)
    unless worker.prefers?(day, hour)
      alternate = workers.find { |w| w.prefers?(day, hour) }
      #puts " ==> alternate.class: #{alternate.class} - #{alternate}"
      hours[index][-1] = alternate unless alternate.nil?
      #puts " ==> hours[#{index}][-1]: #{hours[index][-1]}"
    end
  end
end

%w{Mon Tue Wed Thu Fri Sat Sun}.each do |day|
  puts "#{day}:"
  schedule[day].each do |hour, worker|
    puts " #{hour}: #{worker}"
  end
end



