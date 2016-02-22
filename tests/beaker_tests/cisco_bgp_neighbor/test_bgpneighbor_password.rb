################################################################################
# Copyright (c) 2015 Cisco and/or its affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
################################################################################
#
# TestCase Name:
# -------------
# BgpNeighbor-Provider-password.rb
#
# TestCase Prerequisites:
# -----------------------
# This is a Puppet BGP Neighbor resource testcase for Puppet Agent on Nexus
# devices.
# The test case assumes the following prerequisites are already satisfied:
# A. Host configuration file contains agent and master information.
# B. SSH is enabled on the Agent.
# C. Puppet master/server is started.
# D. Puppet agent certificate has been signed on the Puppet master/server.
#
# TestCase:
# ---------
# This is a BGP Neighbor resource test that tests for password and type
# attributes when created with 'ensure' => 'present'.
#
# The testcode checks for exit_codes from Puppet Agent, Vegas shell and
# Bash shell command executions. For Vegas shell and Bash shell command
# string executions, this is the exit_code convention:
# 0 - successful command execution, > 0 - failed command execution.
# For Puppet Agent command string executions, this is the exit_code convention:
# 0 - no changes have occurred, 1 - errors have occurred,
# 2 - changes have occurred, 4 - failures have occurred and
# 6 - changes and failures have occurred.
#
# Note: 0 is the default exit_code checked in Beaker::DSL::Helpers::on() method.
#
# The testcode also uses RegExp pattern matching on stdout or output IO
# instance attributes to verify resource properties.
#
###############################################################################
# rubocop:disable Style/HashSyntax

# Require UtilityLib.rb and BgpNeighborLib.rb paths.
require File.expand_path('../../lib/utilitylib.rb', __FILE__)

id = 'password'

tests = {
  :master => master,
  :agent  => agent,
  resource_name: 'cisco_bgp_neighbor',
}

test_name "TestCase :: #{tests[:resource_name]} - #{id}" do
  resource_absent_cleanup(agent, 'cisco_bgp')

  os = operating_system
  vrf = 'red'
  neighbor = '1.1.1.1'
  encr_pw = '386c0565965f89de'
  passwords = { :default   => 'test',
                :cleartext => 'test',
              }

  if os == 'ios_xr'
    passwords[:md5] = encr_pw
  else
    passwords['3des'] = encr_pw
  end

  passwords.each do |type, password|
    tests[id] = {
      desc:           "1.1 Password type: #{type}, password: #{password})",
      title_pattern:  "2 #{vrf} #{neighbor}",
      manifest_props: {
        remote_as:     99,
        password_type: type,
        password:      password,
      },
      resource:       {
        'ensure' => 'present'
      },
    }

    if os == 'ios_xr'
      # for XR, just make sure a password is there for types other than md5
      if type == :md5 || type == 'md5'
        tests[id][:resource]['password'] = encr_pw
      else
        tests[id][:resource]['password'] = IGNORE_VALUE
      end
    else
      tests[id][:resource]['password'] = encr_pw
    end

    # NOTE: We can't simply call test_harness_run() here since idempotence
    # test will fail (we can't tell if a password has changed).

    create_manifest_and_resource(tests, id)
    test_manifest(tests, id)
    test_resource(tests, id)

    tests[id][:desc] = '1.2 Test removing the password'
    tests[id][:manifest_props] = {
      :password => ''
    }
    create_manifest_and_resource(tests, id)
    test_manifest(tests, id)

    tests[id][:desc] = '1.3 Verify password has been removed on the box'
    tests[id][:resource] = { 'password' => IGNORE_VALUE }
    test_resource(tests, id, true)
  end

  resource_absent_cleanup(agent, 'cisco_bgp')

  skipped_tests_summary(tests)
end

logger.info("TestCase :: #{tests[:resource_name]} - #{id} :: End")
