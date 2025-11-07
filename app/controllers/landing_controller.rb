class LandingController < ApplicationController
  allow_unauthenticated_access only: %i[index authed]
  before_action :set_featured_projects

  def index
    if user_logged_in?
      redirect_to home_path
      return
    end

    ahoy.track "landing_visit"

    render layout: false
  end

  def authed
    redirect_to root_path and return unless user_logged_in?

    render "landing/index", layout: false
  end

  def utm_source
    redirect_to root_path
  end

  private

  def set_featured_projects
    @community_projects = [
        {
          title: "Serenity",
          url: "https://github.com/The-UnknownHacker/Serenity",
          image: "https://hc-cdn.hel1.your-objectstorage.com/s/v3/7d356e0df304801e02072f3740b6f05e545adea3_image__28_.png",
          description: "Touch-based drumpad with ESP32-S3, copper PCB sensing, microSD storage, and configurable sound layers",
          author: "The-UnknownHacker"
        },
        {
          title: "CyberTrust",
          url: "https://github.com/Aahil78/CyberTrust",
          image: "https://hc-cdn.hel1.your-objectstorage.com/s/v3/9b742720c3d9744d063ebf16b100c4c3143a2fc4_Image_from_iOS__2_.jpg",
          description: "RP2350A-based USB security key with user presence button and neopixel",
          author: "Aahil78"
        },
        {
          title: "Nexo-BT",
          url: "https://github.com/Arrow-07/NexoBT",
          image: "https://hc-cdn.hel1.your-objectstorage.com/s/v3/9a0505725a9ae6b40626841e47de45d0d1193296_image__27_.png",
          description: "Wireless music receiver with balanced XLR outputs using ESP32 and PCM5102APWR DAC",
          author: "Arrow-07"
        },
        {
          title: "KeyDeck",
          url: "https://github.com/CJBrandi/KeyDeck/",
          image: "https://hc-cdn.hel1.your-objectstorage.com/s/v3/66ad39ad0517dddf1f898374511b821cf32b5a55_APC_0031-hdr.jpg",
          description: "Simple macropad with 2 status LEDs, each button runs a different shortcut",
          author: "CJBrandi"
        },
        {
          title: "bop",
          url: "https://github.com/ShuchirJ/bop",
          image: "https://hc-cdn.hel1.your-objectstorage.com/s/v3/8512795d05da190eeb2e3d020ad350866a647ec9_20251105_213807.jpg",
          description: "Bluetooth audio receiver with line level and headphone level outputs",
          author: "ShuchirJ"
        },
        {
          title: "Fulmen",
          url: "https://github.com/AethelVeritas/Fulmen/tree/main",
          image: "https://hc-cdn.hel1.your-objectstorage.com/s/v3/9c4b16c116de2369826cbeade229397ba3ab4452_image.png",
          description: "Small ergonomic low-profile wireless keyboard, reversible design",
          author: "AethelVeritas"
        },
        {
          title: "Serenity",
          url: "https://github.com/The-UnknownHacker/Serenity",
          image: "https://hc-cdn.hel1.your-objectstorage.com/s/v3/7d356e0df304801e02072f3740b6f05e545adea3_image__28_.png",
          description: "Touch-based drumpad with ESP32-S3, copper PCB sensing, microSD storage, and configurable sound layers",
          author: "The-UnknownHacker"
        },
        {
          title: "CyberTrust",
          url: "https://github.com/Aahil78/CyberTrust",
          image: "https://hc-cdn.hel1.your-objectstorage.com/s/v3/9b742720c3d9744d063ebf16b100c4c3143a2fc4_Image_from_iOS__2_.jpg",
          description: "RP2350A-based USB security key with user presence button and neopixel",
          author: "Aahil78"
        },
        {
          title: "Nexo-BT",
          url: "https://github.com/Arrow-07/NexoBT",
          image: "https://hc-cdn.hel1.your-objectstorage.com/s/v3/9a0505725a9ae6b40626841e47de45d0d1193296_image__27_.png",
          description: "Wireless music receiver with balanced XLR outputs using ESP32 and PCM5102APWR DAC",
          author: "Arrow-07"
        },
        {
          title: "KeyDeck",
          url: "https://github.com/CJBrandi/KeyDeck/",
          image: "https://hc-cdn.hel1.your-objectstorage.com/s/v3/66ad39ad0517dddf1f898374511b821cf32b5a55_APC_0031-hdr.jpg",
          description: "Simple macropad with 2 status LEDs, each button runs a different shortcut",
          author: "CJBrandi"
        },
        {
          title: "bop",
          url: "https://github.com/ShuchirJ/bop",
          image: "https://hc-cdn.hel1.your-objectstorage.com/s/v3/8512795d05da190eeb2e3d020ad350866a647ec9_20251105_213807.jpg",
          description: "Bluetooth audio receiver with line level and headphone level outputs",
          author: "ShuchirJ"
        }
      ]

    @pro_projects = [
        {
          title: "Serenity",
          url: "https://github.com/The-UnknownHacker/Serenity",
          image: "featured/serenity.webp",
          description: "Touch-based drumpad with ESP32-S3, copper PCB sensing, microSD storage, and configurable sound layers",
          author: "The-UnknownHacker"
        },
        {
          title: "CyberTrust",
          url: "https://github.com/Aahil78/CyberTrust",
          image: "featured/cybertrust.webp",
          description: "RP2350A-based USB security key with user presence button and neopixel",
          author: "Aahil78"
        },
        {
          title: "Nexo-BT",
          url: "https://github.com/Arrow-07/NexoBT",
          image: "featured/nexo-bt.webp",
          description: "Wireless music receiver with balanced XLR outputs using ESP32 and PCM5102APWR DAC",
          author: "Arrow-07"
        },
        {
          title: "KeyDeck",
          url: "https://github.com/CJBrandi/KeyDeck/",
          image: "featured/keydeck.webp",
          description: "Simple macropad with 2 status LEDs, each button runs a different shortcut",
          author: "CJBrandi"
        },
        {
          title: "bop",
          url: "https://github.com/ShuchirJ/bop",
          image: "featured/bop.webp",
          description: "Bluetooth audio receiver with line level and headphone level outputs",
          author: "ShuchirJ"
        },
        {
          title: "Fulmen",
          url: "https://github.com/AethelVeritas/Fulmen/tree/main",
          image: "featured/fulmen.webp",
          description: "Small ergonomic low-profile wireless keyboard, reversible design",
          author: "AethelVeritas"
        },
        {
          title: "Bicolor Matrix Board",
          url: "https://github.com/picafe/bicolor-matrix",
          image: "featured/bicolor-matrix-board.webp",
          description: "Red and green 32x8 LED matrix with HT16K33A IC",
          author: "picafe"
        },
        {
          title: "Quaero",
          url: "https://github.com/AethelVeritas/Quaero/tree/main",
          image: "featured/quaero.webp",
          description: "Low-profile split ergo keyboard with splay, removable column/number row, and trackpad support",
          author: "AethelVeritas"
        },
        {
          title: "WASP",
          url: "https://github.com/justhar/WASP-OPSI",
          image: "featured/wasp.webp",
          description: "Wi-Fi sensing platform with 8 synchronized ESP32 nodes for AoA, localization, and gesture recognition",
          author: "justhar"
        },
        {
          title: "Athena",
          url: "https://github.com/NotARoomba/Athena",
          image: "featured/athena.webp",
          description: "Advanced flight controller with triple MCU architecture",
          author: "NotARoomba"
        },
        {
          title: "wake",
          url: "https://github.com/JavaScythe/wake/",
          image: "featured/wake.webp",
          description: "Advanced alarm clock with 35 neopixels, ESP32 wifi, speaker, buzzer, and projector",
          author: "JavaScythe"
        },
        {
          title: "Automatic Toilet Paper Folder V2",
          url: "https://github.com/Synaptic-Odyssey/AutomaticToiletPaperFolder_V2",
          image: "featured/automatic-toilet-paper-folder-v2.webp",
          description: "Streamlined product version of the 1st place Highway to Undercity project",
          author: "Synaptic-Odyssey"
        },
        {
          title: "PR Mini Bot",
          url: "https://github.com/tobycm/pr-mini-bot",
          image: "featured/pr-mini-bot.webp",
          description: "Miniature bot mimicking 8339 2025 FRC bot with solar panel and supercaps for power harvesting",
          author: "tobycm"
        },
        {
          title: "VikramSatv0 Electrical Power Sub-system",
          url: "https://github.com/Rishaan2202/VikramSat_Electrical-Power-Sub-System",
          image: "featured/vikramsatv0-electrical-power-sub-system.webp",
          description: "Fully functional EPS for 2U CubeSat project by 14-year-old maker",
          author: "Rishaan2202"
        }
      ]
  end
end
