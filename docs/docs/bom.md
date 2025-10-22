| title       | Make a BOM                           |
| ----------- | ---------------------------------- |
| description | How to make a Bill of Materials |

# Let's Design a Bill of Mareials!
---
> As you create hardware projects for Blueprint, you will be required to include a BOM, or Bill of Materials, in .csv format. If you have any questions or suggestions, reach out in #blueprint-support or DM @Tanishq Goyal!

--- 
## What is a BOM? Why is this important?


A BOM, or Bill of Materials, is the comprehensive list of ==**all**== required parts that you need to manufacture a finished product. Writing a BOM involves creating a document with a clear, organized structure to list all components, parts, and raw materials needed to manufacture a product. Think of this as a recipe: you need to specify exactly how much of each ingredient is needed, along with accurate costs, to ensure the final product turns out correctly. This is one of the most important parts of an open-source hardware project, as it is impossible to build anything without materials. 

--- 
## What Is Included in Your BOM? 

In industrial BOMs, you will generally include information such as part numbers, part names, descriptions, manufacturer/manufacturing method, etc. If you are interested, check out [this BOM writing guide](https://durolabs.co/blog/bill-of-materials-example/)

![Manufactoring BOM Example!](https://hc-cdn.hel1.your-objectstorage.com/s/v3/fbea41efef552a6cc8830f589c44f6f3f2b8e236_pasted_image_20251017223635.png)
> This is is what industry BOMs look like. Thankfully, you won't have to deal with that for Blueprint! This format is pretty widespread, with robotics teams listing parts similarly as well. 

However, for Blueprint, your BOMs will look vastly different and is much less complex.  Here are the bare minimums for what you need for your Blueprint BOM:

1. Product name
2. Product link
3. Product cost
4. Product amount


That's it! However, a good BOM exceeds the bare minimum requirement. A good BOM may include:

1. Product name
2. Product description
3. Product link
4. Product unit price
5. Product amount
6. Product running total.

I find that this format allows me to track my costs easily. Although the minimum BOM looks simpler, the second example is much easier to actually use and read as you work on your project. 

Here's an example! Note that these are flexible. I also included taxes in order to get the most accurate BOM possible. 

| Item                              | Description        | Quantity | Unit Price ($) | Total Price ($) | URL                                                                                                                  | Running Total ($ with Tax) |     |
| --------------------------------- | ------------------ | -------- | -------------- | --------------- | -------------------------------------------------------------------------------------------------------------------- | -------------------------- | --- |
| Lancer Long Hotend                | Hotend             | 1        | 34.99          | 34.99           | https://peopoly.net/products/magneto-x-lancer-melt-zone?variant=46839304225050                                       | 37.31                      |     |
| CPAP FAN                          | Part-cooling Fan   | 1        | 19.99          | 19.99           | https://www.fabreeko.com/products/cpap-fan-10ws7040-hose-by-mellow                                                   | 58.62                      |     |
| 3010 FAN                          | Hotend Fan         | 1        | 6.69           | 6.69            | https://www.aliexpress.us/item/3256808756746945.html                                                                 | 65.78                      |     |
| BTT Microprobe                    | Bed-Leveling Probe | 1        | 18.99          | 18.99           | https://biqu.equipment/products/microprobe-v1-0-for-b1-printers-h2-extruders-ender-3                                 | 86.00                      |     |
| SKR Mini E3 V3.0                  | MCU                | 1        | 29.98          | 29.98           | https://biqu.equipment/products/bigtreetech-skr-mini-e3-v2-0-32-bit-control-board-for-ender-3?variant=40035469885538 | 117.97                     |     |
| MGN12H Linear Rail Carriage Block | Linear Rail        | 1        | 22.93          | 22.93           | https://www.aliexpress.us/item/2251832643511407.html                                                                 | 142.42                     |     |
| GT2 Timing Belt                   | Belt               | 1        | 2.38           | 2.38            | https://www.aliexpress.us/item/3256805030553800.html                                                                 | 144.96                     |     |


--- 

## How Do I Create a BOM?

Fortunately, there are tools that allow you to easily create a .csv file, without manually writing one. 

Here is an example using Google Sheets. I will use formulas to make the Total Price and Running Total automatically update. 

1. Total Price Formula. This is equivalent to the Unit Price times the quantity. 

![Step_1](https://hc-cdn.hel1.your-objectstorage.com/s/v3/19deaef50d30d1524066970c1b76a219ad170939_pasted_image_20251017234942.png)

You should then drag the blue circle on the bottom right corner to copy the formulas for the below cells. For more information on formatting with Google Sheets, check out this [basic Google Sheets formula guide!](https://www.youtube.com/watch?v=llkP9DxRAPI) 

2. Running Total.
   
This calculation represents the cumulative total of purchases including sales tax. The formula is:

**Running Total = (Total Price × (1 + Sales Tax Rate)) + Previous Running Total**

###### Example: New Jersey Sales Tax (6.625%)

**Formula Structure:**
- **Tax Multiplier:** `1.06625 (1 + 0.06625)`
- **Rounding:** Applied to nearest cent using `ROUND` function
- **First Item:** `=ROUND(Total Price × 1.06625, 2)`
  - **Example:** `=ROUND(D2*1.06625,2)`
  - ![roundingexample.0](https://hc-cdn.hel1.your-objectstorage.com/s/v3/85f4db06f3ed14e960764b7143931e6875eed6f3_pasted_image_20251018003730.png)
- **Subsequent Items:** `=ROUND(Total Price × 1.06625, 2) + Previous Running Total`
  - **Example:** `=ROUND(D3*1.06625,2)+G2`
  - ![roundingexample.1](https://hc-cdn.hel1.your-objectstorage.com/s/v3/2905b4cb99a86be967c7144cf6372dd936f00b04_pasted_image_20251018003712.png)

--- 

# How do I export my BOM, and put it in Github?

1. Click **File**
2. Select **Download**
3. Choose **Comma separated values (.csv)**

![BOM](https://hc-cdn.hel1.your-objectstorage.com/s/v3/3479c9e12046945013728171f0a0e4d705464fd1_image.png)
