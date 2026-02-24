#! /usr/bin/env ruby -S rspec

require 'spec_helper'
require 'puppetdb/connection'
require 'puppet/util/puppetdb'

describe 'query_nodes' do
  let(:puppetdb) { double('PuppetDB::Connection') }

  before do
    allow(PuppetDB::Connection).to receive(:check_version)
    allow(PuppetDB::Connection).to receive(:from_uris).and_return(puppetdb)
    allow(Puppet::Util::Puppetdb).to receive_message_chain(:config, :server_urls).and_return([])
  end

  context 'without fact parameter' do
    it do
      expect(puppetdb).to receive(:query)
        .with(:nodes, ['in', 'certname', ['extract', 'certname', ['select_fact_contents', ['and', ['=', 'path', ['hostname']], ['=', 'value', 'apache4']]]]], :extract => :certname)
        .and_return([ { 'certname' => 'apache4.puppetexplorer.io' } ])
      should run.with_params('hostname="apache4"').and_return(['apache4.puppetexplorer.io'])
    end
  end

  context 'with a fact parameter' do
    it do
      expect(puppetdb).to receive(:query)
        .with(:facts, ['and', ['in', 'certname', ['extract', 'certname', ['select_fact_contents', ['and', ['=', 'path', ['hostname']], ['=', 'value', 'apache4']]]]], ['or', ['=', 'name', 'ipaddress']]], :extract => :value)
        .and_return([ { 'value' => '172.31.6.80' } ])
      should run.with_params('hostname="apache4"', 'ipaddress').and_return(['172.31.6.80'])
    end
  end

  context 'with a nested fact parameter' do
    it do
      expect(puppetdb).to receive(:query)
        .with(:facts, ['and', ['in', 'certname', ['extract', 'certname', ['select_fact_contents', ['and', ['=', 'path', ['hostname']], ['=', 'value', 'apache4']]]]], ['or', ['=', 'name', 'networking']]], :extract => :value)
        .and_return([
          {
            'value' => {
              'interfaces' => {
                'eth0' => {
                  'ip' => '172.31.6.80',
                  'network' => '172.31.0.0',
                },
                'eth1' => {
                  'ip' => '172.32.6.80',
                  'network' => '172.32.0.0',
                },
                'bond0' => {},
              }
            }
          }
        ])
      should run.with_params('hostname="apache4"', 'networking.interfaces.eth1.ip').and_return(['172.32.6.80'])
    end
  end

  context 'with a missing nested fact parameter' do
    it do
      expect(puppetdb).to receive(:query)
        .with(:facts, ['and', ['in', 'certname', ['extract', 'certname', ['select_fact_contents', ['and', ['=', 'path', ['hostname']], ['=', 'value', 'apache4']]]]], ['or', ['=', 'name', 'networking']]], :extract => :value)
        .and_return([
          {
            'value' => {
              'interfaces' => {
                'eth0' => {
                  'ip' => '172.31.6.80',
                  'network' => '172.31.0.0',
                },
                'eth1' => {
                  'ip' => '172.32.6.80',
                  'network' => '172.32.0.0',
                },
                'bond0' => {},
              }
            }
          }
        ])
      should run.with_params('hostname="apache4"', 'networking.interfaces.missing_interface.ip').and_return([nil])
    end
  end
end
