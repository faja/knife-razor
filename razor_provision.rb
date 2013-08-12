require 'chef/knife'
require 'net/http'
require 'json'

module Razor
  class RazorProvision < Chef::Knife

    banner "knife razor provision NODE ROLE[,ROLE,ROLE...]"

    def run
      node_name = @name_args[0]
      if node_name.nil?
        ui.fatal("You must specify a node name")
        exit 1
      end

      node_role = @name_args[1] || Chef::Config[:knife][:razor_base_role]
      if node_role.nil?
        ui.fatal("You must specify a node role")
        exit 1
      end

      node = Chef::Node.load(node_name)
      node_role.split(',').each do |role|
        Chef::Role.load(role)
      end

      razor_api = Chef::Config[:knife][:razor_api] || '127.0.0.1:8026'

      ## tag exist?
      if not Razor.get_object_uuid(razor_api,'tag','name',node_name)
        ui.fatal "There is no razor tag with name #{ui.color(node_name,:cyan)}. I'm done here."
        exit 1
      end

      ## broker exist ?
      if not broker_uuid = Razor.get_object_uuid(razor_api,'broker','name',node_role)
        ui.fatal "There is no razor chef broker with name #{ui.color(node_role,:cyan)}. I'm done here."
        exit 1
      end

      ## policy exist?
      if not policy_uuid = Razor.get_object_uuid(razor_api,'policy','label',node_name)
        ui.fatal "There is no razor policy with name #{ui.color(node_name,:cyan)}. I'm done here."
        exit 1
      end

      json_hash = {"enabled" => 'false', 'broker_uuid' => broker_uuid, 'new_line_number' =>"1"}
      Razor.update_object(razor_api,"policy/#{policy_uuid}",json_hash)

      ui.msg "Policy '#{ui.color(policy_uuid,:cyan)}' for node '#{ui.color(node_name,:cyan)}' updated."
      ui.msg "Ensure that node #{ui.color(node_name,:cyan)} can boot via pxe, then reboot it by '#{ui.color("knife ssh 'name:#{node_name}' 'reboot'",:cyan)}' or manually."
    end

  end
end
