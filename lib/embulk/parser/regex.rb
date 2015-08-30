Embulk::JavaPlugin.register_parser(
  "regex", "org.embulk.parser.regex.RegexParserPlugin",
  File.expand_path('../../../../classpath', __FILE__))
