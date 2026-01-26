class CustomsReceiptTemplate < Phlex::HTML
  include ActiveSupport::NumberHelper

  def initialize(package)
    @package = package
  end

  def view_template
    doctype
    html do
      head do
        meta charset: "UTF-8"
        style { raw safe(css) }
        title { "Customs Receipt – #{@package.tracking_number}" }
      end
      body do
        render_header
        render_shipment_info
        render_contents_table
        render_shipping_info
        render_footer_notes
        render_footer
      end
    end
  end

  private

  def render_header
    img height: 64, style: "display: inline-block; float: left;", src: HC_LOGO
    div style: "display: inline-block; padding-left: 10px;" do
      b { "Sam Liu" }
      br
      plain "Hack Club"
      br
      plain "15 Falls Rd"
      br
      plain "Shelburne, VT 05482"
      br
      plain "United States"
    end
    br
    br
    br
  end

  def render_shipment_info
    div style: "display: inline-block;" do
      b { "Ship to: " }
      pre { @package.recipient_address }
    end
    br
    br
  end

  def render_contents_table
    b { "Contents:" }
    div class: "table" do
      div class: "header" do
        cell { "Item" }
        cell(:right) { "Quantity" }
        cell(:right) { "Value/pc" }
      end
      @package.contents.each do |item|
        row do
          cell { item.name }
          cell(:right) { item.quantity }
          cell(:right) { number_to_currency(item.value) }
        end
      end
      row do
        cell(:right, "grid-column": "span 3") do
          "Total: #{number_to_currency(@package.total_value)}"
        end
      end
    end
  end

  def render_shipping_info
    info "Shipped on: #{@package.created_at.strftime('%Y-%m-%d')} (YYYY-MM-DD)"
    if @package.shipping_cost.present?
      info "Shipping cost: #{number_to_currency(@package.shipping_cost)}"
    end
    info("Original tracking number: #{@package.tracking_number}") if @package.tracking_number.present?
  end

  def render_footer_notes
    br
    info do
      plain "All amounts are given in USD."
      br
      br
      b { "N.B." }
      plain " This shipment is a gift. Valuations are for customs purposes only."
    end
  end

  def render_footer
    p(class: "footer") { "Hack Club is a 501(c)(3) public charity. Our nonprofit EIN is 81-2908499." }
  end

  def cell(align = :left, style = {})
    div class: "cell", style: style.merge(text_align: align.to_s) do
      yield
    end
  end

  def row
    div class: "row" do
      yield
    end
  end

  def info(text = "")
    div class: "info" do
      plain text if text.present?
      yield if block_given?
    end
  end

  def css
    <<~CSS
      body { padding: 16px; color: black; font-family: sans-serif; }
      h4 { font-weight: 400 }
      .table { display: grid; grid-template-columns: 1fr auto auto; width: 100% }
      .table > .header { display: contents; }
      .table .cell { padding: .5px 8px }
      .table > .header > .cell { background: #000; color: #fff; font-weight: 400; text-align: left; }
      .table > .row { display: contents; }
      .table > .row:nth-child(odd) * { background-color: #ececec; }
      td { border: none; }
      img.emoji { margin: 0 .05em 0 .1em; vertical-align: -0.1em; }
      div.info { margin-top: .54em; }
      .footer { font-size: 10pt; color: #999999; position: fixed; bottom: 0px; width: 100%; white-space: nowrap; }
      pre { white-space: pre-wrap; font-family: sans-serif; margin-top: 4px; }
    CSS
  end

  HC_LOGO = "https://assets.hackclub.com/icon-rounded.png"
end
