class Image < ApplicationRecord
  # The originally uploaded file
  has_one_attached :file
  # The processed (converted/optimized) image file
  has_one_attached :processed_file

  # After an image is created, kick off processing.
  after_commit :enqueue_processing, on: :create

  private

  def enqueue_processing
    ProcessImageJob.perform_later(id)
  end
end
