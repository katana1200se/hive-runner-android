require 'webmock/rspec'
require 'json'

$LOAD_PATH << File.expand_path('../../lib', __FILE__)

ENV['HIVE_CONFIG'] = File.expand_path('../config_with_hivemind', __FILE__)
SPEC_HOME = File.expand_path('..', __FILE__)

def reset_hive options = {}
  ENV['HIVE_CONFIG'] = File.expand_path(options[:config] || 'config_default', SPEC_HOME)

  Hive.module_eval do
    # Reload settings
    Chamber.load(
      basepath: ENV['HIVE_CONFIG'],
      namespaces: { environment: 'test' }
    )

    # Force reconnection to Hive Mind
    @hive_mind = nil
  end
end

def hm_device options
  id = options[:id] || 1
  {
    id: id,
    device_type: options[:device_type] || 'Mobile',
    operating_system_name: options[:os] || 'android',
    version: options[:os_version] || '1,2,3',
    serial: "serial#{id}",
    model: options[:model] || 'Test Model',
    brand: options[:brand] || 'Test Brand',
  }
end

def adb_device options
  id = options[:id] || 1
  dev = DeviceAPI::Android::Device.new(
    serial: "serial#{id}",
    state: 'device',
    version: options[:os_version] || '1.2.3'
  )
  allow(dev).to receive(:wifi_mac_address) { options[:wifi_mac_addresss] || '00:11:22:33:44:%02d' % id }
  allow(dev).to receive(:ip_address) { options[:ip_address] || '192.168.100.%d' % id }
  allow(dev).to receive(:manufacturer) { options[:brand] || 'Test Brand' }
  allow(dev).to receive(:model) { options[:model] || 'Test Model' }
  allow(dev).to receive(:imei) { options[:imei] || '123456%d' % id }
  allow(dev).to receive(:version) { options[:os_version] || '1.2.3' }
  allow(dev).to receive(:get_device_type) { :default }
  dev
end

def mock_devices options
    mac = '11:22:33:44:55:%02d' % options[:id]
    escaped_mac = mac.gsub /:/, '%3A'
    allow(Mac).to receive(:addrs) { [mac] }

    if options[:register_fail]
      stub_request(:post, "http://hivemind/api/devices/register.json").
          with(body: /%5Bmacs%5D%5B%5D=#{escaped_mac}/).
          to_return(:status => 500, :body => '', :headers => {})
    else
      stub_request(:post, "http://hivemind/api/devices/register.json").
          with(body: /%5Bmacs%5D%5B%5D=#{escaped_mac}/).
          to_return(:status => 200, :body => {id: options[:id], connected_devices: options[:hm_devices]}.to_json, :headers => {})
    end

    if options[:poll_fail]
      stub_request(:put, "http://hivemind/api/devices/poll.json").
          with(body: /id%5D=#{options[:id]}/).
          to_return(:status => 500, :body => '', :headers => {})
    else
      stub_request(:put, "http://hivemind/api/devices/poll.json").
          with(body: /id%5D=#{options[:id]}/).
          to_return(:status => 200, :body => {connected_devices: options[:hm_devices]}.to_json, :headers => {})
    end

    allow(DeviceAPI::Android).to receive(:devices) { options[:adb_devices] }
end

RSpec.configure do |config|
  config.before(:each) do
    stub_request(:post, "http://hivemind/api/device_statistics/upload.json").
         to_return(:status => 200, :body => "", :headers => {})

    stub_request(:put, "http://hivemind/api/plugin/hive/connect.json").
         to_return(:status => 200, :body => "", :headers => {})
  end
end