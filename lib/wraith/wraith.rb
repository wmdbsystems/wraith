require "yaml"
require "wraith/helpers/logger"
require "wraith/helpers/utilities"

class Wraith::Wraith
  include Logging
  attr_accessor :config

  def initialize(config, yaml_passed = false)
    @config = yaml_passed ? config : open_config_file(config)
    logger.level = verbose ? Logger::DEBUG : Logger::INFO
  end

  def open_config_file(config_name)
    possible_filenames = [
      config_name,
      "#{config_name}.yml",
      "#{config_name}.yaml",
      "configs/#{config_name}.yml",
      "configs/#{config_name}.yaml"
    ]

    possible_filenames.each do |filepath|
      if File.exist?(filepath)
        config = File.open filepath
        return YAML.load config
      end
    end
    fail ConfigFileDoesNotExistError, "unable to find config \"#{config_name}\""
  end

  def directory
    if !@config["directory"].nil?
      @config["directory"].is_a?(Array) ? "shots/" + @config["directory"].first : "shots/" + @config["directory"]
    else if !@config["project"].nil?
      "shots/" + @config["project"]
    else
      "shots/dummy"
    end
    end
  end

  def history_dir
    @config["history_dir"] || false
  end

  def project
    @config["project"] || ''
  end

  def engine
    engine = @config["browser"] ? @config["browser"] : "casperjs"
    # Legacy support for those using the old style "browser: \n phantomjs: 'casperjs'" configs
    engine = engine.values.first if engine.is_a? Hash
    engine
  end

  def snap_file
    @config["snap_file"] ? convert_to_absolute(@config["snap_file"]) : snap_file_from_engine(engine)
  end

  def snap_file_from_engine(engine)
    path_to_js_templates = File.dirname(__FILE__) + "/javascript"
    case engine
    when "phantomjs"
      path_to_js_templates + "/phantom.js"
    when "casperjs"
      path_to_js_templates + "/casper.js"
    # @TODO - add a SlimerJS option
    else
      logger.error "Wraith does not recognise the browser engine '#{engine}'"
    end
  end

  def before_capture
    @config["before_capture"] ? convert_to_absolute(@config["before_capture"]) : false
  end

  def widths
    @config["screen_widths"]
  end

  def resize
    # @TODO make this default to true, once it's been tested a bit more thoroughly
    @config["resize_or_reload"] ? (@config["resize_or_reload"] == "resize") : false
  end

  def domains
    @config["domains"]
  end

  def base_domain
    domains[base_domain_label]
  end

  def comp_domain
    domains[comp_domain_label]
  end

  def base_domain_label
    domains.keys[0]
  end

  def comp_domain_label
    domains.keys[1]
  end

  def spider_file
    default = @config["spider_file"] ? "spider/" + @config["spider_file"] : "spider/spider.txt"
    if @config["project"].nil?
      default
    else
      "spider/" + @config["project"] + ".txt"
    end
  end

  def spider_days
    @config["spider_days"] ? @config["spider_days"] : 10
  end

  def sitemap
    @config["sitemap"]
  end

  def spider_skips
    @config["spider_skips"]
  end

  def paths
    @config["paths"]
  end

  def fuzz
    @config["fuzz"] ? @config["fuzz"] : "20%"
  end

  def highlight_color
    @config["highlight_color"] ? @config["highlight_color"] : "red"
  end

  def mode
    if %w(diffs_only diffs_first alphanumeric).include?(@config["mode"])
      @config["mode"]
    else
      "diffs_first"
    end
  end

  def threshold
    @config["threshold"] ? @config["threshold"] : 5
  end

  def gallery_template
    default = 'advanced_template'
    if @config["gallery"].nil?
      default
    else
      @config["gallery"]["template"] || default
    end
  end

  def thumb_height
    default = 200
    if @config["gallery"].nil?
      default
    else
      @config["gallery"]["thumb_height"] || default
    end
  end

  def thumb_width
    default = 200
    if @config["gallery"].nil?
      default
    else
      @config["gallery"]["thumb_width"] || default
    end
  end

  def phantomjs_options
    @config["phantomjs_options"]
  end

  def verbose
    # @TODO - also add a `--verbose` CLI flag which overrides whatever you have set in the config
    @config["verbose"] || false
  end
end
