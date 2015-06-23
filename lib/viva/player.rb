require 'childprocess'
require 'io/console'

class Viva
  # Plays the music either on local filesystem or by streaming
  class Player
    PLAYER = 'mpg123'
    # To start mpg123 in server mode
    PLAYER_OPTIONS = ['-R']
    FINISHED = 0

    def initialize(param)
      case param
      when Viva::Database::Track
        @track = param
        @url = param.url
      when String
        @url = param
      else
        fail
      end
    end

    def play(url: nil)
      unless File.executable?(`which #{PLAYER}`.chomp!)
        fail "#{PLAYER} cannot be run"
      end

      # Save current tty
      stty_state = `stty -g`

      print_info

      r, w = IO.pipe
      @process = ChildProcess.build(PLAYER, *PLAYER_OPTIONS)
      @process.io.stdout = w
      @process.duplex = true
      @process.start

      to_play = url || @url
      load_file(to_play)

      # Child
      input_pid = fork do
        loop do
          cmd = STDIN.getch
          send_cmd(cmd)

          # Inform parent that mpg123 has terminated
          w.puts 'q' if cmd == 'q'
        end
      end

      # Parent
      loop do
        output = r.gets.chomp

        # When getting message from child that mpg123 has terminated
        break if output == 'q'

        # Show current time
        if output.start_with?('@F')
          # Forth field is the current time
          current_time = output.split(' ')[3]

          # Erase previously shown characters
          print ' ' * 20
          print "\r#{current_time}"
        elsif output.start_with?('@P')
          state = output.split(' ')[-1].to_i
          # @P = 1 when paused, @P = 0 when finished
          if state == FINISHED
            puts
            break
          end
        end
      end

      STDIN.cooked!
      puts
      Process.kill('KILL', input_pid)
      # Restore
      system("stty #{stty_state}")
    end

    # Saves the URL to local. The basename is used when no file name is given
    # Returns the name of the file.
    def save(name = nil)
      puts "Downloading from #{@url}"
      name = File.basename(@url) if name.nil?
      open(name, 'wb') do |file|
        file << open(@url).read
      end
      name
    end

    def save_and_play(name = nil)
      name = save(name)
      # Play the saved file
      puts "Now playing #{name}"
      play(url: name)
    end

    private

    def print_info
      return if !defined?(@track) || @track.nil?

      title = @track[:title] || @track[:default_title]
      print "#{title}"
      unless @track.series.nil?
        series = @track.series[:jpn] || @track.series[:eng] \
                 || @track.series[:raw]
        print " from #{series}"
      end
      puts
    end

    # Sends the command to the child process (mpg123)
    def send_cmd(cmd)
      @process.io.stdin.puts cmd
    end

    # Use the "load" command for mpg123 to start playing the mp3 file
    def load_file(path)
      send_cmd("load #{path}")
    end
  end
end
