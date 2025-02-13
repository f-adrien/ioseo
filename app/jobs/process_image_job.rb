# app/jobs/process_image_job.rb
class ProcessImageJob < ApplicationJob
  queue_as :default

  def perform(image_id)
    puts "Starting ProcessImageJob for image ID: #{image_id}"
    image = Image.find(image_id)
    return unless image.file.attached?

    puts 'Image file attached, downloading...'
    downloaded_file = image.file.download

    require 'mini_magick'
    processed = MiniMagick::Image.read(downloaded_file)
    puts 'File downloaded and read by MiniMagick'

    new_format = image.output_format.presence || 'webp'
    processed.format(new_format)
    puts "Image format set to #{new_format}"

    processed.strip
    puts 'Image metadata stripped'

    processed.quality image.quality.presence || 75
    puts 'Image quality set to 75'

    if image.resize_width.present?
      processed.resize "#{image.resize_width}x"
      puts "Image resized to width: #{image.resize_width}"
    end

    # (Optional) If you need the original file URL for something else:
    image_url = Rails.application.routes.url_helpers.rails_blob_url(
      image.file, only_path: false, host: 'https://ioseo.s3.eu-west-3.amazonaws.com/'
    )
    puts "Generated public URL for the original file: #{image_url}"

    # Generate alt text using the modified (processed) image.
    image_data = generate_image_data(processed, image)
    image.update(alt_text: image_data['alt'])
    puts "Alt-text generated and updated: #{image_data['alt']}"

    seo_filename = "#{image_data['name'].parameterize}.#{new_format}"
    puts "SEO-friendly filename: #{seo_filename}"

    new_blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(processed.to_blob),
      filename: seo_filename,
      content_type: processed.mime_type
    )
    image.processed_file.attach(new_blob)
    puts 'Processed file attached successfully'
  rescue StandardError => e
    puts "Error processing image #{image_id}: #{e.message}"
  end

  private

  def generate_image_data(processed_image, image)
    puts 'Generating alt text using GPT-4 Vision...'

    # Convert the modified image to a binary blob and encode it in Base64.
    base64_image = Base64.strict_encode64(processed_image.to_blob)
    ext = image.file.filename.extension || processed_image.type.to_s.split('/').last || 'jpeg'
    data_url = "data:image/#{ext};base64,#{base64_image}"

    # Build the messages array for the API.
    prompt_text = "Provide a creative and consistent SEO-optimized alt-text and name without extension for this image in #{image.language}. Your response must only contain a string like this: {\"alt\": \"Alt text here\", \"name\": \"Filename here\"}."

    if image.seo_terms.present?
      prompt_text += " Also, include the following SEO keywords in a subtle way: #{image.seo_terms}."
    end

    messages = [
      {
        'type' => 'text',
        'text' => prompt_text
      },
      {
        'type' => 'image_url',
        'image_url' => { 'url' => data_url, 'detail' => 'auto' }
      }
    ]

    client = OpenAI::Client.new(
      access_token: Rails.application.credentials.dig(:openai, :api_key),
      log_errors: true
    )

    # NOTE: Adjust the API parameters if necessary for the GPT-4 Vision API.
    response = client.chat(
      parameters: {
        model: 'gpt-4o',
        messages: [
          { role: 'user', content: messages }
        ]
      }
    )
    image_data = JSON.parse(response.dig('choices', 0, 'message', 'content').to_s.strip)
    puts "Image data  received: #{image_data}"
    image_data
  rescue StandardError => e
    puts "Error generating alt text: #{e.message}"
    'Optimized image'
  end
end
