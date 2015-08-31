module Embulk
  module Guess

    # TODO implement guess plugin to make this command work:
    #      $ embulk guess -g "regex" partial-config.yml
    #
    #      Depending on the file format the plugin uses, you can use choose
    #      one of binary guess (GuessPlugin), text guess (TextGuessPlugin),
    #      or line guess (LineGuessPlugin).

    #class Regex < GuessPlugin
    #  Plugin.register_guess("regex", self)
    #
    #  def guess(config, sample_buffer)
    #    if sample_buffer[0,2] == GZIP_HEADER
    #      guessed = {}
    #      guessed["type"] = "regex"
    #      guessed["property1"] = "guessed-value"
    #      return {"parser" => guessed}
    #    else
    #      return {}
    #    end
    #  end
    #end

    #class Regex < TextGuessPlugin
    #  Plugin.register_guess("regex", self)
    #
    #  def guess_text(config, sample_text)
    #    js = JSON.parse(sample_text) rescue nil
    #    if js && js["mykeyword"] == "keyword"
    #      guessed = {}
    #      guessed["type"] = "regex"
    #      guessed["property1"] = "guessed-value"
    #      return {"parser" => guessed}
    #    else
    #      return {}
    #    end
    #  end
    #end

    class Regex < LineGuessPlugin
      Plugin.register_guess("regex", self)

      def guess_lines(config, sample_lines)
        guessed = apache_common(config, sample_lines)
        if guessed
          return {"parser" => guessed}
        end

        return {}
      end

      def apache_common(config, sample_lines)
        g = RegexApacheLogGuesser.new
        g.ip(:remote_host, regexName: 'remoteHost').token(:identity).token(:user)
          .kakko(:datetime, format: '%d/%b/%Y:%H:%M:%S %z', type: 'timestamp')
          .method_path_protocol
          .integer(:status).integer_or_minus(:size)
          .string(:referer).string(:user_agent, regexName: 'userAgent')
          .integer(:in_byte, regexName: 'inByte').integer(:out_byte, regexName: 'outByte')

        ptn = g.compile
        all_line_matched = sample_lines.all? do |line|
          ptn.match(line)
        end

        if all_line_matched
          guessed = {}
          guessed["type"] = "regex"
          guessed["regex"] = g.pattern_str
          guessed["columns"] = g.columns
          return guessed
        end
        return nil
      end
    end

    class RegexApacheLogGuesser
      attr_reader :columns

      def initialize
        @patterns = []
        @columns = []
      end

      def compile
        Regexp.compile pattern_str
      end

      def pattern_str
        '^' + @patterns.join(' ') + '$'
      end

      def ip(name, opts={})
        @patterns << "(?<#{opts[:regexName] || name}>[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3})"
        @columns << {:name => name, :type => 'string'}.merge(opts)
        self
      end

      def ip_or_minus(name, opts={})
        @patterns << "(?<#{opts[:regexName] || name}>[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}|-)"
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
