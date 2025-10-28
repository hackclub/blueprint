# Shop System Documentation

## Overview

The Blueprint Toolbag shop system allows users to spend earned tickets on physical items and tools.

## Database Schema

### ShopItem Model

**Table:** `shop_items`

| Field | Type | Description |
|-------|------|-------------|
| `id` | bigint | Primary key |
| `name` | string | Item name |
| `desc` | string | Item description |
| `ticket_cost` | integer | Cost in tickets |
| `usd_cost` | integer | Cost in USD cents (e.g., 599 = $5.99) |
| `enabled` | boolean | Whether item is available for purchase |
| `one_per_person` | boolean | Limit one per user |
| `total_stock` | integer | Total available stock (null = unlimited) |
| `type` | string | STI type (reserved for future use) |
| `created_at` | datetime | |
| `updated_at` | datetime | |

**Attachments:**
- `image` - ActiveStorage attachment for item photo

## Current Items (21 total)

### Small Tools (15-40 tickets)
- Solder (15 tickets, $4.29)
- Solder wick (15 tickets, $4.65)
- Wire strippers (20 tickets, $5.99)
- Flush Cutters (20 tickets, $2.99)
- Needle-nose pliers (20 tickets, $2.99)
- Safety Glasses (20 tickets, $5.00)
- Soldering Iron (20 tickets, $10.00)
- Helping Hands (20 tickets, $5.99)
- Silicone Soldering Mat (20 tickets, $3.00)
- Precision screwdrivers (40 tickets, $9.99)
- Digital multimeter (40 tickets, $7.99)
- Mini hot-plate (40 tickets, $12.00)

### Mid-Range Tools (70-120 tickets)
- Heat gun (70 tickets, $19.99)
- 3d printer filament (75 tickets, $25.00)
- Fume extractor (100 tickets, $28.99)
- Bench power supply (120 tickets, $65.00)

### Large Equipment (520-6000 tickets)
- Ender 3 3d printer (520 tickets, $168.99)
- Bambu Lab A1 Mini (800 tickets, $249.99)
- CNC Router (1400 tickets, $449.00)
- Bambu Lab P1S (1700 tickets, $549.00)
- Bambu Lab H2D (6000 tickets, $1,999.00)

## Seed Data

Shop items can be populated from the seed file:

```bash
bin/rails runner db/seeds/shop_items.rb
```

This seed file:
- Creates/updates all 21 shop items
- Sets ticket costs and USD costs
- Attempts to attach images from `public/shop/` directory
- Is idempotent (can be run multiple times)

## Controller

**ToolbagController** (`app/controllers/toolbag_controller.rb`)

```ruby
def index
  @items = ShopItem.where(enabled: true).order(:ticket_cost, :name)
end
```

## View

**Location:** `app/views/toolbag/index.html.erb`

Features:
- Displays user's ticket balance
- Shows all enabled items in a grid
- Conditionally enables/disables purchase button based on user's tickets
- Shows item image (if attached) or placeholder
- Sorted by ticket cost (lowest first)

## User Tickets System

### ManualTicketAdjustment Model

Allows manual adjustment of user tickets while maintaining audit trail.

**Table:** `manual_ticket_adjustments`

| Field | Type | Description |
|-------|------|-------------|
| `id` | bigint | Primary key |
| `user_id` | bigint | Foreign key to users |
| `adjustment` | integer | Ticket adjustment (can be negative) |
| `internal_reason` | string | Required explanation |
| `created_at` | datetime | |
| `updated_at` | datetime | |

### Earning Tickets

Users earn tickets through approved BuildReviews:

```ruby
# In User model
def tickets
  build_review_tickets = received_build_reviews
    .approved
    .where(invalidated: false)
    .sum { |br| br.tickets_awarded }

  manual_adjustments = manual_ticket_adjustments.sum(:adjustment)

  build_review_tickets + manual_adjustments
end
```

Tickets are calculated based on:
- Hours logged on the project
- Project tier multiplier
- Optional reviewer adjustments (multiplier/offset)

## TODO: Future Enhancements

- [ ] Add purchase flow and order tracking
- [ ] Implement ShopOrder model to track purchases
- [ ] Add stock management
- [ ] Add one_per_person enforcement
- [ ] Add type field usage (e.g., PhysicalItem, DigitalItem, Credit)
- [ ] Add image upload interface for admins
- [ ] Add link field to store product URLs
- [ ] Add admin interface for managing shop items
