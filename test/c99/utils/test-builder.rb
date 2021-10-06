require 'tmpdir'
require 'open3'

class TestBuilder

    def initialize(name)
        @name = name
    end

    def compileElby (source)
        withTmpDir { |dirname|
            basename = File.basename(source)
            outfile = File.join(dirname, basename ++ ".c")
            stdout, stderr, status = Open3.capture3("elby-compile", "-t", "c", "-o", outfile, source)
            raise "Elby compilation failed: \n\n#{stderr}" unless status.success?

            yield outfile
        }
    end

    def compileC (source)
        outfile = source ++ ".o"
        stdout, stderr, status = Open3.capture3("zig", "cc", "-lc", "-o", outfile, source)
        raise "C compilation failed: \n\n#{stderr}" unless status.success?

        yield outfile
    end

    def executeWithStatus(binary)
        stdout, stderr, status = Open3.capture3(binary)
        yield status
    end

    def withTmpDir()
        dir = Dir.mktmpdir("test_#{@name}_", ENV["ELBY_TEMP_DIR"] || "/tmp")
        yield dir
    end
end
