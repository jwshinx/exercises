class Madlib

# Given the madlib text as a string, builds a list of questions and
# a map of questions to "blanks"
  def initialize(txt)
  @questions = []
  @story_parts = []
  @answer_list = []
  @answers = []

    stored = {}

    #txt.split(/\((\([^)]*\))\)/).each do |item|
    #txt.split( / \(  (\([^)]*\))  \) / ).each do |item|

    #txt.split(/(123)-(123)/).each do |item|
    txt.split(/\((\([^)]*\))\)/).each do |item|

      puts "item: #{item}" 
      
      if item[0] == ?(                       # "?" matches a single char
        item = item[1..-2].gsub("\n", '')
        if item.index(':')
          name, question = item.split(':')
          stored[name] = @questions.length
          @questions << question
        else
          name, question = item, item
        end
        @answer_list << (stored[name] || @questions.length)
        @questions << question unless stored[name]
      else
        @story_parts << item
      end
    end
  end

  # Calls a block with the index and text of each question
  def list_questions(&block)
    @questions.each_index do |i|
      yield(i, @questions[i])
    end
  end

  # Stores the answer for a given question index
  def answer_question(i, answer)
    @answers[i] = answer
  end

  # Returns a string with the answers filled-in to their respective blanks
  def show_result
    real_answers = @answer_list.collect {|i| @answers[i]}
    @story_parts.zip(real_answers).flatten.compact.join
  end
end

# Example that reads the madlib text from a file specified on the
# command line

madlib = Madlib.new(IO.read(ARGV.shift))
puts "--> madlib: #{madlib.inspect}"
answers = []
madlib.list_questions do |i, q|
  print "Give me " + q + ": "
  answers[i] = gets.strip
end
answers.each_index {|i| madlib.answer_question(i, answers[i]) }
puts madlib.show_result
