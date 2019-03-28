require 'tempfile'
require 'fileutils'
require 'fastlane/action'
require_relative '../helper/bowl_helper'

module Fastlane
  module Actions
    class SetGradlePropertyAction < Action
      def self.run(params)
        app_project_dir ||= params[:app_project_dir]
        regex = Regexp.new(/(?<key>#{params[:key]}\s+)(?<eql>=\s+)?(?<left>[\'\"]?)(?<value>[a-zA-Z0-9\.\_]*)(?<right>[\'\"]?)(?<comment>.*)/)
        found = false
        Dir.glob("#{app_project_dir}/build.gradle") do |path|
          begin
            temp_file = Tempfile.new('versioning')
            File.open(path, 'r') do |file|
              file.each_line do |line|
                unless line.match(regex) and !found
                  temp_file.puts line
                  next
                end
                line = line.gsub regex, "\\k<key>\\k<eql>\\k<left>#{params[:value]}\\k<right>\\k<comment>"
                found = true
                temp_file.puts line
              end
              file.close
            end
            temp_file.rewind
            temp_file.close
            FileUtils.mv(temp_file.path, path)
            temp_file.unlink
          end
        end
      end

      #####################################################
      # @!group Documentation
      #####################################################
      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :app_project_dir,
                                  env_name: "BOWL_APP_PROJECT_DIR",
                               description: "The path to the application source folder in the Android project (default: android/app)",
                                  optional: true,
                                      type: String,
                             default_value: "android/app"),
          FastlaneCore::ConfigItem.new(key: :key,
                               description: "The property key",
                                      type: String),
          FastlaneCore::ConfigItem.new(key: :value,
                               description: "The property value",
                                      type: String)
        ]
      end

      def self.description
        "Set the value of your project"
      end

      def self.details
        [
          "This action will set the value directly in build.gradle . "
        ].join("\n")
      end

      def self.authors
        ["Benjamin Wulff"]
      end

      def self.is_supported?(platform)
        platform == :android
      end
    end
  end
end
