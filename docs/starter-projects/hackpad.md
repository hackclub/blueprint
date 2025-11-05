# Make your own Hackpad!

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

---

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

![Schematic button](/docs/v2/schematicbutton.png)

Once you're in, press the **A** key to add symbols for your components. Search and add:

- `XIAO-RP2040-DIP` (your microcontroller)
- `SW_Push` (keyboard switch — copy and paste 4 times)
- `SK6812 MINI LED` (RGB LED, aka neopixels — use 2)

To rotate symbols, press **R**. To mirror, press **X**.

![Placed components](/docs/v2/placedcomponents.png)

Now start wiring — press **W** to begin. Connect components like this:

![Wired components](/docs/v2/wiredcomponents.png)

Don’t forget to add **GND** and **+5V** symbols (press **P** to search).

Once wired, assign **footprints** to your symbols using the footprint assignment tool:

![Assign footprints](/docs/v2/assignfootprints.png)

Assign them according to this example:

![Assigned footprints](/docs/v2/assignedfootprints.png)

When done, click *Apply & Save Schematic.* Done with the schematic — onto the PCB!

---

### Routing the PCB

Open the PCB editor:

![Switch to PCB](/docs/v2/switchtopcb.png)

Click *Update PCB from schematic*:

![Update from schematic](/docs/v2/updatefromschematic.png)

Place your components down:

![PCB start](/docs/v2/pcbstart.png)

Change the grid for easier placement — go to the top bar and click the grid value, then *Edit Grids...*

![Grid menu](/docs/v2/grid.png)
![Edit grid](/docs/v2/editgrid.png)

Add a custom grid of **2.38125mm**.

Now place components.  
To move: **M**, rotate: **R**, flip: **F**.

Align your switches like so:

![Align switches](/docs/v2/align.png)

Front vs back side of the board:

![Front vs back](/docs/v2/frontback.png)
![Components sides](/docs/v2/compfrontback.png)

After placing, draw the board outline on the **Edge.Cuts** layer:

![Edge cuts](/docs/v2/righttoolbar.png)
![Draw rectangle](/docs/v2/edgecutsselect.png)

Make sure the XIAO USB head sticks out!

![XIAO head](/docs/v2/xiaohead.png)

Now route the board — press **X** to start drawing traces.

![Routing example](/docs/v2/routing.png)

If you need to switch sides, press **V** to add a via.

![Via example](/docs/v2/via.png)

When all blue lines disappear, you’re done routing:

![Final PCB](/docs/v2/finalpcb.png)

Brand your Hackpad! Use the **Text Tool** to write its name and “XIAO HERE”:

![Add text](/docs/v2/addtext.png)
![Final PCB labeled](/docs/v2/realfinalpcb.png)

Run DRC to check for errors:

![DRC button](/docs/v2/drcbutton.png)

You’re done with the PCB 🎉

For more advanced design, check out the [advanced PCB guide](/advancedPCB).

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

![New component](/docs/v2/newcomponent.png)

Measure your PCB dimensions in KiCad.

![Ruler](/docs/v2/ruler.png)
![PCB size](/docs/v2/pcbsize.png)

Create a sketch and draw a rectangle 1mm bigger than your PCB.

![Fusion rectangle](/docs/v2/fusionrect.png)

Add another rectangle 20mm larger.

![Fusion rectangle 2](/docs/v2/fusionrect2.png)

Center it using dimensions (9.5mm spacing).

Add 4 holes (3.4mm) 5mm from each edge, then 6mm holes centered on them.

![Circles](/docs/v2/fusioncircle2.png)

Finish sketch → extrude holes with 3.1mm offset, 9.9mm distance.

![Extrude](/docs/v2/fusionextrude.png)

Then extrude the outer rectangle 13mm, and inner square 3mm.

![Half case](/docs/v2/fusioncasehalf.png)

Measure the USB port offset in KiCad.

![USB dist](/docs/v2/kicadusbdist.png)

Draw the USB cutout and extrude -7.5mm.

![Fusion hole](/docs/v2/fusionhole.png)
![Fusion case](/docs/v2/fusioncase.png)

Export as a STEP file.

Round corners with a 5mm fillet:

![Fillet example](/docs/v2/fillet.png)

---

### Creating the Top

Start a new design, insert the DXF file you made earlier.

![Insert DXF](/docs/v2/fusionholes.png)

Lock it, then create an outer rectangle matching your PCB.

![Fusion layout](/docs/v2/fusionalmost.png)

Add a USB cutout rectangle (18.5×31mm) and 4 screw holes (3.4mm, 5mm offset).

![Final sketch](/docs/v2/fusionfinalsketch.png)

Extrude the plate by 1.5mm and fillet edges.

![Final plate](/docs/v2/fusionplatefinal.png)

Congrats — top done!

---

### Finishing Touches

Brand your case — add your name via a text sketch and extrude it -0.2mm.

![Text](/docs/v2/createtext.png)
![Extruded text](/docs/v2/extrudedtext.png)

You can import 3D models of components to test fit:

![Tested case](/docs/v2/testedcase.png)

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
