require "wraith"
require "wraith/helpers/logger"
require "anemone"
require "nokogiri"
require "uri"

class Wraith::Spidering
  include Logging
  attr_reader :wraith

  def initialize(config)
    @wraith = Wraith::Wraith.new(config)
  end

  def check_for_paths
    if wraith.paths.nil?
      unless wraith.sitemap.nil?
        logger.info "no paths defined in config, loading paths from sitemap"
        spider = Wraith::Sitemap.new(wraith)
      else
        logger.info "no paths defined in config, crawling from site root"
        spider = Wraith::Crawler.new(wraith)
      end
      spider.determine_paths
    end
  end
end

class Wraith::Spider
  def initialize(wraith)
    @wraith = wraith
    @paths = {}
  end

  def determine_paths
    spider
    write_file
  end

  private

  def write_file
    File.open(@wraith.spider_file, "w+") { |file| file.write(@paths) }
  end

  def add_path(path)
    @paths[path == "/" ? "home" : (path.gsub("/", "__").gsub("?", "__").gsub("=", "__").gsub(".", "__").gsub("&", "__").gsub("%", "__").gsub("$", "__").chomp("__").downcase)[0...200]] = path
  end

  def spider
  end
end

class Wraith::Crawler < Wraith::Spider
  include Logging

  EXT = %w(flv swf png jpg gif asx zip rar tar 7z \
           gz jar js css dtd xsd ico raw mp3 mp4 \
           wav wmv ape aac ac3 wma aiff mpg mpeg \
           avi mov ogg mkv mka asx asf mp2 m1v \
           m3u f4v pdf doc xls ppt pps bin exe rss xml)

  def spider
    if File.exist?(@wraith.spider_file) && modified_since(@wraith.spider_file, @wraith.spider_days)
        logger.info "using existing spider file"
      @paths = eval(File.read(@wraith.spider_file))
    else
      logger.info "creating new spider file"
      Anemone.crawl(@wraith.base_domain) do |anemone|
        anemone.skip_links_like(/\.(#{EXT.join('|')})$/)
        # Add user specified skips
        anemone.skip_links_like(@wraith.spider_skips)
        anemone.on_every_page {
            |page| add_path(page.url.path)
            logger.info "Crawling: " + page.url.path
        }
      end
    end
  end

  def modified_since(file, since)
    (Time.now - File.ctime(file)) / (24 * 3600) < since
  end
end

class Wraith::Sitemap < Wraith::Spider
  include Logging

  def spider
    unless @wraith.sitemap.nil?
      logger.info "reading sitemap.xml from #{@wraith.sitemap}"
      if @wraith.sitemap =~ URI.regexp
        sitemap = Nokogiri::XML(open(@wraith.sitemap))
      else
        sitemap = Nokogiri::XML(File.open(@wraith.sitemap))
      end
      sitemap.css("loc").each do |loc|
        path = loc.content
        # Allow use of either domain in the sitemap.xml
        @wraith.domains.each do |_k, v|
          path.sub!(v, "")
        end
        if @wraith.spider_skips.nil? || @wraith.spider_skips.none? { |regex| regex.match(path) }
          add_path(path)
        end
      end
    end
  end
end
