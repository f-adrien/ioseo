class ImagesController < ApplicationController
  before_action :set_image, only: [:destroy]

  # GET /images
  def index
    @images = Image.order(created_at: :desc)
  end

  # GET /images/new
  def new
    @image = Image.new
  end

  # POST /images
  def create
    @image = Image.new(image_params)
    if @image.save
      # Enqueue the single-image job if needed:
      ProcessImageJob.perform_later(@image.id)
      redirect_to images_path, notice: 'Image uploaded and is being processed.'
    else
      render :new
    end
  end

  # POST /images/bulk_process
  def bulk_process
    if params[:image_ids].present?
      BulkProcessImagesJob.perform_later(params[:image_ids])
      redirect_to images_path, notice: 'Bulk processing initiated.'
    else
      redirect_to images_path, alert: 'Please select at least one image.'
    end
  end

  # DELETE /images/:id
  def destroy
    @image.destroy
    redirect_to images_path, notice: 'Image deleted successfully.'
  end

  private

  def set_image
    @image = Image.find(params[:id])
  end

  def image_params
    params.require(:image).permit(:output_format, :include_seo_terms, :seo_terms, :resize_width, :quality, :file)
  end
end
