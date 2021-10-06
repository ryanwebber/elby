require_relative "../../utils/test-builder.rb"

require 'test/unit'
extend Test::Unit::Assertions

test = TestBuilder.new("003-simple-if")

test.compileElby(File.join(File.dirname(__FILE__), 'main.lb')) { |cOut|
    test.compileC(cOut) { |executable|
        test.executeWithStatus(executable) { |status|
            assert_equal(0, status.exitstatus)
        }
    }
}
