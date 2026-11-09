# Exercise the Fastfile DSL without building, signing, or contacting Apple.
require 'minitest/autorun'
module UI
  def self.user_error!(message); raise ArgumentError, message; end
end
class FastfileHarness
  attr_reader :scan_options
  def fastlane_version(*); end
  def default_platform(*); end
  def platform(*); yield; end
  def before_all(&block); @before_all = block; end
  def desc(*); end
  def lane(*); end
  def after_all(*); end
  def error(*); end
  def scan(options); @scan_options = options; end
end
class CIFastlaneTest < Minitest::Test
  def setup
    @old = %w[JENKINS_URL CI_IOS_SIMULATOR_UDID].to_h { |k| [k, ENV[k]] }
    @old.each_key { |k| ENV.delete(k) }
    @harness = FastfileHarness.new
    @harness.instance_eval(File.read(File.expand_path('../../Example/fastlane/Fastfile', __dir__)))
  end
  def teardown
    @old.each { |k,v| v ? ENV[k] = v : ENV.delete(k) }
  end
  def test_jenkins_requires_an_owned_simulator
    ENV['JENKINS_URL'] = 'https://jenkins.example/'
    assert_raises(ArgumentError) { @harness.test_on_simulator(false) }
  end
  def test_jenkins_uses_exact_destination_without_device_fallback
    ENV['JENKINS_URL'] = 'https://jenkins.example/'
    ENV['CI_IOS_SIMULATOR_UDID'] = '11111111-1111-1111-1111-111111111111'
    @harness.test_on_simulator(false)
    assert_equal 'platform=iOS Simulator,id=11111111-1111-1111-1111-111111111111', @harness.scan_options[:destination]
    assert_equal true, @harness.scan_options[:skip_detect_devices]
    refute @harness.scan_options.key?(:devices)
  end
  def test_local_missing_device_must_fail_instead_of_fallback
    @harness.test_on_simulator(false)
    assert_equal ['iPhone 11'], @harness.scan_options[:devices]
    assert_equal true, @harness.scan_options[:ensure_devices_found]
  end
  def test_skipped_tests_do_not_require_a_simulator
    ENV['JENKINS_URL'] = 'https://jenkins.example/'
    @harness.test_on_simulator(true)
    assert_nil @harness.scan_options
  end
end
