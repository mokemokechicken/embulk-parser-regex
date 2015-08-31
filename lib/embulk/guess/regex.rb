module Embulk
  module Guess

    # TODO implement guess plugin to make this command work:
    #      $ embulk guess -g "regex" partial-config.yml
    #
    #      Depending on the file format the plugin uses, you can use choose
    #      one of binary guess (GuessPlugin), text guess (TextGuessPlugin),
    #      or line guess (LineGuessPlugin).

    class Regex < LineGuessPlugin
      Plugin.register_guess("regex", self)

      def guess_lines(config, sample_lines)
        guesser_list = []
        guesser_list << apache_common(config, sample_lines)
        guesser_list << apache_combined(config, sample_lines)
        guesser_list << apache_combinedio(config, sample_lines)
        guesser_list << apache_x_forwarded_for + apache_combined(config, sample_lines)
        guesser_list << apache_x_forwarded_for + apache_combinedio(config, sample_lines)
        guesser_list.each do |g|
          return {"parser" => g.guessed} if g.match_all?(sample_lines)
        end
        return {}
      end

      def apache_x_forwarded_for
        RegexApacheLogGuesser.new
          .ip_or_minus(:x_forwarded_for, regexName: 'forwardedFor')
      end

      def apache_common(config, sample_lines)
        RegexApacheLogGuesser.new
          .ip(:remote_host, regexName: 'remoteHost').token(:identity).token(:user)
          .kakko(:datetime, format: '%d/%b/%Y:%H:%M:%S %z', type: 'timestamp')
          .method_path_protocol
          .integer(:status).integer_or_minus(:size)
      end

      def apache_combined(config, sample_lines)
        apache_common(config, sample_lines)
          .string(:referer).string(:user_agent, regexName: 'userAgent')
      end

      def apache_combinedio(config, sample_lines)
        apache_combined(config, sample_lines)
          .integer(:in_byte, regexName: 'inByte').integer(:out_byte, regexName: 'outByte')
      end
    end

    class RegexApacheLogGuesser
      attr_reader :columns, :patterns

      def initialize(patterns=nil, columns=nil)
        @patterns = (patterns || [])
        @columns = (columns || [])
      end

      def +(guesser)
        RegexApacheLogGuesser.new(@patterns + guesser.patterns, @columns + guesser.columns)
      end

      def match_all?(lines)
        ptn = compile
        lines.all? {|line| ptn.match(line)}
      end

      def guessed
          ret = {}
          ret["type"] = "regex"
          ret["regex"] = pattern_str
          ret["columns"] = columns
          ret
      end

      def compile
        Regexp.compile pattern_str
      end

      def pattern_str
        '^' + @patterns.join(' ') + '$'
      end

      def ip(name, opts={})
        @patterns << "(?<#{opts[:regexName] || name}>[.:0-9]+)"
        @columns << {:name => name, :type => 'string'}.merge(opts)
        self
      end

      def ip_or_minus(name, opts={})
        @patterns << "(?<#{opts[:regexName] || name}>[.:0-9]+|-)"
        @columns << {:name => name, :type => 'string'}.merge(opts)
        self
      end

      def token(name, opts={})
        @patterns << "(?<#{opts[:regexName] || name}>\\S+)"
        @columns << {:name => name, :type => 'string'}.merge(opts)
        self
      end

      def string(name, opts={})
        @patterns << "\"(?<#{opts[:regexName] || name}>[^\"]*)\""
        @columns << {:name => name, :type => 'string'}.merge(opts)
        self
      end

      def string_or_minus(name, opts={})
        @patterns << "\"(?<#{opts[:regexName] || name}>[^\"]*|-)\""
        @columns << {:name => name, :type => 'string'}.merge(opts)
        self
      end

      def integer(name, opts={})
        @patterns << "(?<#{opts[:regexName] || name}>[0-9]+)"
        @columns << {:name => name, :type => 'long'}.merge(opts)
        self
      end

      def integer_or_minus(name, opts={})
        @patterns << "(?<#{opts[:regexName] || name}>[0-9]+|-)"
        @columns << {:name => name, :type => 'long'}.merge(opts)
        self
      end

      def kakko(name, opts={})
        @patterns << "\\[(?<#{opts[:regexName] || name}>[^\\]]*)\\]"
        @columns << {:name => name, :type => 'string'}.merge(opts)
        self
      end

      def method_path_protocol
        @patterns << '"((?<method>\S+) (?<path>\S+) (?<protocol>HTTP/\d+\.\d+)|-)"'
        @columns << {:name => 'method', :type => 'string'}
        @columns << {:name => 'path', :type => 'string'}
        @columns << {:name => 'protocol', :type => 'string'}
        self
      end
    end
  end
end
