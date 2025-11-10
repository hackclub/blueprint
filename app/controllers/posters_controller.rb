class PostersController < ApplicationController
  include PosterHelper

  require "prawn"
  require "prawn-svg"
  require "combine_pdf"

  def show
    poster_id = params[:id]

    pdf_data = case poster_id
    when "1"
      generate_poster_1
    when "2"
      generate_poster_2
    else
      return render plain: "Poster not found", status: :not_found
    end

    send_data pdf_data, type: "application/pdf", disposition: "inline", filename: "poster_#{poster_id}.pdf"
  end

  private

  def generate_poster_1
    template_path = Rails.root.join("app", "assets", "1.pdf")
    return render plain: "Template PDF not found", status: :not_found unless File.exist?(template_path)

    combine_with_template(template_path, "https://#{ENV['APPLICATION_HOST']}/r/#{current_user.id}?ref=r")
  end

  def generate_poster_2
    template_path = Rails.root.join("app", "assets", "2.pdf")
    return render plain: "Template PDF not found", status: :not_found unless File.exist?(template_path)

    combine_with_template(template_path, "https://#{ENV['APPLICATION_HOST']}/r/#{current_user.id}?ref=r")
  end

  def combine_with_template(template_path, qr_url)
    prawn_pdf = Prawn::Document.new(page_size: "LETTER") do |pdf|
      add_qr_code_to_pdf(pdf, qr_url, x: 310, y: pdf.bounds.top-269, size: 120)
    end.render

    base = CombinePDF.load(template_path.to_s)
    overlay = CombinePDF.parse(prawn_pdf)

    base.pages.each do |page|
      page << overlay.pages[0]
    end

    base.to_pdf
  end
end
