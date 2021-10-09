require_relative "../../utils/test-builder.rb"

require 'test/unit'
extend Test::Unit::Assertions

test = TestBuilder.new("007-mutable-var")

test.compileElby(File.join(File.dirname(__FILE__), 'main.lb')) { |cOut|
    test.compileC(cOut) { |executable|
        test.executeWithStatus(executable) { |status|
            assert_equal(3, status.exitstatus)
        }
    }
}
