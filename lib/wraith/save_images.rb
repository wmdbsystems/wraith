require "parallel"
require "shellwords"
require "wraith"
require "wraith/helpers/capture_options"
require "wraith/helpers/logger"
require "wraith/helpers/save_metadata"
require "wraith/helpers/utilities"

class Wraith::SaveImages
  include Logging
  attr_reader :wraith, :history, :meta

  def initialize(config, history = false, yaml_passed = false)
    @wraith = Wraith::Wraith.new(config, yaml_passed)
    @history = history
    @meta = SaveMetadata.new(@wraith, history)
  end

  def check_paths
    if !wraith.paths
      path = File.read(wraith.spider_file)
      eval(path)
    else
      wraith.paths
    end
  end

  def save_images
    jobs = define_jobs
    parallel_task(jobs)
  end

  def define_jobs
    jobs = []
    check_paths.each do |label, options|
      settings = CaptureOptions.new(options, wraith)

      if settings.resize
        jobs = jobs + define_individual_job(label, settings, wraith.widths, options)
      else
        wraith.widths.each do |width|
          jobs = jobs + define_individual_job(label, settings, width, options)
        end
      end
    end
    jobs
  end

  def define_individual_job(label, settings, width, options)
    base_file_name    = meta.file_names(width, label, meta.base_label)
    compare_file_name = meta.file_names(width, label, meta.compare_label)

    jobs = []
    jobs << [label, settings.path, prepare_widths_for_cli(width), settings.base_url,    base_file_name,    settings.selector, wraith.before_capture, settings.before_capture, options]
    jobs << [label, settings.path, prepare_widths_for_cli(width), settings.compare_url, compare_file_name, settings.selector, wraith.before_capture, settings.before_capture, options] unless settings.compare_url.nil?

    jobs
  end

  def prepare_widths_for_cli(width)
    # prepare for the command line. [30,40,50] => "30,40,50"
    width = width.join(',') if width.is_a? Array
    width
  end

  def run_command(command)
    output = []
    IO.popen(command).each do |line|
      logger.info line
      output << line.chomp!
    end.close
    output
  end

  def parallel_task(jobs)
    Parallel.each(jobs, :in_threads => 8) do |_label, _path, width, url, filename, selector, global_before_capture, path_before_capture, options|
      begin
        command = construct_command(width, url, filename, selector, global_before_capture, path_before_capture)
        attempt_image_capture(command, filename)
        write_original_url_to_file(File.dirname(filename), options)
      rescue => e
        logger.error e
        create_invalid_image(filename, width)
      end
    end
  end

  def write_original_url_to_file(directory, options)
    orig_url_file = directory + '/url.txt'
    # logger.info "Write " + options + " to " + orig_url
    File.open(orig_url_file, "w") { |file| file.write(options) }
  end

  def construct_command(width, url, file_name, selector, global_before_capture, path_before_capture)
    width    = prepare_widths_for_cli(width)
    selector = selector.gsub '#', '\#' # make sure id selectors aren't escaped in the CLI
    global_before_capture = convert_to_absolute global_before_capture
    path_before_capture   = convert_to_absolute path_before_capture

    command_to_run = "#{meta.engine} #{wraith.phantomjs_options} '#{wraith.snap_file}' '#{url}' '#{width}' '#{file_name}' '#{selector}' '#{global_before_capture}' '#{path_before_capture}'"
    logger.debug command_to_run
    command_to_run
  end

  def attempt_image_capture(capture_page_image, filename)
    max_attempts = 5
    max_attempts.times do |i|
      run_command capture_page_image

      if wraith.resize
        return # @TODO - need to check if the image was generated, as per the reload example below
      end

      return if File.exist? filename

      logger.warn "Failed to capture image #{filename} on attempt number #{i + 1} of #{max_attempts}"
    end

    fail "Unable to capture image #{filename} after #{max_attempts} attempt(s)"
  end

  def create_invalid_image(filename, width)
    logger.warn "Using fallback image instead"
    invalid = File.expand_path("../../assets/invalid.jpg", File.dirname(__FILE__))
    FileUtils.cp invalid, filename

    set_image_width(filename, width)
  end

  def set_image_width(image, width)
    `convert #{image.shellescape} -background none -extent #{width}x0 #{image.shellescape}`
  end
end
