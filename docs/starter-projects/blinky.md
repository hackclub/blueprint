# Blinky Board

Made by @Tanishq Goyal

Hi there! This is a tutorial on how to make a 555 LED Chaser board otherwise known as a “Blinky Board”. You can follow this tutorial, customize your design and you will be shipped the parts to build it!

## Blinky Board (Alternative)

[Check out the EasyEDA version here!](blinkyeda.md)

## Table of Contents
- [Blinky Board](#blinky-board)
  - [Blinky Board (Alternative)](#blinky-board-alternative)
  - [Table of Contents](#table-of-contents)
  - [What We Will Build](#what-we-will-build)
  - [What We’ll Be Doing](#what-well-be-doing)
  - [Set Up Accounts](#set-up-accounts)
  - [Creating Your GitHub Repo](#creating-your-github-repo)
  - [Creating Your Project on Blueprint](#creating-your-project-on-blueprint)
  - [Create Your Project on KiCad](#create-your-project-on-kicad)
  - [Create Your Schematic](#create-your-schematic)
  - [How Do the Components Work and How Do I Connect Them?](#how-do-the-components-work-and-how-do-i-connect-them)
- [Assigning Footprints in KiCad](#assigning-footprints-in-kicad)
  - [Steps to Add the CD4017 Footprint](#steps-to-add-the-cd4017-footprint)
  - [Create a Printed Circuit Board (PCB)](#create-a-printed-circuit-board-pcb)
  - [PCB Routing](#pcb-routing)
  - [Customization](#customization)
  - [Run Design Rules Check](#run-design-rules-check)
  - [Add Your Files to Your GitHub Repo](#add-your-files-to-your-github-repo)
  - [Upload Your Files to GitHub](#upload-your-files-to-github)
  - [Getting a JLCPCB Price](#getting-a-jlcpcb-price)
  - [Submitting Your Blueprint Project to Get Funding](#submitting-your-blueprint-project-to-get-funding)

## What We Will Build

We will all build this LED chaser which blinks 10 LEDs in a variable speed sequence.

![](/old-cdn/766c5aee15a8c57b1bd57467f3382fc68c0a627c_unnamed.gif)

Here’s the schematic:

![](/old-cdn/5447f846be0c0dfc8fb9e18855233e17eee82b6b_image.webp)

## What We’ll Be Doing

- Set up [KiCad](https://www.kicad.org/)
- Design a Schematic
- Create a Printed Circuit Board (PCB)
- Submit your board for manufacturing at JLCPCB
- Get a PCB grant from Hack Club Blueprint
- Wait a week for your board to come back
- Solder your board
- Test your board and enjoy!

## Set Up Accounts

If you haven’t already, you should download [KiCad](https://www.kicad.org/) and [GitHub](https://github.com/). KiCad is what you will use to design the PCB and GitHub is where you will share it.

## Creating Your GitHub Repo

Create a repository on [Github.com](http://Github.com). (you may need to create an account)

![](/old-cdn/8c2a28ed6838101ae8c5def10c9115042637a201_image.webp)

You need to

- **Name it** - I named it 555 Chaser but you can do whatever
- **Write a nice description** - this can be short
- **Make it public**
- **Enable  a README** so others can see what you made

![](/old-cdn/86cd75d246e16ce3a172caa472c49f2648ee92eb_image.webp)

Now copy the URL for your repo. You will need it for your next step.

## Creating Your Project on Blueprint

Now, you just need to create your project on Blueprint. Blueprint not only allows people to share projects, but acts as a gallery of all the projects made.

First, create your Blueprint account on [https://blueprint.hackclub.com/](https://blueprint.hackclub.com/) (⇒ Sign in). In the future, you will be able to log into your account anywhere, anytime to make your project.

![](/old-cdn/b7cf34ff897d78ad13372226165e67814934dae3_image.webp)

Your screen should look something like this.

Click the “+ Start a Project” button at the bottom of your screen. You need to fill out the form (you can just copy the name and description from your GitHub repo). Don’t worry about the banner for now. You can put that in later.

![](/old-cdn/84fa13d1537256ffdb6f5fd9939f96f4f0603bd3_image.webp)

IMPORTANT:
Make sure you select the LED Chaser as your guide. Doing this will bypass the need for a journal in order to ship. For your future Blueprint projects, you will need to make an updated guide with what you are making.

Also, make sure you click “I need funding”

Now click “Create Project”

![](/old-cdn/283a56a17d26ee6e3d42a9d20975cbaa25b04964_image.webp)

Once your project is created, click into it on the project screen.

![](/old-cdn/a73a0deeb8dbf8e604f0ebfda1f95f6f6ccd6daa_image.webp)

## Create Your Project on KiCad

Create a new KiCad project by going:
`File -> new project, and choosing your name/folder for the project`

After that, double click your schematic to start working on your PCB. PCB's essentially have 2 main parts, the schematic, and the actual PCB.

The schematic is basically a wiring diagram, that shows how everything will connect, but isn't like exactly where the components are placed or how thick your traces are, it's solely to show how everything is wired, not where.

## Create Your Schematic

You should see something like the image below. That is the schematic editor where you will be making your circuit diagram.

![](/old-cdn/425d3c50977a13ebf74772212c11d5481555b481_image.webp)

Here are the components we will be using: (IC stands for Integrated Circuit)

![](/old-cdn/d91b426a709588e2ab5803427c3624a753450f45__771DD54A-39E4-4922-9E2C-BAE6DBCC179B_.webp)

In schematic, things are represented as symbols. Here are the symbols for the components above:

![](/old-cdn/c75477351563114ae06c0dc00b2fa508cf611273_image.webp)

In order to place components (aka symbols), you need to press `a` and search for a component  such as “NE555P”.

![](/old-cdn/3e3b36d04734d421554efa639702cfa84b241388_image.webp)

You will now need to go through and find all of your components. Luckily, we already compiled a list of everything you need to place:

- **[NE555P](https://www.ti.com/lit/ds/symlink/ne555.pdf)** (this is your 555 IC which is famous in circuitry)
- **CD4017** (this is your main 4017 IC. It controls all of the LED’s flashing given an input from the 555)
- **MountingHole_Pad** (this is your header, or little pins which you will use to power your circuit. You will need 2 off these. Additionally, there is another little header which you can use for debugging your circuit)
- **C_Polarized** (this is an electrolytic capacitor, it is directional so be careful!)
- **C** (this is a normal capacitor)
- **R** (this is a 1k ohm resistor and 470 ohm resistor)
- **RV** (this is a potentiometer otherwise known as a variable resistor. You can use this to control the speed of the flashes)

> To change values of resisitors, double click the resistor, change the value, then click OK.

You will also need to place a total of 10 LED below. You will get 10 of each color in the kit so don’t worry about assigning their color right now!

- **LED** (normal LED)

In the kit, you will be given
- 10x Red LED's
- 10x Orange LED' s
- 10x Yellow LED's
- 10x Emerald LED's
- 10x Blue LED's

Here is a good point to remind you. If you ever need help, ask in #blueprint-support on the Hack Club Slack.

## How Do the Components Work and How Do I Connect Them?

> In general, it is good practice to not wire everything directly. This makes it hard to read. Instead, use [labels](https://www.baldengineer.com/kicad-bus-labels-and-global-labels.html)!

First, we know that the battery pads connect to +5v ([5 volts of power](https://theengineeringmindset.com/what-is-voltage/)) and gnd (ground is connected to the negative terminal of a battery or power supply, acting as the main return path for current).

Therefore, I click `W` (for wire) and connect the mounting holes as such:

![](/old-cdn/131c8dfacde59ed5e224b156257712a6e735e49f_image.webp)

**Now, let's take a look at the [555 timer](https://www.instructables.com/555-Timer/#step6).** There are three different modes:

- Monostable Mode, or One Shot, is great for creating time delays. This is almost used as a stopwatch; you press a button (trigger), and the timer turns ON for a set amount of time, then automatically turns OFF.

- **Astable Mode produces a continuous oscillating signal. In this configuration, the 555 timer repeatedly toggles its output between high and low states, with both the frequency and pulse width adjustable. Essentially, this mode mode makes the timer act like a blinking light. It keeps switching ON and OFF again and again, without needing you to press anything. We will be using this mode, as it lets the LED blink at a speed we can adjust.**

- Bistable Mode causes the 555 timer to toggle its output between high and low states depending on the state of two inputs. Essentially, it acts like a toggle switch. Foe example, you can press button A to turn the LED ON, then press button B to turn the LED off.

This is the general schematic for Astable Mode:

![F55UTLKH78T8OJF](https://github.com/user-attachments/assets/ca7259a8-c5da-4e9a-b017-76e3486fff61)

At the end, this is what it should look like:

![Astable Diagram](/old-cdn/f4258af8a265de6744357ac62db79e3c35fcb055_image.webp)

Next, lets take a look at the 4017 IO expander. Due to the lack of GPIO on the 555 timer, we need a way to connect more LEDs. Thats where we use these IO expanders! We will connect as follows:
- VDD to +5v
- VSS to GND
- CLK to Q from the NE555P 	(Clock input from 555 timer)
- CLEN to GND (This is the clock inhibit, a control signal that pauses or freezes the operation of a digital circuit by blocking incoming clock pulses. We do not need this for this circuit. )
- Reset to GND (This is the reset. When set HIGH, the counter immediately resets. )
- Cout not connected (click Q, and connect it to the no-flag symbol. This would be used to connect more IO expanders, but we do not need this.)

Next, connect GPIO Q0–Q9 to LEDs, and tie all of their cathodes together through a single 470 Ω resistor to ground. This resistor is needed to limit the current flowing through whichever LED is active at a given time. The minimum resistance can be estimated using the formula:

R = (V_supply − V_f) / I

where:
- V_supply = supply voltage (e.g., 5 V)
- V_f = LED forward voltage (e.g., ~2 V for red, ~3 V for blue/white)
- I = desired current (e.g., 5–15 mA)

Power‑limiting resistors prevent excessive current that could damage the LED or the driving IC. In practice, standard resistor values such as 220 Ω, 330 Ω, or 470 Ω are commonly used depending on brightness and power budget. Lower resistance allows more current and brighter LEDs, while higher resistance reduces current, conserves power, and extends component life.

At the end, it should look something like this:

![4017](/old-cdn/939f70e5de76b8bb28e6daf54a036b9cbc0bb3bd_image.webp)

# Assigning Footprints in KiCad

In general, footprints can be found by checking the component’s datasheet. A quick search online usually helps.

Unfortunately, the **CD4017** footprint is not included in KiCad by default. Let’s fix that!

---

## Steps to Add the CD4017 Footprint

1. **Go to the Texas Instruments export site**
    [Texas Instruments CD4017BE Export Page](https://app.ultralibrarian.com/details/15b11d40-103f-11e9-ab3a-0a3560a4cccc/Texas-Instruments/CD4017BE)

2. **Create an account**
   - Sign up or log in to Ultra Librarian.

3. **Download the footprint**
   - Click **Download Now**
   - Select **KiCad** as the CAD format
   - Choose **KiCad v6+**
   - Download the file

4. **Import into KiCad**
   - Open KiCad
   - Click Preferences
   - Click `Manage Footprint Libraries`
   - Import! What I personally do is create a folder with all my custom imports. Find the .kicad_mod file, and put it into a .pretty folder.

Your footprints should look something like this:

![](/old-cdn/bf6e6b7ca1eeba39f6ddd680f6efa7a7b06cbfd4_image.webp)

---

## Create a Printed Circuit Board (PCB)

To synchronize changes between your schematic and PCB layout in KiCad:

- Press **F8**
  *or*
- Click the **Update PCB from Schematic** button

You can do this anytime you want to refresh the PCB with the latest schematic updates.

First, create a board outline. For this tutorial, **YOU NEED TO CUSTOMIZE YOUR BOARD WITH A CUSTOM OUTLINE AND ART**

This is done by modifying the `Edge.Cuts` layer on the right side.

There are many ways to do this. You can either manually draw it with the given menue.

I found the default outline options limiting and wanted to create something more complex.
To do this, I:

1. Took a Batman image.
2. Converted the image into a DXF file using an image-to-DXF converter.
3. Imported the DXF file into KiCad.
4. Created a 100x100 mm box as a reference.
5. Used the measuring tool to determine the correct scale.
6. Scaled the outline down so it fit within 100 mm.

At the end, it may look something like this:

![](/old-cdn/06ae2032f870f668a088dafecf0d36b64cacef1e_image.webp)

**Make sure to always keep your board below 100x100mm!**

## PCB Routing

A PCB is made out of multiple layers. Our boards are “two layer” meaning that they have two layers of copper wire.

The layers include:

Top and bottom solder mask: the white ink where you can do art

Top and bottom copper layer: the layers where you make your copper wires

Substrate: The actual plastic (usually green) which makes up your board

Via: the tunnels which connect the top and bottom copper layers

![](/old-cdn/c2ec73f247fdb1f466903fc86d345fe0f4b47b6f_image.webp)

Place all of your components inside the Board Outline. Move components to shorten ratlines, which are are the straight blue lines.

- You can use ‘r’ to rotate them
- Remember to save (Control-S or  ⌘-S) often !!!!

Now it's time to route the PCB! Hit X on your keyboard and hit anything with a thin blue line poking out of it. It should dim the entire screen, show you which direction you need to go with a thin blue line and highlight the destination:

![example here](/old-cdn/e56026795ef53593ec7e75e329f0bc7c9c9d71b6_image.webp)

Join the highlighted points together. If there isn't enough space on the front side, or there is a trace already present that is blocking you, you can route on the back side by clicking B.Cu on the right toolbar. At the same time, if you want to change sides during routing, press V and a via shall be added, which will transfer your trace to the other side of the board. **Wires and pads of different colors (except golden) can't be connected together directly! You must via to the other side.**

![](/old-cdn/94a3f8fd9531b47e0f5322ea7bf1c76724ad1c82_image.webp)

Your routing is complete!

> Tip: place everything based on what shortens the blue lines, and what makes them not cross!

> Tip 2: Use a [ground plane](https://www.kicadtips.com/how-to/make-a-ground-plane) to help with routing and to reduce noise. Thats what the red and blue layers are for! Its not necessary, but looks nice and is easy to set up!

![](/old-cdn/a37611747f571d7a98564a52686e42722adfa6c0_image.webp)

## Customization

You may have already added some text and art to customize your board. if not, you can click “F.Silkscreen” and use the text tool.

![sample text](/old-cdn/40af4f6bb85a2aadc2e3791e28f2e6e84ed8eb56_image.webp)

To add art, just select the “Top Silkscreen Layer” or “Bottom Silkscreen Layer” in the sidebars. Then you use the kicad image converter to add custom art.

![](https://kicad-info.s3.dualstack.us-west-2.amazonaws.com/original/3X/a/3/a3b5fba9b9455697b0d861d48a028c571ec44403.png)

Your board is now beautiful

![](/old-cdn/159975437b4e769b6bcf42d8f52560b11d06c143_image.webp)

## Run Design Rules Check

**DRC** stands for Design Rules Check. This runs a script which makes sure that your board has no interference errors, no components are off the board, and no wires are intersecting. It does not however confirm that your board works.

![](/old-cdn/27ae0765082623ea2988bbe01ce8cb8a4012b0b8_image.webp)

Using the output, correct any errors. This can be confusing, so remember: you can always ask for help!

Here are some common errors:

- Track and copper errors (clearance violations, track width, annular rings)
- Via errors (diameter, micro vias, blind/buried vias)
- Pad and footprint errors (pad-to-pad, hole clearances)
- Edge and board outline errors (copper edge clearance, silkscreen issues)
- Zone errors (copper slivers, starved thermals, unconnected items)
- Net and connection errors (missing connections, net conflicts)
- Courtyard errors (overlaps, missing courtyards)

Once your PCB passes the DRC, it is finished!

In PCB editor click View > 3D Viewer to see your finished work!

![](/old-cdn/50638b1bb956cd429eab5755e7aaf142ffe088db_image.webp)

## Add Your Files to Your GitHub Repo

Now it is time to order your board.

Get the following files of your project:

- A screenshot of your 3d view 
  - In PCB Editor: View → 3D Viewer → Edit → Copy 3D Image.
- .kicad_pro (KiCad project file)
- .kicad_sch (schematic, if you used KiCad)
- .kicad_pcb (PCB, if you used KiCad)
- Your Gerber files:
  1. In your PCB editor do File → Fabrication Outputs → Gerbers (.gbr)
  2. Set an output folder (e.g., a new "Gerbers" folder)
  3. Select necessary layers (Generally already selected)
  4. Click Plot
  5. Click Generate Drill Files
  6. Zip the resulting files for your manufacturer

## Upload Your Files to GitHub

Go back to the GitHub repo you created at the start.

Click Add File → Upload files

![](/old-cdn/470145098fd2379b9385c1f49ddf795fbadfa1a3_image.webp)

Drag in your:


- Screenshot of your 3d view 
- .kicad_pro (KiCad project file)
- .kicad_sch (schematic, if you used KiCad)
- .kicad_pcb (PCB, if you used KiCad)
- Gerbers 

(you should have downloaded all of these before)

![](/old-cdn/8116375daf649aa342be5d409e010a5769f5ed81_image.webp)

You can then click to commit your changes.

Finally, edit your ReadME
![](/old-cdn/383215c7b9b871788025c40fd95b2cab387938d2_image.webp)

NOTE: ALL projects you make for Blueprint must have a project photo in your ReadME.

## Getting a JLCPCB Price

Go to [https://jlcpcb.com/](https://jlcpcb.com/) and make an account. Then, add your Gerber file for the instant quote.

![](/old-cdn/baaa0ca887d51110c30cba9d862968acbef618f8_image.webp)

Settings:

You should keep the default settings for everything. The only thing you should/can change is the PCB Color. I did black as seen below:

![](/old-cdn/2b2ea8e606d05ddff382fdcc7934da4bff70615c_image.webp)

For high-spec options, also keep the default. Do not click PCB assembly as we will give you a kit to hand-solder your board.

![](/old-cdn/053061912ca84c66c46323ccef5b12cb71c7d721_image.webp)

Once you have successfully *Not* changed any of the settings (except the board color), on the right, change the shipping method to Global Standard Direct (or Air Registered Mail if it is cheaper), and take a screenshot (this is very important).

![](/old-cdn/6f538d5f301eae997544c43c1d6ce6daca01331d_image.webp)

## Submitting Your Blueprint Project to Get Funding

You are almost done! At this stage you should have:

- A completed board
- A GitHub repo for your board
- A Blueprint project for your board
- A price estimate and screenshot for your board

Go back to your Blueprint project screen from before. You should edit the project so the banner is your 3D render.

![](/old-cdn/a73a0deeb8dbf8e604f0ebfda1f95f6f6ccd6daa_image.webp)

Now, click “Ship It”

![](/old-cdn/6d1688e2383ca416db27b57942698e7f24a88da9_image.webp)

Blueprint will run some checks. If any are red, you need to fix them. (you may need to upload your project banner)

![](/old-cdn/0e646bc3c854746bfd51172fa68cdba8a9df1625_image.webp)

Enter the dollar amount which you previously screenshotted on JPCLCB (don’t worry, we will give you extra for any fluctuations).

![](/old-cdn/22dfe9ac0998e14b4f9418b118f37eeee29a5561_image.webp)

Click “No” for 3d print

![](/old-cdn/cd0755158d34ae939d044a3d350e0ca6c4cb6ea7_image.webp)

Upload your JLCPCB screenshot from earlier

![](/old-cdn/0aaa8f8f94dab1567dfdaff06ca5ac755b07f131_image.webp)

Check your project…. and ship!

![](/old-cdn/9306e1f8bb9e33f20e757051d90f47fe1f8035e0_image.webp)

You may need to verify your Hack Club identity if you have not already.

You are done!

You should wait for  a reviewer to approve your project! Once it is approved, you can complete the checkout on JLCPCB (making sure to use Global Standard Direct (or Air Registered Mail if it is cheaper), and your kit/soldering iron will be sent to you!

While you wait….

Check out more Blueprint projects on [https://blueprint.hackclub.com/explore](https://blueprint.hackclub.com/explore)! You can also make any hardware project you want on Blueprint, and get up to $400 to make it. For future Blueprint projects, you will need to make a journal throughout your development process. Again, if you have any questions, ask in #blueprint-suppport on Slack.