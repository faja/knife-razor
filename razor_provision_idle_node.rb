require 'chef/knife'
require 'net/http'
require 'json'

module Razor
  class RazorProvisionIdleNode < Chef::Knife

    banner "knife razor provision idle node NODE MACADDRESS [ROLE] [-e ENVIRONMENT] [-o OS]"
   
    option :os,
      :short       => "-o ATTR",
      :long        => "--os ATTR",
      :description => "OS type and version - default is centos6",
      :default     => "centos6"
    
    option :env,
      :short       => "-e ATTR",
      :long        => "--environment ATTR",
      :description => "Set Chef environment",
      :default     => "_default"

    def run
      # grab arguments and options
      node_name    = @name_args[0]
      macaddress   = @name_args[1]
      role_name    = @name_args[2]
      os           = config[:os]
      env          = config[:env]
      node_matcher = 'macaddress'

      # node argument is required
      if node_name.nil?
        ui.fatal("You must specify a node name")
        exit 1
      end

      # chef if node exist in chef
      if Chef::Search::Query.new.search(:node, "name:#{node_name}")[2] > 0
        ui.fatal("Node '#{ui.color(node_name,:cyan)}' exists in chef.")
        ui.fatal("Use '#{ui.color('knife razor provision chef node',:cyan)}' instead.")
        exit 1
      end

      # macaddress argument is required
      if macaddress.nil?
        ui.fatal("You must specify a mac address")
        exit 1
      else
        macaddress = macaddress.upcase
      end
      # validate macaddress
      if not macaddress =~ /^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$/
        ui.fatal "Wrong macaddress format."
        exit 1
      end

      # check if role argument was specified and if so, check if role exists in chef server
      if role_name.nil?
        ui.warn("No Role specified.")
        role_name = ''
      else
        role_name.split(',').each do |role|
          role_test = Chef::Role.load(role)
        end
      end

      razor_api = Chef::Config[:knife][:razor_api] || '127.0.0.1:8026'
      
      # chef if model exist in RAZOR
      if not model_uuid = Razor.get_object_uuid(razor_api,'model','label',os)
        ui.fatal "There is no model #{ui.color(os,:cyan)} in RAZOR, please create one first."
        exit 1
      end
      
      # chef if environment exist in chef
      if Chef::Search::Query.new.search(:environment, "name:#{env}")[2] == 0
        ui.fatal("There is no environment '#{ui.color(env,:cyan)}' in chef.")
        exit 1
      end

      # chef if chef environment exist in RAZOR
      if not broker_uuid = Razor.get_object_uuid(razor_api,'broker','name',env)
        ui.fatal "There is no environment #{ui.color(env,:cyan)} in RAZOR, please create one first."
        exit 1
      end

      ui.msg "Knife Razor Provision Idle Node!\n"
      ui.msg "Node: #{ui.color(node_name,:cyan)}"
      ui.msg "Mac address:#{ui.color(macaddress,:cyan)}"
      ui.msg "Environment: #{ui.color(env,:cyan)}"
      ui.msg "Role(s): #{ui.color(role_name,:cyan)}"
      ui.msg "OS: #{ui.color(os,:cyan)}\n\n"

      if tag_uuid = Razor.get_object_uuid(razor_api,'tag','name',node_name)
      # remove existing tags
        tag_uuid.each do |uuid|
          Razor.delete_object(razor_api,'tag',uuid)
        end
      end

      if policy_uuid = Razor.get_object_uuid(razor_api,'policy','label',node_name)
        # delete policy
        policy_uuid.each do |uuid|
          Razor.delete_object(razor_api,'policy',uuid)
        end
      end
      # create policy      

      if active_model_uuid = Razor.get_object_uuid(razor_api,'active_model','label',node_name)
        # delete policy
        active_model_uuid.each do |uuid|
          Razor.delete_object(razor_api,'active_model',uuid)
        end
      end
 
      # create tag
      tag_list = []
      tag_list << node_name.gsub(/\./,'_')
      role_name.split(',').each do |role|
        tag_list << "role__#{role}"
      end

      tag_list.each do |tag|
        json_hash = {"name" => node_name, "tag" => tag }
        tag_uuid = Razor.create_object(razor_api,'tag',json_hash)
        ui.msg "Tag '#{ui.color(tag,:cyan)}' created with UUDI '#{ui.color(tag_uuid,:cyan)}'"
      
        # create matcher
        json_hash = { 
          "key"     => node_matcher+'_eth0',
          "compare" => "equal",
          "value"   => macaddress,
          "invert"  => "false"
         }
         Razor.create_object(razor_api,"tag/#{tag_uuid}/matcher",json_hash)
         ui.msg "Matcher '#{ui.color(node_matcher,:cyan)}' => '#{ui.color(macaddress,:cyan)}' added."
       end
       # create policy
       json_hash = {
         "model_uuid"  => model_uuid[0],
         "broker_uuid" => broker_uuid[0],
         "label"       => node_name,
         "tags"        => tag_list.join(','),
         "template"    => "linux_deploy",
         "maximum"     => "1",
         "enabled"     => "true"
       }
       policy_uuid = Razor.create_object(razor_api,'policy',json_hash)
       ui.msg "Policy '#{ui.color(node_name,:cyan)}' created with UUDI '#{ui.color(policy_uuid,:cyan)}'"

      ui.msg "\nRazor prepared, please restart node: #{ui.color(node_name,:cyan)} and boot it using #{ui.color('PXE',:cyan)}." 
    end

  end
end
