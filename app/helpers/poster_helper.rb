module PosterHelper
  def generate_qr_code(content, color: "black")
    require "rqrcode"

    qr = RQRCode::QRCode.new(content)

    qr.as_svg(
      module_size: 6,
      color: color
    )
  end

  def add_qr_code_to_pdf(pdf, content, x:, y:, size:, color: "black")
    qr_svg = generate_qr_code(content, color: color)

    pdf.svg qr_svg, at: [ x, y ], width: size
  end
end
