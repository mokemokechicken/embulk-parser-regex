package org.embulk.parser.regex;

// Many Copies from
// https://github.com/frsyuki/embulk-parser-msgpack/blob/master/src/main/java/org/embulk/parser/msgpack/MsgpackParserPlugin.java

import com.google.common.base.Optional;
import org.embulk.EmbulkEmbed;
import org.embulk.config.*;
import org.embulk.spi.*;
import org.embulk.spi.time.TimestampFormatter;
import org.embulk.spi.time.TimestampParser;
import org.embulk.spi.type.*;
import org.embulk.spi.util.DynamicColumnSetter;
import org.embulk.spi.util.LineDecoder;
import org.embulk.spi.util.Timestamps;
import org.embulk.spi.util.dynamic.*;

import java.util.HashMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class RegexParserPlugin implements ParserPlugin {

    public interface PluginTask extends Task, LineDecoder.DecoderTask, TimestampParser.Task {
        @Config("regex")
        public String getRegex();

        @Config("columns")
        public SchemaConfig getSchemaConfig();

        @Config("skip_if_unmatch")
        @ConfigDefault("false")
        public boolean getSkipIfUnmatch();
    }

    public interface PluginTaskFormatter
            extends Task, TimestampFormatter.Task {
    }

    private interface TimestampColumnOption
            extends Task, TimestampFormatter.TimestampColumnOption {
    }

    public void transaction(ConfigSource config, ParserPlugin.Control control) {
        PluginTask task = config.loadConfig(PluginTask.class);
        control.run(task.dump(), task.getSchemaConfig().toSchema());
    }

    @Override
    public void run(TaskSource taskSource, Schema schema, FileInput input, PageOutput output) {
        PluginTask task = taskSource.loadTask(PluginTask.class);
        LineDecoder lineDecoder = new LineDecoder(input, task);
        PageBuilder pageBuilder = new PageBuilder(Exec.getBufferAllocator(), schema, output);
        TimestampParser[] timestampParsers = Timestamps.newTimestampColumnParsers(task, task.getSchemaConfig());

        Pattern pattern = Pattern.compile(task.getRegex());
        Map<String, DynamicColumnSetter> setterMap = setupSetters(pageBuilder, task.getSchemaConfig(),
                timestampParsers, taskSource.loadTask(PluginTaskFormatter.class));

        while (input.nextFile()) {
            while (true) {
                String line = lineDecoder.poll();
                if (line == null) {
                    break;
                }
                Matcher matcher = pattern.matcher(line);
                if (!matcher.matches()) {
                    if (task.getSkipIfUnmatch()) {
                        // TODO: How to Log?
                        continue;
                    } else {
                        throw new RuntimeException("Unmatched Line: " + line);
                    }
                }

                for (Map.Entry<String, DynamicColumnSetter> pair : setterMap.entrySet()) {
                    String value = matcher.group(pair.getKey());
                    if (value == null) {
                        pair.getValue().setNull();
                    } else {
                        pair.getValue().set(value);
                    }
                }
                pageBuilder.addRecord();
            }
        }
        pageBuilder.finish();
    }

    private Map<String, DynamicColumnSetter> setupSetters(PageBuilder pageBuilder,
                                                          SchemaConfig schema,
                                                          TimestampParser[] timestampParsers,
                                                          TimestampFormatter.Task formatterTask) {
        Map<String, DynamicColumnSetter> setterMap = new HashMap<>();

        int index = -1;
        for (ColumnConfig c : schema.getColumns()) {
            index++;
            String name = c.getName();
            Type type = c.getType();
            Column column = c.toColumn(index);


            DefaultValueSetter defaultValue = new NullDefaultValueSetter();
            DynamicColumnSetter setter;

            if (type instanceof BooleanType) {
                setter = new BooleanColumnSetter(pageBuilder, column, defaultValue);

            } else if (type instanceof LongType) {
                setter = new LongColumnSetter(pageBuilder, column, defaultValue);

            } else if (type instanceof DoubleType) {
                setter = new DoubleColumnSetter(pageBuilder, column, defaultValue);

            } else if (type instanceof StringType) {
                TimestampFormatter formatter = new TimestampFormatter(formatterTask,
                        Optional.of(c.getOption().loadConfig(TimestampColumnOption.class)));
                setter = new StringColumnSetter(pageBuilder, column, defaultValue, formatter);

            } else if (type instanceof TimestampType) {
                // TODO use flexible time format like Ruby's Time.parse
                TimestampParser parser = timestampParsers[column.getIndex()];
                setter = new TimestampColumnSetter(pageBuilder, column, defaultValue, parser);

            } else {
                throw new ConfigException("Unknown column type: " + type);
            }
            setterMap.put(name, setter);
        }

        return setterMap;
    }

}



