require 'fastlane/action'
require_relative '../helper/bowl_helper'

LEVEL = 'l'
BLACK = "\e[40m"
WHITE = "\e[107m"
DEFAULT = "\e[49m"
SPACER = "  "

module Fastlane
  module Actions
    module SharedValues
      BOWL_DOWNLOAD_URL = :BOWL_DOWNLOAD_URL
      BOWL_VERSION_LINK = :BOWL_VERSION_LINK
    end

    class BowlAction < Action
      def self.print_qr_code(url)
        require 'rqrcode'
        qrcode = RQRCode::QRCode.new(url)

        width = qrcode.modules.length

        puts WHITE + SPACER * (width + 2) + BLACK

        width.times do |x|
          print WHITE + SPACER
          width.times do |y|
            print (qrcode.is_dark(x,y) ? BLACK : WHITE ) + SPACER
          end
          puts WHITE + SPACER + DEFAULT
        end

        puts WHITE + SPACER * (width + 2) + BLACK
      end

      def self.connection(options)
        require 'faraday'

        foptions = {
          url: options[:base_url]
        }
        Faraday.new(foptions) do |builder|
          builder.request(:multipart)
          builder.request(:url_encoded)
          builder.response(:json, content_type: /\bjson$/)
          builder.adapter(:net_http)
        end
      end

      def self.upload_version(m2m_api_token, build_file, options)
        connection = self.connection(options)

        options[:build_file] = Faraday::UploadIO.new(build_file, 'application/octet-stream') if build_file && File.exist?(build_file)
        
        connection.post do |req|
          req.headers['Accept'] = 'application/json'
          if options[:ipa].nil?
            req.url("/api/apps/android/versions")
          else
            req.url("/api/apps/ios/versions")
          end
          req.headers['X-M2M-Auth-Token'] = m2m_api_token
          req.body = options
        end
      end

      def self.run(params)
        build_file = [
          params[:ipa],
          params[:apk]
        ].detect { |e| !e.to_s.empty? }

        if build_file.nil?
          UI.user_error!("You have to provide a build file (params 'apk' or 'ipa')")
        end

        UI.success('Starting with file(s) upload to BOWL... this could take some time.')

        values = params.values
        m2m_api_token = values.delete(:m2m_api_token)

        values.delete_if { |k, v| v.nil? }

        response = self.upload_version(m2m_api_token, build_file, values)
        case response.status
        when 200...300
          install_url = response.body['installUrl']
          link = response.body['link']

          Actions.lane_context[SharedValues::BOWL_DOWNLOAD_URL] = install_url
          Actions.lane_context[SharedValues::BOWL_VERSION_LINK] = link

          UI.success('Build successfully uploaded to BOWL!')
          UI.success('Scan the QR below to test the version')
          self.print_qr_code(install_url)
          UI.message("Installation Link: #{install_url}") if install_url

          UI.success('Once you\'re happy, approve the new version to make it publicly available')
          UI.message("Link to version: #{link}") if link

        else
          if response.body.to_s.include?("App could not be created")
            UI.user_error!("BOWL has an issue processing this app.")
          else
            UI.user_error!("Error when trying to upload file(s) to BOWL: #{response.status} - #{response.body}")
          end
        end
      end

      def self.description
        "Handles uploads to BOWL backend"
      end

      def self.authors
        ["Benjamin Wulff"]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.details
        # Optional:
        "Soon"
      end

      def self.available_options
        # Define all options your action supports. 
        
        # Below a few examples
        [
          FastlaneCore::ConfigItem.new(key: :m2m_api_token,
                                       env_name: "BOWL_M2M_API_TOKEN", # The name of the environment variable
                                       description: "M2M API Token for UploadToBowlAction", # a short description of this parameter
                                       verify_block: proc do |value|
                                          UI.user_error!("No M2M API token for UploadToBowlAction given, pass using `m2m_api_token: 'token'`") unless (value and not value.empty?)
                                          # UI.user_error!("Couldn't find file at path '#{value}'") unless File.exist?(value)
                                       end),
          FastlaneCore::ConfigItem.new(key: :base_url,
                                       env_name: "BOWL_BASE_URL", # The name of the environment variable
                                       description: "Base Url for UploadToBowlAction", # a short description of this parameter
                                       verify_block: proc do |value|
                                          UI.user_error!("No Base Url for UploadToBowlAction given, pass using `base_url: 'url'`") unless (value and not value.empty?)
                                       end),
          FastlaneCore::ConfigItem.new(key: :apk,
                                        env_name: "BOWL_APK", # The name of the environment variable
                                        description: "Path to your APK file",
                                       default_value: Actions.lane_context[SharedValues::GRADLE_APK_OUTPUT_PATH],
                                       default_value_dynamic: true,
                                       optional: true,
                                       verify_block: proc do |value|
                                         UI.user_error!("Couldn't find apk file at path '#{value}'") unless File.exist?(value)
                                       end,
                                       conflicting_options: [:ipa],
                                       conflict_block: proc do |value|
                                         UI.user_error!("You can't use 'apk' and '#{value.key}' options in one run")
                                       end),
          FastlaneCore::ConfigItem.new(key: :ipa,
                                        env_name: "BOWL_IPA",
                                        description: "Path to your IPA file",
                                        default_value: Actions.lane_context[SharedValues::IPA_OUTPUT_PATH],
                                        default_value_dynamic: true,
                                        optional: true,
                                        verify_block: proc do |value|
                                          UI.user_error!("Couldn't find ipa file at path '#{value}'") unless File.exist?(value)
                                        end,
                                        conflicting_options: [:apk],
                                        conflict_block: proc do |value|
                                          UI.user_error!("You can't use 'ipa' and '#{value.key}' options in one run")
                                        end),
          FastlaneCore::ConfigItem.new(key: :version,
                                       env_name: "BOWL_APP_VERSION",
                                       description: "Version of your IPA or APK file",
                                       is_string: true, # true: verifies the input is a string, false: every kind of value
                                       verify_block: proc do |value|
                                            UI.user_error!("No version key given, pass using `version: 'version'`") unless (value and not value.empty?)
                                        end),
          FastlaneCore::ConfigItem.new(key: :mandatory,
                                       env_name: "BOWL_APP_VERSION_MANDATORY",
                                       description: "Wether this version represents a mandatory update",
                                       is_string: false,
                                       optional: true,
                                       default_value: false) # the default value if the user didn't provide one
        ]
      end

      def self.output
        # Define the shared values you are going to provide
        # Example
        [
          ['BOWL_DOWNLOAD_URL', 'Url of the uploaded build'],
          ['BOWL_VERSION_LINK', 'Link to the uploaded version in BOWL backend']
        ]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.authors
        # So no one will ever forget your contribution to fastlane :) You are awesome btw!
        ["Benjamin Wulff"]
      end

      def self.is_supported?(platform)
        # Adjust this if your plugin only works for a particular platform (iOS vs. Android, for example)
        # See: https://docs.fastlane.tools/advanced/#control-configuration-by-lane-and-by-platform
        #
        # [:ios, :mac, :android].include?(platform)
        true
      end
    end
  end
end
