package org.embulk.parser.regex

import com.google.common.base.Optional
import org.embulk.config.Config
import org.embulk.config.ConfigDefault
import org.embulk.config.ConfigDiff
import org.embulk.config.ConfigSource
import org.embulk.config.Task
import org.embulk.config.TaskSource
import org.embulk.spi.*
import org.embulk.spi.time.TimestampParser
import org.embulk.spi.type.Type
import org.embulk.spi.type.Types
import org.embulk.spi.util.LineDecoder

import java.util.ArrayList

public class RegexParserPlugin : ParserPlugin {
    public interface PluginTask : Task, LineDecoder.DecoderTask, TimestampParser.Task

    override fun transaction(config: ConfigSource, control: ParserPlugin.Control) {
        val task = config.loadConfig(javaClass<PluginTask>())
        val columns = ArrayList<ColumnConfig>()

        columns.add(ColumnConfig("remote_host", Types.STRING, config))
        columns.add(ColumnConfig("method", Types.STRING, config))

        val schema = SchemaConfig(columns).toSchema()
        control.run(task.dump(), schema)
    }

    override fun run(taskSource: TaskSource, schema: Schema, input: FileInput, output: PageOutput) {
        val task = taskSource.loadTask(javaClass<PluginTask>())
        val lineDecoder = LineDecoder(input, task)
        val pageBuilder = PageBuilder(Exec.getBufferAllocator(), schema, output)

        while (input.nextFile()) {
            while (true) {
                val line = lineDecoder.poll() ?: break

                pageBuilder.setString(0, "hoge")
                pageBuilder.setString(1, "fuga")
                pageBuilder.addRecord()
            }
        }
        pageBuilder.finish()

    }
}
