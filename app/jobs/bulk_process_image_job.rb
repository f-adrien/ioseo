# app/jobs/bulk_process_images_job.rb
require 'base64'
require 'json'

class BulkProcessImagesJob < ApplicationJob
  queue_as :default

  def perform(image_ids)
    images = Image.where(id: image_ids)
    return if images.empty?

    messages_content = []
    # Primary instruction: ask for SEO-optimized descriptions for each image.
    prompt_text = 'For each of the following images, provide a detailed, SEO-optimized description that can be used as alt text and as a filename. Return the results as a JSON object where each key is the image ID and its value is the description.'
    messages_content << { 'type' => 'text', 'text' => prompt_text }

    images.each do |image|
      # Add a short text introduction per image.
      image_intro = "Image ID #{image.id}."
      image_intro += " Keywords: #{image.seo_terms}." if image.seo_terms.present?
      messages_content << { 'type' => 'text', 'text' => image_intro }

      # Download and encode the image.
      downloaded_file = image.file.download
      base64_image = Base64.strict_encode64(downloaded_file)
      ext = image.file.filename.extension || 'jpeg'
      data_url = "data:image/#{ext};base64,#{base64_image}"

      messages_content << { 'type' => 'image_url', 'image_url' => { 'url' => data_url, 'detail' => 'auto' } }
    end

    client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
    response = client.chat(
      parameters: {
        model: 'gpt-4o-mini', # Use the appropriate model supporting Base64 image inputs.
        messages: [
          { role: 'user', content: messages_content }
        ],
        max_tokens: 300
      }
    )

    result_text = response.dig('choices', 0, 'message', 'content').to_s.strip
    # Attempt to parse the result as JSON.
    begin
      alt_texts = JSON.parse(result_text)
    rescue JSON::ParserError => e
      Rails.logger.error "Error parsing bulk alt text response: #{e.message}"
      alt_texts = {}
    end

    # Update each image record with its corresponding alt text.
    images.each do |image|
      if alt_texts[image.id.to_s].present?
        image.update(alt_text: alt_texts[image.id.to_s])
      else
        image.update(alt_text: 'Optimized image')
      end
    end
  rescue StandardError => e
    Rails.logger.error "Error processing bulk images: #{e.message}"
  end
end
