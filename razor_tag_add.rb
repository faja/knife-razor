require 'chef/knife'
require 'net/http'
require 'json'

module Razor
  class RazorTagAdd < Chef::Knife
    banner "knife razor tag add NODE"
    
    option :matcher,
      :short       => "-m ATTR",
      :long        => "--matcher ATTR",
      :description => "Define matcher key - default is macaddress",
      :default     => 'macaddress'

    def run
      node_name = @name_args[0]
      node_matcher = config[:matcher]

      if node_name.nil?
        ui.fatal("You must specify a node name")
        exit 1
      end

      node = Chef::Node.load(node_name)
      if node.attribute?(node_matcher)
        matcher_value = node.automatic_attrs[node_matcher]
      else
        ui.fatal("Couldn't find '#{ui.color(node_matcher, :cyan)}' attribute for node '#{ui.color(node_name, :cyan)}'")
        exit 1
      end

      razor_api = Chef::Config[:knife][:razor_api] || '127.0.0.1:8026'
      if tag_uuid = Razor.get_object_uuid(razor_api,'tag','name',node_name)
        ui.confirm("Tag with name #{ui.color(node_name, :cyan)} already exist, do you want to update the matcher")
        if matcher_uuid = Razor.get_matcher_uuid(razor_api,tag_uuid)
          json_hash = {"key" => node_matcher, "value" => matcher_value}
          Razor.update_object(razor_api,"tag/#{tag_uuid}/matcher/#{matcher_uuid}",json_hash)
          ui.msg "Matcher '#{ui.color(node_matcher,:cyan)}' => '#{ui.color(matcher_value,:cyan)}' added."
        else
          json_hash = {
            "key"     => node_matcher,
            "compare" => "equal",
            "value"   => matcher_value,
            "invert"  => "false"
          }
          Razor.create_object(razor_api,"tag/#{tag_uuid}/matcher",json_hash)
          ui.msg "Matcher '#{ui.color(node_matcher,:cyan)}' => '#{ui.color(matcher_value,:cyan)}' added."
        end
      else
        json_hash = {"name" => node_name, "tag" => node_name}
        tag_uuid = Razor.create_object(razor_api,'tag',json_hash)
        ui.msg "Tag '#{ui.color(node_name,:cyan)}' created with UUDI '#{ui.color(tag_uuid,:cyan)}'"
        json_hash = {
          "key"     => node_matcher,
          "compare" => "equal",
          "value"   => matcher_value,
          "invert"  => "false"
        }
        Razor.create_object(razor_api,"tag/#{tag_uuid}/matcher",json_hash)
        ui.msg "Matcher '#{ui.color(node_matcher,:cyan)}' => '#{ui.color(matcher_value,:cyan)}' added."
      end
    end

  end
end
