class CreateImages < ActiveRecord::Migration[7.1]
  def change
    create_table :images do |t|
      t.string :output_format
      t.integer :resize_width
      t.integer :resize_height
      t.integer :quality
      t.string :language
      t.string :alt_text
      t.string :seo_terms

      t.timestamps
    end
  end
end
