# Shop Items Seed Data
# This populates the shop_items table with all available items from the toolbag

shop_items_data = [
  {
    name: "Wire strippers",
    desc: "A 7-inch wire stripper with a built-in cutter for cleanly removing insulation from electrical wires.",
    ticket_cost: 20,
    usd_cost: 599, # stored in cents
    enabled: true,
    one_per_person: false,
    total_stock: nil,
    image_filename: "wire-strippers.webp",
    link: "https://www.harborfreight.com/7-inch-wire-stripper-with-cutter-98410.html"
  },
  {
    name: "Flush Cutters",
    desc: "Compact micro flush cutters ideal for trimming wire ends and plastic parts with precision.",
    ticket_cost: 20,
    usd_cost: 299,
    enabled: true,
    one_per_person: false,
    total_stock: nil,
    image_filename: "flush-cutters.webp",
    link: "https://www.harborfreight.com/micro-flush-cutter-90708.html"
  },
  {
    name: "Needle-nose pliers",
    desc: "Slim 5-3/4 inch pliers for gripping, bending, and manipulating small wires or components.",
    ticket_cost: 20,
    usd_cost: 299,
    enabled: true,
    one_per_person: false,
    total_stock: nil,
    image_filename: "needle-nose-pliers.webp",
    link: "https://www.harborfreight.com/5-34-in-needle-nose-pliers-63815.html"
  },
  {
    name: "Precision screwdrivers",
    desc: "A 33-piece precision screwdriver set for small electronics and detailed mechanical work.",
    ticket_cost: 40,
    usd_cost: 999,
    enabled: true,
    one_per_person: false,
    total_stock: nil,
    image_filename: "precision-screwdrivers.webp",
    link: "https://www.harborfreight.com/33-piece-precision-screwdriver-set-93916.html"
  },
  {
    name: "Safety Glasses",
    desc: "Clear protective eyewear designed to shield eyes from solder splashes and debris.",
    ticket_cost: 20,
    usd_cost: 500,
    enabled: true,
    one_per_person: false,
    total_stock: nil,
    image_filename: "safety-glasses.webp",
    link: "https://www.harborfreight.com/safety/vision-protection/safety-glasses/safety-glasses-clear-99762.html"
  },
  {
    name: "Digital multimeter",
    desc: "A 7-function multimeter for measuring voltage, current, and resistance in circuits.",
    ticket_cost: 40,
    usd_cost: 799,
    enabled: true,
    one_per_person: false,
    total_stock: nil,
    image_filename: "digital-multimeter.webp",
    link: "https://www.harborfreight.com/electrical/electrician-s-tools/multimeters-testers/7-function-digital-multimeter-59434.html"
  },
  {
    name: "Soldering Iron",
    desc: "A lightweight 30W soldering iron perfect for electronics assembly and repair work.",
    ticket_cost: 20,
    usd_cost: 1000,
    enabled: true,
    one_per_person: false,
    total_stock: nil,
    image_filename: "soldering-iron.webp",
    link: "https://www.harborfreight.com/electrical/electrician-s-tools/soldering-guns-irons/30-watt-lightweight-soldering-iron-69060.html"
  },
  {
    name: "Solder",
    desc: "Lead-free rosin core solder for creating clean and reliable electrical joints.",
    ticket_cost: 15,
    usd_cost: 429,
    enabled: true,
    one_per_person: false,
    total_stock: nil,
    image_filename: "solder.webp",
    link: "https://www.harborfreight.com/lead-free-rosin-core-solder-69378.html"
  },
  {
    name: "Fume extractor",
    desc: "Compact fume extractor with a replaceable filter for safe soldering environments.",
    ticket_cost: 100,
    usd_cost: 2899,
    enabled: true,
    one_per_person: false,
    total_stock: nil,
    image_filename: "fume-extractor.webp",
    link: "https://www.amazon.com/ToolBud-Extractor-Removable-High-Efficiency-Soldering/dp/B0DZXFJL51"
  },
  {
    name: "Helping Hands",
    desc: "A soldering aid with adjustable clips and a magnifier to hold components in place.",
    ticket_cost: 20,
    usd_cost: 599,
    enabled: true,
    one_per_person: false,
    total_stock: nil,
    image_filename: "helping-hands.webp",
    link: "https://www.harborfreight.com/helping-hands-60501.html"
  },
  {
    name: "Solder wick",
    desc: "Copper braid used for desoldering and removing excess solder from circuit boards.",
    ticket_cost: 15,
    usd_cost: 465,
    enabled: true,
    one_per_person: false,
    total_stock: nil,
    image_filename: "solder-wick.webp",
    link: "https://www.amazon.com/JoTownCand-Premium-Desoldering-Residue-Solder/dp/B0DRN688Q5"
  },
  {
    name: "Heat gun",
    desc: "1500-watt dual-temperature heat gun for heat-shrinking, paint removal, and solder reflow.",
    ticket_cost: 70,
    usd_cost: 1999,
    enabled: true,
    one_per_person: false,
    total_stock: nil,
    image_filename: "heat-gun.webp",
    link: "https://www.harborfreight.com/1500-watt-11-amp-dual-temperature-heat-gun-56434.html"
  },
  {
    name: "Bench power supply",
    desc: "Adjustable 30V 10A bench power supply for testing circuits with precise voltage control.",
    ticket_cost: 120, # Updated from controller's 200 to match spreadsheet
    usd_cost: 6500,
    enabled: true,
    one_per_person: false,
    total_stock: nil,
    image_filename: "bench-power-supply.webp",
    link: "https://www.temu.com/-power-supply-variable-30v-10a-bench-power-supply-with-output-switch-short-circuit-alarm-adjustable-switching-regulated-power-supply-with-4---display-usb--interface--g-601099717219435.html"
  },
  {
    name: "3d printer filament",
    desc: "High-quality PLA filament compatible with most FDM 3D printers for strong, smooth prints.",
    ticket_cost: 75,
    usd_cost: 2500,
    enabled: true,
    one_per_person: false,
    total_stock: nil,
    image_filename: "3d-printer-filament.webp",
    link: nil
  },
  {
    name: "Mini hot-plate",
    desc: "Compact electric hot plate for preheating PCBs and assisting in solder reflow processes.",
    ticket_cost: 40,
    usd_cost: 1200,
    enabled: true,
    one_per_person: false,
    total_stock: nil,
    image_filename: "mini-hot-plate.webp",
    link: "https://www.aliexpress.us/item/3256808909358780.html"
  },
  {
    name: "Silicone Soldering Mat",
    desc: "Heat-resistant silicone mat to protect work surfaces and organize small parts during soldering.",
    ticket_cost: 20,
    usd_cost: 300,
    enabled: true,
    one_per_person: false,
    total_stock: nil,
    image_filename: "silicone-soldering-mat.webp",
    link: "https://www.aliexpress.us/item/3256809840602515.html"
  },
  {
    name: "Ender 3 3d printer",
    desc: "Affordable and reliable FDM 3D printer ideal for hobbyists and rapid prototyping projects.",
    ticket_cost: 520,
    usd_cost: 16899,
    enabled: true,
    one_per_person: false,
    total_stock: nil,
    image_filename: "ender-3-3d-printer.webp",
    link: "https://store.creality.com/products/ender-3-3d-printer-4za7"
  },
  {
    name: "Bambu Lab A1 Mini",
    desc: "Compact 3D printer with automatic calibration and high-speed printing capabilities.",
    ticket_cost: 800,
    usd_cost: 24999,
    enabled: true,
    one_per_person: false,
    total_stock: nil,
    image_filename: "bambu-lab-a1-mini.webp",
    link: "https://us.store.bambulab.com/products/a1-mini"
  },
  {
    name: "Bambu Lab P1S",
    desc: "High-performance enclosed 3D printer designed for speed, reliability, and multi-material support.",
    ticket_cost: 1700,
    usd_cost: 54900,
    enabled: true,
    one_per_person: false,
    total_stock: nil,
    image_filename: "bambu-lab-p1s.webp",
    link: "https://us.store.bambulab.com/products/p1s"
  },
  {
    name: "Bambu Lab H2D (base)",
    desc: "Flagship high-end 3D printer offering industrial-grade precision and advanced automation.",
    ticket_cost: 6000,
    usd_cost: 199900,
    enabled: true,
    one_per_person: false,
    total_stock: nil,
    image_filename: "bambu-lab-h2d-base.webp",
    link: "https://us.store.bambulab.com/products/h2d"
  },
  {
    name: "CNC Router",
    desc: "Precision desktop CNC router for cutting, engraving, and milling wood, plastic, and aluminum.",
    ticket_cost: 1400,
    usd_cost: 44900,
    enabled: true,
    one_per_person: false,
    total_stock: nil,
    image_filename: "cnc-router.webp",
    link: "https://www.sainsmart.com/products/cubiko"
  }
]

puts "Creating shop items..."

shop_items_data.each do |item_data|
  # Extract image filename and link separately as they're not model attributes
  image_filename = item_data.delete(:image_filename)
  link = item_data.delete(:link)

  # Find or create the shop item
  shop_item = ShopItem.find_or_initialize_by(name: item_data[:name])
  shop_item.assign_attributes(item_data)

  if shop_item.save
    puts "✓ Created/Updated: #{shop_item.name}"

    if image_filename
      image_path = Rails.root.join("app", "assets", "images", "shop", image_filename)
      if File.exist?(image_path)
        shop_item.image.purge if shop_item.image.attached?
        File.open(image_path) do |file|
          shop_item.image.attach(
            io: file,
            filename: image_filename,
            content_type: "image/webp"
          )
        end
        puts "  ✓ Uploaded image to ActiveStorage: #{image_filename}"
      else
        puts "  ⚠ Image not found: #{image_path}"
      end
    end
  else
    puts "✗ Failed to create: #{item_data[:name]}"
    puts "  Errors: #{shop_item.errors.full_messages.join(', ')}"
  end
end

puts "\nShop items seed complete!"
puts "Total items: #{ShopItem.count}"
