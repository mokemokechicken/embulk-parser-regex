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
        ptn = [IP,
        all_line_matched = sample_lines.all? do |line|
          line =~ /^$/
        end
        if all_line_matched
          guessed = {}
          guessed["type"] = "regex"
          guessed["property1"] = "guessed-value"
          return guessed
        end
        return nil
      end

      def re_ip(name)
        "(?<#{name}>[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3})"
      end

      def re_ip_or_minus(name)
        "(?<#{name}>[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}|-)"
      end

      def re_token(name)
        "(?<#{name}>\\S+)"
      end

      def re_string(name)
        "\"(?<#{name}>[^\"]*)\""
      end

      def re_integer(name)
        "(?<#{name}>[0-9]+)"
      end

      def re_kakko(name)
        "\\[(?<#{name}>[^\\]]*)\\]"
      end

      def re_method_path_protocol
        '"(?<method>\S+) (?<path>\S+) (?<protocol>HTTP/\d+\.\d+)"'
      end

    end

  end
end
