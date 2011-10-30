module PremailerRails
  class Premailer < ::Premailer
    @@_css_cache = {}

    def initialize(html)
      load_html(html)
      options = {
        :with_html_string => true,
        :adapter          => :hpricot, # Nokogiri will not work <-- undefined method `at_css'
        :line_length      => 80
      }.merge css_options
      super(html, options)
    end

    def load_html(string)
      # @doc is also used by ::Premailer
      @doc ||= Hpricot(string)
    end

    def to_plain_text
      html_src = ''
      begin
        html_src = @doc.at("body").inner_html
      rescue; end

      html_src = @doc.to_html unless html_src and not html_src.empty?
      
      # These are the lines why we are patching this 'to_plain_text' method
      plain_doc = Nokogiri::HTML(html_src)
      plain_doc.search('.//style').remove    # I think this is a premailer bug. Styles that are "unmergable" are added to the end but NOT removed in the text version
      plain_doc.search('.//img').remove      # Well, we just don't want images converted
      
      convert_to_text(plain_doc.to_html, @options[:line_length], @html_encoding)
    end

    protected

    def css_options
      options = {
        :css => linked_css_files
      }

      if linked_css_files.empty?
        options[:css_string] = default_css_file
      end

      options
    end

    def default_css_file
      # Don't cache in development.
      if Rails.env.development? or not @@_css_cache.include? :default
        @@_css_cache[:default] =
          if defined? Hassle and Rails.configuration.middleware.include? Hassle
            File.read("#{Rails.root}/tmp/hassle/stylesheets/email.css")
          elsif Rails.configuration.try(:assets).try(:enabled)
            Rails.application.assets.find_asset('email.css').body
          else
            File.read("#{Rails.root}/public/stylesheets/email.css")
          end
      end
      @@_css_cache[:default]
    rescue => ex
      puts ex.message
      @@_css_cache[:default] = nil
    end

    # Scan the HTML mailer template for CSS files, specifically link tags with
    # types of text/css (other ways of including CSS are not supported).
    def linked_css_files
      @_linked_css_files ||= @doc.search('link[@type="text/css"]').collect do |l|
        href = l.attributes['href']
        if href.include? '?'
          href[0..(href.index('?') - 1)]
        else
          href
        end
      end
    end
  end
end
