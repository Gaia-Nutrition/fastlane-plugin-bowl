require 'tempfile'
require 'fileutils'
require 'fastlane/action'
require_relative '../helper/bowl_helper'

module Fastlane
  module Actions
    class GetGradlePropertyAction < Action
      def self.run(params)
        app_project_dir ||= params[:app_project_dir]
        regex = Regexp.new(/(?<key>#{params[:key]}\s+)(?<eql>=\s+)?(?<left>[\'\"]?)(?<value>[a-zA-Z0-9\.\_]*)(?<right>[\'\"]?)(?<comment>.*)/)
        value = ""
        found = false
        Dir.glob("#{app_project_dir}/build.gradle") do |path|
          begin
            File.open(path, 'r') do |file|
              file.each_line do |line|
                unless line.match(regex) and !found
                  next
                end
                key, eql, left, value, right, comment = line.match(regex).captures
                break
              end
              file.close
            end
          end
        end
        return value
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
                                      type: String)
        ]
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
