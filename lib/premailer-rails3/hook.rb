module PremailerRails
  class Hook
    def self.delivering_email(message)
      # If the mail only has one part, it may be stored in message.body. In that
      # case, if the mail content type is text/html, the body part will be the
      # html body.
      if message.html_part
        html_body = message.html_part.body.to_s
      elsif message.content_type =~ /text\/html/
        html_body = message.body.to_s
        message.body = nil
      end


      if html_body
        text_part = message.text_part
        message.body = nil # otherwise we get two text/html parts into the mail

        premailer = Premailer.new(html_body)
        charset   = message.charset
        
        message.html_part do
          content_type "text/html; charset=#{charset}"
          body premailer.to_inline_css
        end

        if text_part
          message.text_part = text_part
        else
          message.text_part do
            content_type "text/plain; charset=#{charset}"
            body premailer.to_plain_text
          end
        end
      end
    end
  end
end
