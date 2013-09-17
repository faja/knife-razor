require 'chef/knife'
require 'net/http'
require 'json'

module Razor
  class RazorProvisionChefNode < Chef::Knife

    banner "knife razor provision chef node NODE [ROLE{,ROLE,ROLE...}] [-e ENVIRONMENT] [-o OS]"
   
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
      role_name    = @name_args[1]
      os           = config[:os]
      env          = config[:env]
      node_matcher = 'macaddress'
      
      # node argument is required
      if node_name.nil?
        ui.fatal("You must specify a node name")
        exit 1
      end
      # just check if node exists in chef server
      node = Chef::Node.load(node_name)

      # check if role argument was specified and if so, check if role exists in chef server
      if role_name.nil?
        ui.warn("No Role specified.")
        role_name = ''
      else
        role_name.split(',').each do |role|
          role_test = Chef::Role.load(role)
        end
      end

      # grab matcher_value from node attributes
      if node.attribute?(node_matcher)
        matcher_value = node.automatic_attrs[node_matcher]
      else
        ui.fatal("Couldn't find '#{ui.color(node_matcher, :cyan)}' attribute for node '#{ui.color(node_name, :cyan)}'. I'm done here.")
        exit 1
      end
      
      # chef if environment exist in chef
      if Chef::Search::Query.new.search(:environment, "name:#{env}")[2] == 0
        ui.fatal("There is no environment '#{ui.color(env,:cyan)}' in chef.")
        exit 1
      end

      razor_api = Chef::Config[:knife][:razor_api] || '127.0.0.1:8026'
      # check if model exists in razor
      if not model_uuid = Razor.get_object_uuid(razor_api,'model','label',os)
        ui.fatal "There is no model #{ui.color(os,:cyan)} in RAZOR, please create one first."
        exit 1
      end

      # check if environment exists in razor
      if not broker_uuid = Razor.get_object_uuid(razor_api,'broker','name',env)
        ui.fatal "There is no environment #{ui.color(env,:cyan)} in RAZOR, please create one first."
        exit 1
      end

      ui.msg "Knife Razor Provision Chef Node!\n"
      ui.msg "Node: #{ui.color(node_name,:cyan)}"
      ui.msg "Environment: #{ui.color(env,:cyan)}"
      ui.msg "Role: #{ui.color(role_name,:cyan)}"
      ui.msg "OS: #{ui.color(os,:cyan)}\n\n"

      # remove existing tags
      if tag_uuid = Razor.get_object_uuid(razor_api,'tag','name',node_name)
        tag_uuid.each do |uuid|
          Razor.delete_object(razor_api,'tag',uuid)
        end
      end

      # remove existing policy
      if policy_uuid = Razor.get_object_uuid(razor_api,'policy','label',node_name)
        policy_uuid.each do |uuid|
          Razor.delete_object(razor_api,'policy',uuid)
        end
      end

      if active_model_uuid = Razor.get_object_uuid(razor_api,'active_model','label',node_name)
        # delete policy
        active_model_uuid.each do |uuid|
          Razor.delete_object(razor_api,'active_model',uuid)
        end
      end
 
      # tag list
      tag_list = []
      tag_list << node_name.gsub(/\./,'_')
      role_name.split(',').each do |role|
        tag_list << "role__#{role}"
      end

      # create tags
      tag_list.each do |tag|
        json_hash = {"name" => node_name, "tag" => tag}
        tag_uuid = Razor.create_object(razor_api,'tag',json_hash)
        ui.msg "Tag '#{ui.color(tag,:cyan)}' created with UUDI '#{ui.color(tag_uuid,:cyan)}'"

      # create matcher
        json_hash = { 
          "key"     => node_matcher+'_eth0',
          "compare" => "equal",
          "value"   => matcher_value,
          "invert"  => "false"
        }
        Razor.create_object(razor_api,"tag/#{tag_uuid}/matcher",json_hash)
        ui.msg "Matcher '#{ui.color(node_matcher,:cyan)}' => '#{ui.color(matcher_value,:cyan)}' added."
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
      ui.msg "#{ui.color('IMPORTANT!',:red)} Remember to #{ui.color('REMOVE',:red)} client #{ui.color(node_name,:red)} from CHEF SERVER by 'knife client delete #{node_name}' command"
    end

  end
end
