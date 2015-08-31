# Regex parser plugin for Embulk

A simple parser Using Regular Expression.

## Overview

* **Plugin type**: parser
* **Guess supported**: yes

## Configuration

- **regex**: regular expression that must use [Named Capturing Group](https://blogs.oracle.com/xuemingshen/entry/named_capturing_group_in_jdk7)  (string, required)
- **columns**: column definition (list of object)
  - **regexName**: 'Named Capturing Group' can only include `[a-zA-Z0-9]`, so alias group name in regex can be specified (string, default: `<name> attr value`)
- **skip_if_unmatch**: if false, when a line don't match the regex, raise RuntimeException. If true, skip the line.  (boolean, default: `false`)

## Example

```yaml
in:
  type: any file input plugin type
  parser:
    type: regex
    regex: ^(?<remoteHost>[.:0-9]+) (?<identity>\S+) (?<user>\S+) \[(?<datetime>[^\]]*)\] "((?<method>\S+) (?<path>\S+) (?<protocol>HTTP/\d+\.\d+)|-)" (?<status>[0-9]+) (?<size>[0-9]+|-) "(?<referer>[^"]*)" "(?<userAgent>[^"]*)" (?<inByte>[0-9]+) (?<outByte>[0-9]+)$
    columns:
    - {name: remote_host, type: string, regexName: remoteHost}
    - {name: identity, type: string}
    - {name: user, type: string}
    - {name: datetime, type: timestamp, format: '%d/%b/%Y:%H:%M:%S %z'}
    - {name: method, type: string}
    - {name: path, type: string}
    - {name: protocol, type: string}
    - {name: status, type: long}
    - {name: size, type: long}
    - {name: referer, type: string}
    - {name: user_agent, type: string, regexName: userAgent}
    - {name: in_byte, type: long, regexName: inByte}
    - {name: out_byte, type: long, regexName: outByte}
```

### Guess
Some apache LogFormats can be guessed.
After writing `in:` section, you can let embulk guess `parser:` section using this command:


```
$ embulk gem install embulk-parser-regex
$ embulk guess -g regex config.yml -o guessed.yml
```

## Build

```
$ ./gradlew gem  # -t to watch change of files and rebuild continuously
```
