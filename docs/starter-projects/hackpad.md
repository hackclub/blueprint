# Make your own Hackpad!

Made by @alexren


<div class="flex justify-center my-8">
  <img src="https://hc-cdn.hel1.your-objectstorage.com/s/v3/6b9c8661f5ae68437e90d14a214f899759eb30b5_image.png" alt="Hackpad Image" style="width: 40%;" />
</div>


Hey! Want to make your own macropad but have absolutely no clue where to start? You found the right place! In this tutorial, we're going to make a 4-key macropad as an example. **For a full submission, you will have to edit it to be your own** (add extra keys?? a knob?? OLED screen? up to you!)

**Read over the [FAQ](/faq) first so that you have an idea of what you're working with!**

This process is going to be broken into 3 parts, each with its own sub-parts:

- [PCB Design](#pcb-design)
  - [Drawing the schematic](#drawing-the-schematic)
  - [Routing the PCB](#routing-the-pcb)
  - [Adding 3D models](#adding-3d-models)
- [Case Design](#creating-your-case)
  - [Creating the bottom](#creating-the-bottom)
  - [Creating the top](#creating-the-top)
  - [Finishing touches](#finishing-touches)
- [Firmware](#firmware)
  - [KMK!](#kmk)

If you're unsure about anything, send a message in **#hackpad!** We have so many eager people to help. (Please try searching your question in the search bar first.)

There's also [this](/resources) giant wall of resources to reference!


# List of approved parts

Here is the list of parts that come with the kit! Feel free to use anything in it

- Seeed XIAO RP2040 - since you're soldering, you can mount it SMD style! Please note it is significantly harder than doing it through-hole, so if it's your first time soldering I would avoid it.
- Through-hole 1N4148 Diodes (Max 20x)
- MX-Style switches (Max 16x)
- EC11 Rotary encoders (Max 2x)
- 0.91 inch OLED displays (Max 1x) (make sure the pin order is GND-VCC-SCL-SDA, otherwise it WILL NOT WORK)
- Blank DSA keycaps (White)
- SK6812 MINI-E LEDs (Max 16x)
- M3x16mm screws
- [M3x5mx4mm heatset inserts](https://www.aliexpress.us/item/2255800046543591.html)
- 3D PRINTED CASE ONLY. NO ACRYLIC.



## Designing your PCB

For this guide we're going to be using [KiCad](https://www.kicad.org/), which is an open source PCB designer tool.

To start, we're going to have to install the KiCad library! We are going to use the following repository:

- [OPL Kicad Library](https://github.com/Seeed-Studio/OPL_Kicad_Library/)

There are many tutorials on how to install libraries — Google is your best friend here :)

@Cyao in the Slack made an awesome tutorial though!  
Here it is:

[Video tutorial](https://cloud-547suu6q6-hack-club-bot.vercel.app/0r.mp4)

---

### Drawing the Schematic

Start by opening up KiCad, a window will pop up, create a new project then click on the "Schematic Editor" button:

![Schematic button](https://hc-cdn.hel1.your-objectstorage.com/s/v3/70f2f1950d3af13329ddc7f8ece3524070d409bc_schematicbutton.png)

Once you're in, press the **A** key to add symbols for your components. Search and add:

- `XIAO-RP2040-DIP` (your microcontroller)
- `SW_Push` (keyboard switch — copy and paste 4 times)
- `SK6812 MINI LED` (RGB LED, aka neopixels — use 2)

To rotate symbols, press **R**. To mirror, press **X**.

![Placed components](https://hc-cdn.hel1.your-objectstorage.com/s/v3/a9799b37f799c031eaea7cc270ab54e7a4945bd8_placedcomponents.png)

Now start wiring — press **W** to begin. Connect components like this:

![Wired components](https://hc-cdn.hel1.your-objectstorage.com/s/v3/9fbe3988e8ac09c42483ad2d9dff7e7fc7f40ff5_wiredcomponents.png)

Don’t forget to add **GND** and **+5V** symbols (press **P** to search).

Once wired, assign **footprints** to your symbols using the footprint assignment tool:

![Assign footprints](https://hc-cdn.hel1.your-objectstorage.com/s/v3/f5b7fde1908bf5ec3dbaa8bc26f9c6b95d97a84e_assignfootprints.png)

Assign them according to this example:

![Assigned footprints](https://hc-cdn.hel1.your-objectstorage.com/s/v3/596082103b4e031d3848b221f73384f03f4b611a_assignedfootprints.png)

When done, click *Apply & Save Schematic.* Done with the schematic — onto the PCB!

---

### Routing the PCB

Open the PCB editor:

![Switch to PCB](https://hc-cdn.hel1.your-objectstorage.com/s/v3/8decb4a5e5188aacec38a99c6ec868b58be838c2_switchtopcb.png)

Click *Update PCB from schematic*:

![Update from schematic](https://hc-cdn.hel1.your-objectstorage.com/s/v3/d1c6b55d3c015423db630ccb10cf966c0816a99a_updatefromschematic.png)

Place your components down:

![PCB start](https://hc-cdn.hel1.your-objectstorage.com/s/v3/d1796f34df89ab20e6b6357175b3757a9ff6bef5_pcbstart.png)

Change the grid for easier placement — go to the top bar and click the grid value, then *Edit Grids...*

![Grid menu](https://hc-cdn.hel1.your-objectstorage.com/s/v3/a720050b61b09862e984bd28d0a6751f90422016_grid.png)
![Edit grid](https://hc-cdn.hel1.your-objectstorage.com/s/v3/140e75affeaabf2daaf654f516a5dc5195c323d0_editgrid.png)

Add a custom grid of **2.38125mm**.

Now place components.  
To move: **M**, rotate: **R**, flip: **F**.

Align your switches like so:

![Align switches](https://hc-cdn.hel1.your-objectstorage.com/s/v3/6863a3637ac91daf5f2e5618aed19f3d94fdcb47_align.png)

Front vs back side of the board:

![Front vs back](https://hc-cdn.hel1.your-objectstorage.com/s/v3/1e70eb3e035e4a0ab0c1506dd30a3815efd292c7_frontback.png)
![Components sides](https://hc-cdn.hel1.your-objectstorage.com/s/v3/e6e0a19a9a9bfe61edc63ff76a0c996582391120_compfrontback.png)

After placing, draw the board outline on the **Edge.Cuts** layer:

![Edge cuts](https://hc-cdn.hel1.your-objectstorage.com/s/v3/d3ff3725449696af6d0497027fe858c387154c2d_righttoolbar.png)
![Draw rectangle](https://hc-cdn.hel1.your-objectstorage.com/s/v3/d543d12062fe70b729e9883742257d3fc4398488_edgecutsselect.png)

Make sure the XIAO USB head sticks out!

![XIAO head](https://hc-cdn.hel1.your-objectstorage.com/s/v3/3982f14c0636b7a40997d86e759bc43331c58ee6_xiaohead.png)

Now route the board — press **X** to start drawing traces.

![Routing example](https://hc-cdn.hel1.your-objectstorage.com/s/v3/84c2d9ef431116b35206cfe1ea5605e951019885_routing.png)

If you need to switch sides, press **V** to add a via.

![Via example](https://hc-cdn.hel1.your-objectstorage.com/s/v3/2c5f108cb7c1ad9cf0ad669468cf0373f9133a81_via.png)

When all blue lines disappear, you’re done routing:

![Final PCB](https://hc-cdn.hel1.your-objectstorage.com/s/v3/af8a5ad6b744cfb84090242997957f54410acdbd_finalpcb.png)

Brand your Hackpad! Use the **Text Tool** to write its name and “XIAO HERE”:

![Add text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/6fb7d15b52317c1d7432c048de06de5e4fa4fd64_addtext.png)
![Final PCB labeled](https://hc-cdn.hel1.your-objectstorage.com/s/v3/2a961bf38e363dd35b0679e5a4c1e2f20199db90_realfinalpcb.png)

Run DRC to check for errors:

![DRC button](https://hc-cdn.hel1.your-objectstorage.com/s/v3/87367f8b352a2d1233f1c35a03dd8a67efe5a2b0_drcbutton.png)

You’re done with the PCB 🎉

---

## Creating your Case

We’ll use [Fusion360](https://www.autodesk.com/products/fusion-360/personal) for this.

Go to [ai03’s plate generator](https://kbplate.ai03.com/), and open [keyboard-layout-editor.com](https://www.keyboard-layout-editor.com/).

Adjust the layout to match your macropad, then copy the **Raw Data** into ai03’s generator and download the DXF.

---

## Creating your Case in Fusion360

Fusion360 has a [free student plan](https://www.autodesk.com/education/home) and a [personal use plan](https://www.autodesk.com/products/fusion-360/personal).

You can use [this link](https://fusion.online.autodesk.com/webapp?submit_button=Launch+Autodesk+Fusion) to open it in your browser.

---

### Creating the Bottom

Create a new project and component.

![New component](https://hc-cdn.hel1.your-objectstorage.com/s/v3/ba29ae66ece9794dacbab6be26b730b618e27288_newcomponent.png)

Measure your PCB dimensions in KiCad.

![Ruler](https://hc-cdn.hel1.your-objectstorage.com/s/v3/b89bd15fbe8d457d09eadc0e244eea7ad64f721d_ruler.png)
![PCB size](https://hc-cdn.hel1.your-objectstorage.com/s/v3/21420ec275e3d644176ed17ee0e4e8e315474a41_pcbsize.png)

Create a sketch and draw a rectangle 1mm bigger than your PCB.

![Fusion rectangle](https://hc-cdn.hel1.your-objectstorage.com/s/v3/80bf23120968456e67f2a8fc478b4f4cadca7e49_fusionrect.png)

Add another rectangle 20mm larger.

![Fusion rectangle 2](https://hc-cdn.hel1.your-objectstorage.com/s/v3/3c5a322be956e5f732e0d509895a6cdd8b89992f_fusionrect2.png)

Center it using dimensions (9.5mm spacing).

Add 4 holes (3.4mm) 5mm from each edge, then 6mm holes centered on them.

![Circles](https://hc-cdn.hel1.your-objectstorage.com/s/v3/7dee9afd3086778a2dbec469644e7ae6a7031bf2_fusioncircle2.png)

Finish sketch → extrude holes with 3.1mm offset, 9.9mm distance.

![Extrude](https://hc-cdn.hel1.your-objectstorage.com/s/v3/e5012fc0a662c8d120b6730ee0e57937496b3fbd_fusionextrude.png)

Then extrude the outer rectangle 13mm, and inner square 3mm.

![Half case](https://hc-cdn.hel1.your-objectstorage.com/s/v3/5b2e76d3daebd0d8af8f9f68e4643daa3f35253e_fusioncasehalf.png)

Measure the USB port offset in KiCad.

![USB dist](https://hc-cdn.hel1.your-objectstorage.com/s/v3/de05c35d940dc2e5c5594e6fe47bd7abb88cd91b_kicadusbdist.png)

Draw the USB cutout and extrude -7.5mm.

![Fusion hole](https://hc-cdn.hel1.your-objectstorage.com/s/v3/d00ca2f93d6ff63d960e7b0566ed7b6612867672_fusionhole.png)
![Fusion case](https://hc-cdn.hel1.your-objectstorage.com/s/v3/29df5be214c13403164543b583d88b3cacceac95_fusioncase.png)

Export as a STEP file.

Round corners with a 5mm fillet:

![Fillet example](https://hc-cdn.hel1.your-objectstorage.com/s/v3/37804a2891e02800f2d4b3f953a398ee5353fc98_fillet.png)

---

### Creating the Top

Start a new design, insert the DXF file you made earlier.

![Insert DXF](https://hc-cdn.hel1.your-objectstorage.com/s/v3/1480f89f7a6e146650ec11668c9c065be4103dc8_fusionholes.png)

Lock it, then create an outer rectangle matching your PCB.

![Fusion layout](https://hc-cdn.hel1.your-objectstorage.com/s/v3/e577de2f63de0008edf4683ab1525982798272c7_fusionalmost.png)

Add a USB cutout rectangle (18.5×31mm) and 4 screw holes (3.4mm, 5mm offset).

![Final sketch](https://hc-cdn.hel1.your-objectstorage.com/s/v3/63d310314e568bb206df0790c421d427adc29860_fusionfinalsketch.png)

Extrude the plate by 1.5mm and fillet edges.

![Final plate](https://hc-cdn.hel1.your-objectstorage.com/s/v3/d39d3891cd4c372befaecadd1fbe95cea39c60ad_fusionplatefinal.png)

Congrats — top done!

---

### Finishing Touches

Brand your case — add your name via a text sketch and extrude it -0.2mm.

![Text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/7fc1b459839b1c49adb20cfa302670cfce15576f_createtext.png)
![Extruded text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/f4cb3ff26d029cec2fa3b397f2d326a499374baf_extrudedtext.png)

You can import 3D models of components to test fit:

![Tested case](https://hc-cdn.hel1.your-objectstorage.com/s/v3/b90f22b0f1ab616c9e65910eb893d49988192a25_testedcase.png)

---

## Firmware

You can use [QMK firmware](https://qmk.fm/) — see [Porting Guide](https://docs.qmk.fm/porting_your_keyboard_to_qmk).

Or use **KMK**, a Python-based firmware that supports hot reloading.

Example code:

```python
import board
from kmk.kmk_keyboard import KMKKeyboard
from kmk.scanners.keypad import KeysScanner
from kmk.keys import KC
from kmk.modules.macros import Press, Release, Tap, Macros

keyboard = KMKKeyboard()
macros = Macros()
keyboard.modules.append(macros)

PINS = [board.D3, board.D4, board.D2, board.D1]
keyboard.matrix = KeysScanner(pins=PINS, value_when_pressed=False)

keyboard.keymap = [
    [KC.A, KC.DELETE, KC.MACRO("Hello world!"),
     KC.Macro(Press(KC.LCMD), Tap(KC.S), Release(KC.LCMD))],
]

if __name__ == '__main__':
    keyboard.go()
