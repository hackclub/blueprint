# How to make a flight controller (from scratch)

Made by @NotARoomba

This is an advanced project. I recommend learning the basics of KiCad by making a small dev board or breadboard first. That said, anyone can follow along, as I'll go **_in-depth_** on how to build a flight controller.

I'm [@NotARoomba](https://github.com/notaroomba) and I have a (sort of) obsession with making flight controllers so heres a guide so that you too have the knowledge of making something [cool](https://github.com/notaroomba/athena). The files for this guide can be found [here](https://github.com/notaroomba/simpleflightcontroller)

First, define what type of flight controller you want: for a rocket or a drone? Keep that in mind when starting your own design. In this guide, we'll build a flight controller specifically for rockets.

To start, create a new repository on GitHub and add two folders: `hardware` and `software`. These folders will hold most of the project files. Then, create a new KiCad project inside the `hardware` folder.

![Folder Structure](https://hc-cdn.hel1.your-objectstorage.com/s/v3/2937dfbe0936703899cece511669a0edc54c7efd_folder-structure.png)
(Folder structure)

![KiCad Project Files](https://hc-cdn.hel1.your-objectstorage.com/s/v3/02816d068a1a60959bb0e6365f396a702800f679_kicad-project-files.png)
(KiCad project files)

## Feature Definition

Before starting any engineering project, define the problem you're solving and the constraints you have. Imagine you want to build a rocket. All flight controllers include a `microcontroller`, which is a small computer that can be programmed to do various tasks. To control the rocket's flight, you'll use servos to move fins or a TVC system (`Thrust Vector Control`- tilting the engine nozzle to steer the rocket).

If you only build a board to drive servos, the rocket won't know which way it's pointing or how to correct its trajectory. You also need position and motion data (rotation and acceleration), plus altitude data. Finally, you'll want to store data persistently (even when powered off) for debugging and post-flight analysis.

Now that we have the rocket's functionality defined, we also need a way to power it. We can use a battery that can power both the rocket's computer and its servos.

Putting this together, we want these features in our rocket's flight controller:

- Can control servos for fins or TVC
- Can obtain position and altitude data
- Can store data even when powered off
- Can be powered by a battery

## Next steps

Now that we have our requirements, let's see how to meet them. Some requirements depend on others. For example, we want battery power - but how large should the battery be? That depends on the voltages and current the servos and microcontroller need, so let's define those first.

Depending on the size of your rocket, current needs will vary because larger servos draw more current. Most hobby servos run on 5–6V and draw ~1A. A 2-cell LiPo (Lithium Polymer) battery (7.4V nominal) is common in RC applications (each cell is ~3.7V) and can be regulated down to 5V for servos.

Most microcontrollers and sensors run on 3.3V, so with a 2-cell (7.4V) LiPo we have more than enough input voltage—as long as we regulate it down to a clean 3.3V line.

Now, after checking off one of the features, we need to tackle the three others.

- Can control servos for fins or TVC
- Can obtain position/altitude data
- Can store data even when powered off
- ~~Can be powered by a battery~~

After choosing servos, we need to know how to control them. Most hobby servos use `PWM (Pulse Width Modulation)`—a method of control where the microcontroller sends rapid on/off pulses, and the pulse width (duration) determines the servo's position.

![Servo PWM Signal](https://hc-cdn.hel1.your-objectstorage.com/s/v3/fbba5610e535e0bd7dd9061bdb1bca6f9520b912_servo-pwm-50hz.png)

The `duty cycle` is the percentage of the period that the signal is high (on).

![PWM Duty Cycle](https://hc-cdn.hel1.your-objectstorage.com/s/v3/dfa58b42380f88635d4898510995f8d17621203a_pwm-duty-cycle.png)

## What about the sensors and microcontroller?

- ~~Needs to be able to control servos for fins or TVC~~
- Needs a way to get position/altitude data
- Needs to store data even when the rocket is off
- ~~Needs to be able to be powered by a battery~~

For position and motion data, we use an `IMU`—an Inertial Measurement Unit. The IMU measures acceleration and rotation (and some devices also estimate altitude). We'll use the `ICM-45686`. While there are many IMUs with different features, this one is robust and well-supported.

For altitude, we'll use a dedicated sensor called a barometer. It measures air pressure and uses that to estimate altitude. We'll use the `BMP580`—a versatile and common choice for flight controllers.

Finally, to store data, we'll use a microSD card. While you can use onboard flash, microSD is more versatile when you want to access flight logs directly from a computer.

Now that we've defined the sensors and peripherals, we need to select a microcontroller. In this tutorial, we'll use an STM32, but you can adapt it to another MCU like the ESP32 if you want Bluetooth/Wi-Fi support. I prefer STM32 because it's relatively easy to program and widely used in flight controllers. After reviewing STM32 options, we'll use the STM32F722RET6 for its high clock speed and lots of peripherals. Feel free to choose another package or part for larger designs.

- ~~Needs to be able to control servos for fins or TVC~~
- ~~Needs a way to get position/altitude data~~
- ~~Needs to store data even when the rocket is off~~
- ~~Needs to be able to be powered by a battery~~

## Power Management

We have two power sources: USB-C from your computer (5V) and a battery (about 7–8.4V for a 2-cell LiPo). You cannot just wire them together. They need circuitry to choose which one feeds the board and to set the right voltages. The microcontroller typically runs at 3.3V, so we must lower the voltage (from the battery or USB-C) before it reaches the MCU.

To change the voltages, we need to use a regulator. There are two common kinds of regulators you'll hear about:

- `LDO`—Low Dropout regulator. It only turns higher voltage into a slightly lower one. Easy and quiet, but it wastes the excess as heat.
- `Switching regulator`—A more efficient regulator. It can:
  - `buck` (turn higher voltage down),
  - `boost` (push lower voltage up), or
  - `buck-boost` (keep the output steady even if the input goes above or below it).

What we'll do on this board:

- Make a 3.3V line (for the MCU and sensors) using a buck regulator.
- Make a 5V line (for servos or accessories) using a buck-boost regulator so it stays at 5V even as the battery voltage fluctuates.
- Get a battery charging IC (Integrated Circuit—a chip) that can charge a 2-cell battery from 5V.

Now that we've specified what functionality we need, we need to select the chips that provide it. I personally love to use ICs from Texas Instruments as they have good documentation and a huge selection of power management chips for everything related to USB.

Go to their website (https://www.ti.com/), select "Products", then "Battery Management ICs", and finally "Battery Charging ICs". Here you can find all sorts of battery charging chips to fit your requirements for future projects.

![TI Battery Charger Page](https://hc-cdn.hel1.your-objectstorage.com/s/v3/d6432723b54aa82475fc61680db8eb9416ea0036_ti-battery-charger-page.png)

After looking around a bit, I found the `BQ25883`. It's a 2-cell Li-Ion/LiPo charger (which meets our requirement). You could add a more complicated battery charger if you want more cells/power, but they take up more space and are more complex to route.

For the regulators, go back to the TI main page, then navigate to "Power Management," then "DC/DC Power Modules." Here you can find all the regulators you would ever need, complete with excellent datasheets.

![TI DC/DC Power Modules](https://hc-cdn.hel1.your-objectstorage.com/s/v3/5485b44bfcbdf47c671d59768d9c9ed748152a25_ti-dcdc-power-modules.png)

Here is where we can choose the right regulators for our needs. For this tutorial, we are going to use the `TPS63070`, which supports 2–16V input and can output a steady 5V with high current for the servos.

Now all that's missing is to find another regulator for 3.3V. For this, we are going to use the `LMR51430` as it supplies a lot of amperage for the various sensors that we will be using.

Now that we have the chips that we are going to use, we also need to verify that they are available on some platform like [LCSC](https://lcsc.com) or wherever else you are going to manufacture your PCB. We also might have to import certain components from LCSC into KiCad.

## Final component list

- USB-C
- MicroSD
- TPS63070
- LMR51430
- BQ25883
- STM32F722RETx
- ICM-45686
- BMP580
- Optional LED

# Starting the Schematic

Now that we have the components that we are going to use, let's start importing them into our project.

Although KiCad has a large selection of components, it is still a bit outdated and there are tons of chips that we would have to import in order to use them. Thankfully, there is a library called [`easyeda2kicad.py`](https://github.com/uPesy/easyeda2kicad.py) that can import these components from LCSC for us.

I have made a simple helper script to import all of the LCSC IDs from a text file, so all you have to do is append the part numbers and run the script again.

## Adding Custom Parts

Start by creating a folder called `lib` in the `/hardware` directory.

Then in the `/hardware` directory, create a new file called `lcsc.txt` and leave it empty for now.

Then create a file called `lcsc.py` (or whatever name you want) and paste this code in there:

```import argparse
import os
import shutil
import subprocess
import sys

def run_easyeda2kicad_from_file(input_file, output_dir="./lib/lcsc", python_exec="python"):
    input_file = os.path.expanduser(input_file)
    output_dir = os.path.expanduser(output_dir)
    python_exec = python_exec or "python"

    if not os.path.isfile(input_file):
        print(f"Error: File not found: {input_file}")
        return 2

    # If a simple name was provided, check PATH; if an absolute path, check that file exists.
    found = shutil.which(python_exec) if os.path.basename(python_exec) == python_exec else os.path.exists(python_exec)
    if not found:
        print(f"Warning: Python executable '{python_exec}' not found in PATH or as given path. Trying anyway.")

    os.makedirs(output_dir, exist_ok=True)

    with open(input_file, "r", encoding="utf-8") as f:
        # ignore blank lines and comments
        lines = [line.strip() for line in f if line.strip() and not line.lstrip().startswith("#")]

    if not lines:
        print("No LCSC IDs found in input file.")
        return 0

    for idx, lcsc_id in enumerate(lines, start=1):
        cmd = [
            python_exec,
            "-m", "easyeda2kicad",
            "--full",
            f"--lcsc_id={lcsc_id}",
            f"--output={output_dir}",
        ]
        print(f"[{idx}/{len(lines)}] Running: {' '.join(cmd)}")
        try:
            subprocess.run(cmd, check=True)
        except subprocess.CalledProcessError as e:
            print(f"❌ Error processing {lcsc_id}: {e}")
        except FileNotFoundError as e:
            print(f"❌ Executable not found: {e}")
            return 3

    print("✅ All commands completed.")
    return 0

def main(argv=None):
    parser = argparse.ArgumentParser(description="Run easyeda2kicad for a list of LCSC IDs.")
    parser.add_argument("input_file", nargs="?", default="./hardware/lcsc.txt", help="Path to file with one LCSC ID per line")
    parser.add_argument("output_dir", nargs="?", default="./lib/lcsc", help="Output directory")
    parser.add_argument("--python", dest="python_exec", default="python",
                        help="Python executable to use (default: 'python')")
    args = parser.parse_args(argv)

    return_code = run_easyeda2kicad_from_file(args.input_file, args.output_dir, args.python_exec)
    sys.exit(return_code if isinstance(return_code, int) else 0)

if __name__ == "__main__":
    main()
```

This code basically calls the `easyeda2kicad.py` library for every line that is present in `lcsc.txt` and adds it to a KiCad library in `/hardware/lib/lcsc`. (Make sure to install it first using `pip install easyeda2kicad.py`)

Now after creating both of those files, in your favorite IDE, edit `lcsc.txt` with the part numbers of the chips that you are going to use.

For example, let's say I want to add a USB-C port from LCSC. Go to [`www.lcsc.com`](www.lcsc.com) and search for USB-C.

![LCSC Search](https://hc-cdn.hel1.your-objectstorage.com/s/v3/6d46cca468d8ed4fca37d81d019dec3b15a68818_lcsc.png)

After searching, I found a good part with large stock (important!), so I then copy the part number (always starts with C followed by numbers, and it's under the name) into `lcsc.txt`.

![LCSC Search](https://hc-cdn.hel1.your-objectstorage.com/s/v3/ec20447082d2df2c068cad1a7c7b04b4d912da83_lcsc_usbc.png)

It should look like this:

![LCSC Search](https://hc-cdn.hel1.your-objectstorage.com/s/v3/03e6a4678418f95bffe676e614429fed3ac59192_lcsc_txt.png)

Then run the Python script to convert that part number into a KiCad library. **IMPORTANT: YOU NEED TO RUN THE SCRIPT EVERY TIME YOU UPDATE `lcsc.txt`.** If you get an error that you can't find `lcsc.txt`, make sure to run the file from the root of your project or add arguments to specify the path of the library/lcsc txt file.

If you have done everything correctly, you should have something that looks like this:

![LCSC Search](https://hc-cdn.hel1.your-objectstorage.com/s/v3/eb221640fbec7f23837dc4350dbde769145734ef_lcsc_script.png)

If in the future you get an error that the script couldn't find/parse a 3D model, those errors are safe to ignore as you can add the 3D model later. However, if the script can't find/parse a footprint for a specific part, then you should probably find another one on LCSC.

After running the script for the first time, add the library to your KiCad project and also the footprint library (the folder that ends with .pretty). It should look like this when you are done.

![LCSC Search](https://hc-cdn.hel1.your-objectstorage.com/s/v3/6ff011c0b1db3493e8e85328a2df286e34758770_kicad_symbol.png)
![LCSC Search](https://hc-cdn.hel1.your-objectstorage.com/s/v3/dd6687dfd4dd4d8d7b79465750410fc3791abf5e_kicad_footprint.png)

Then after that's done, go into your schematic and search for "lcsc". You should find the library with the USB-C connector (or whatever other part you imported).

![LCSC Search](https://hc-cdn.hel1.your-objectstorage.com/s/v3/365f855c838d8320b564685aa93b370a484c82bc_kicad_usbc.png)

Keep in mind that there are some parts that KiCad already has, such as `STM32F722RETx`, but there are others like the IMU that you will have to import.

![LCSC Search](https://hc-cdn.hel1.your-objectstorage.com/s/v3/393b4eb069231176b8eb76e7b6d6661feb93cd74_kicad_pre.png)

After finding the components on LCSC, my `lcsc.txt` looks like this:

![LCSC Search](https://hc-cdn.hel1.your-objectstorage.com/s/v3/64678d6f38b1e93c7c600222c4fe9a170c59b229_lcsc_done.png)

Now run the script again. Once it's done, go back to KiCad and add in all of the components (you may have to reopen the choose parts screen for the LCSC library to update).

![LCSC Search](https://hc-cdn.hel1.your-objectstorage.com/s/v3/5aa0d43b29d3966bb755930400ec9a955a36033b_kicad_start.png)

## USB-C and Power

Now let's start wiring up the power components and USB-C. It's always good practice to start wiring the components that would be used first. In this case, it would be USB-C as it is going to receive voltage, then the battery connector as that voltage from USB-C is going to directly charge the battery. If there is no USB-C, then the battery will provide voltage, followed by the 2 regulators. Again, you can wire each component up in whatever order. I just do it like this to be a bit more organized.

![LCSC Search](https://hc-cdn.hel1.your-objectstorage.com/s/v3/3cef224c168e7de4e92507c1ede446f3412a80ef_usbc.png)

This is the USB-C connector. As you can see, it has a lot of pins, but don't worry if you don't know what all of those mean. Here's a quick explanation:

- **Shell**: This is the outer case of the USB-C port. It's usually connected to ground.
- **GND**: Ground.
- **VBUS**: This is the pin that supplies voltage from the device that connects to it. Usually it provides 5V at 3A, depending on the cable.
- **SBU1/2**: These are low-speed lines that can be used as alternate pins for different accessories, such as AUX+ and AUX- when connected to a DisplayPort. We don't need to use them.
- **CC1/2**: These are Configuration Channel pins. Basically, they detect if the connector is flipped and can also be used to negotiate more power out of VBUS (USB-PD). We are going to connect them to 5.1K resistors to ground as this tells the other device that we want 5V.
- **DN/DP**: These are the USB lines that we will be connecting to the STM32. They are used to transfer data between devices.

Now with that information in mind, when you finish wiring up the USB-C connector, it should look like this:

![LCSC Search](https://hc-cdn.hel1.your-objectstorage.com/s/v3/159720619db037c2cf9504c755cb985c189212e3_usbc_done.png)

I used net labels to organize it better so that we don't have spaghetti cables all over the schematic.

### Battery Charger (BQ25883)

Now let's wire up the battery charger. This is the next step in our power route. There are many chips in the world, and knowing the pins on each of them is virtually impossible. So, each manufacturer provides what's called a `datasheet` for each component. It's basically a document that details everything about that chip—its pinout and how to implement it.

To access the datasheet for any component in KiCad, simply click on the component and press D. If there isn't one, just search on Google "`[part] datasheet`" and it's usually a PDF.

Opening the datasheet for the battery charger, we are greeted with this:

![LCSC Search](https://hc-cdn.hel1.your-objectstorage.com/s/v3/4c28f281f13aebe8a9dbdd0ca940b8e641243f0b_datasheet_bat.png)

This may look intimidating as there are 86 pages of letters, numbers, formulas, and graphs. However, there is one section that is valuable to us called `Application and Implementation`. This section basically gives us a reference schematic on how to use said chip. We can use the sidebar or table of contents to locate that section. You should see this:

![LCSC Search](https://hc-cdn.hel1.your-objectstorage.com/s/v3/e349d5af31c995f344ab90e6e34ae9a9a47b714c_datasheet_sch.png)

This is the schematic for a specific implementation, and we can see below that there is a table that describes it:

![LCSC Search](https://hc-cdn.hel1.your-objectstorage.com/s/v3/5228fe7ee112b60df9369d919467b205e6f17e1b_datasheet_table.png)

Here we can see the different parameters that influence the design of the schematic above. It is important to understand what each of these values means to determine if the schematic works for your specific needs.

### Design Parameters Explained:

- **VBUS voltage**: How much voltage the chip needs to charge the battery. Our 5V from the USB-C fits within the range, so we're good.
- **Input current limit**: Determines how much of the available 3A current will be consumed.
- **Fast charge current limit**: Sets how much current will be used to charge the battery.
- **Minimum system voltage**: If the battery falls below this voltage, the internal regulator activates to maintain this voltage until the battery completely dies.
- **Battery regulation voltage**: The maximum voltage the chip will charge the batteries to. In this case: 4.2V per Li-ion cell × 2 cells = 8.4V maximum.

These parameters determine the specific resistor and capacitor values needed in the schematic. If we scroll down further in the datasheet, we can see the calculations needed to determine the inductor and capacitor values:

![LCSC Search](https://hc-cdn.hel1.your-objectstorage.com/s/v3/9ea846f444e104f74bf68ad5cce77f6c93758de5_datasheet_calc.png)

If you need a chip that has a reference schematic that doesn't fit your needs, then you need to do some calculations in order to get the right component values. However, usually you don't have to do that.

### Extra Info

If you haven't noticed already, the chip can be connected to a host through some pins called SDA, SCL, INT, CE, and PG. If you don't know what they do or want to know what they mean, there's a section in the datasheet called `Pin Configuration and Functions` that goes into detail about what each pin does.

![Datasheet Pin Configuration](https://hc-cdn.hel1.your-objectstorage.com/s/v3/f011cba7b3ac4e3753242034df4e72215f2feb0a_datasheet_pin_config.png)

Here we can see that for those pins there are descriptions like `active low`, `open drain`, and `I2C`. Let's break down what these terms mean:

#### Active Low

**Active low** means the pin is "active" (doing its job) when the voltage is LOW (0V or close to ground), not when it's HIGH (3.3V or 5V). Think of it like a backwards switch—when you pull the pin to ground, that's when it triggers the function. Many reset pins work this way: pull the reset pin low to reset the chip, and let it go high to run normally.

#### Open Drain

**Open drain** is a type of output that can only pull a pin down to 0V (LOW), but cannot push it up to 3.3V (HIGH). Think of it like a one-way switch—it can only connect the wire to ground, not to power. When the switch is "off", the wire is left floating with no connection. This is why open drain pins need a "pull-up resistor"—a resistor that connects the wire to 3.3V and keeps it HIGH when nothing is pulling it down. Multiple chips can share the same wire this way without interfering with each other.

### Communication Protocols

Now let's talk about the different ways chips can talk to each other. There are several common protocols you'll encounter:

#### I2C/I3C (Inter-Integrated Circuit)

I2C uses only **2 wires**: SDA (data) and SCL (clock). Multiple devices can share the same two wires, and each device has a unique address. Think of it like a conference call where everyone shares the same phone line, but each person has a unique ID. Both wires need one pull-up resistor each (in total) in order to function correctly.

**Pros:**

- Only needs 2 wires regardless of how many devices you connect.
- Built-in addressing system allows multiple devices on same bus.
- Relatively simple to implement.
- Good for sensors and simple peripherals.

**Cons:**

- Slower than SPI (typically 100 kHz to 3.4 MHz).
- Limited distance—long wires can cause signal problems.
- Can get complex with timing issues and error handling.
- Address conflicts if two devices have the same address.

#### SPI (Serial Peripheral Interface)

SPI uses **at least 3 wires** plus one additional wire for each device: MISO (Master In, Slave Out), MOSI (Master Out, Slave In), SCK (clock), and CS (Chip Select) for each device. It's like having separate phone lines for each conversation.

**Pros:**

- Much faster than I2C (can go 10 MHz+ easily).
- Full duplex (can send and receive simultaneously).
- Simpler protocol.
- More reliable over longer distances.

**Cons:**

- Needs more wires (especially with multiple devices).
- No built-in error checking.
- Only one master device allowed.
- Can use up many pins quickly with multiple devices.

#### UART (Universal Asynchronous Receiver-Transmitter)

UART uses **2 wires**: TX (transmit) and RX (receive). It's a point-to-point connection between two devices, like a private phone call.

**Pros:**

- Very simple—just 2 wires.
- No clock signal needed (asynchronous).
- Long distance capable with proper drivers.
- Universal—almost every microcontroller has it.
- Good for debugging and console output.

**Cons:**

- Only connects two devices directly.
- Both devices must agree on baud rate (how fast the data goes) beforehand.
- No built-in error correction.
- Can lose sync if timing is off.

#### USB (Universal Serial Bus)

USB uses **2 data wires** (D+ and D-) plus power and ground. It's like a smart postal system that can handle packages of different sizes and priorities.

**Pros:**

- Standardized connector and protocol.
- Provides power to devices.
- Hot-pluggable (can connect/disconnect while powered).
- High speed (up to 10 Gbps on USB 3.1).
- Built-in error correction and flow control.
- Can connect many devices through hubs.

**Cons:**

- Complex protocol requiring dedicated hardware/software.
- More expensive to implement.
- Requires specific connectors and cables.
- Power management can be tricky.
- Not suitable for real-time applications due to variable latency.

---

We will not be connecting the USB to the battery charging chip as we need to connect the STM32 to USB-C to be able to program it. Looking through the datasheet, it says that those pins are used to determine how much current can be used. However, they can also be set through the `I2C` interface that the IC has, so we can change that later with the STM32.

Now that we know that the schematic suits our needs, we can start copying it in KiCad. When copying a schematic from a datasheet, any pins that can be connected externally should use `Net Labels` like so (obviously with the pull-up resistors added later):

![Net Labels Example](https://hc-cdn.hel1.your-objectstorage.com/s/v3/98a8cd4ec01d8601acdc01184249e973e61c6861_net_labels_example.png)

Also, because we are dealing with power, we have to use `separate grounds` such as `power ground` and `digital ground`. Usually, for most chips, we will use the digital ground. However, sometimes we have to work with power components and need to have a cleaner ground reference. In the datasheet, you can see that there are different symbols for ground.

**Digital ground** is used for all the digital components like microcontrollers, sensors, and logic chips. Digital circuits switch on and off rapidly, creating noise on the ground plane. This is fine for digital circuits since they only care about HIGH (1) or LOW (0), not the exact voltage.

![Digital Ground Symbol](https://hc-cdn.hel1.your-objectstorage.com/s/v3/e749ca5629229308a49ba2be4295e5ca1dde2fc0_digital_ground_symbol.png)

**Power ground** is used for high-current circuits like motor drivers, charging circuits, and voltage regulators. These circuits can draw lots of current, creating voltage drops and noise in the ground connections. Keeping them separate prevents this noise from affecting sensitive circuits.

![Power Ground Symbol](https://hc-cdn.hel1.your-objectstorage.com/s/v3/1f9b90df2a7fc0b422e6369a6ce3972f6bde3b4d_power_ground_symbol.png)

#### Why Separate Them?

The noise from digital switching or high-current power circuits can interfere with sensitive analog measurements from the sensors.

The trick is to keep these grounds separate on the PCB traces but connect them together at a single point. The datasheet says to connect them below the `thermal pad` (a conductive area under ICs to dissipate heat/reduce noise) of the chip. This gives each type of circuit its own clean ground reference while still maintaining a common ground for the entire board.

Now wire up the rest of the schematic, and you should end up with something similar to this:

![Battery Charger Schematic Complete](https://hc-cdn.hel1.your-objectstorage.com/s/v3/f3339b7c990ce680447e4ab1f6781c8e76354703_battery_charger_complete.png)

Note the mess, but I have different ground names for PGND and GND, although I used the same symbol. I added a battery screw terminal and also connected the battery ground to PGND, and I also shorted PGND and GND. I plan on connecting PGND and GND on the bottom of the thermal pad (this is actually the EP/Pin 25, but in the end I removed PGND and used only GND for simplicity).

### Regulators

Now after finishing the battery charger, I am going to start wiring up the regulators, starting with the `TPS63070`.

Apply the same methodology as wiring up the battery charger: look up the datasheet, go to the `Application and Implementation` section, and look at the schematic. In this case, there are 2 schematics:

![TPS63070 Adjustable Application](https://hc-cdn.hel1.your-objectstorage.com/s/v3/d563f4ddeff3b72f081a77601c4f33f277bc570f_tps63070_adjustable.png)
A typical application that can be adjusted depending on your needs.

And if you scroll down a bit more:
![TPS63070 Fixed Voltage Application](https://hc-cdn.hel1.your-objectstorage.com/s/v3/586f44f95da873cbd7a0c3eaba996dda57b91af7_tps63070_fixed.png)

Another typical application, but this time it outputs a fixed voltage.

Really, the only difference is that for the adjustable version, there's a `voltage divider`—a pair of resistors that can be used to create a voltage less than or equal to the input voltage:

![Voltage Divider Circuit](https://hc-cdn.hel1.your-objectstorage.com/s/v3/4e405900e8a68972df11b37104da2234747800e2_voltage_divider_circuit.png)

In the fixed version, we don't use a voltage divider so it stays at 5V (it's predetermined in the chip).

In our case, we are going to use the fixed version as it uses fewer components and also gives us the 5V that we need.

## TIP

When wiring things based on schematics, make sure to use the recommended size capacitor/inductor values (if mentioned) and set it in KiCad like so when you are going to place the part:
![KiCad Component Value Setting](https://hc-cdn.hel1.your-objectstorage.com/s/v3/d5db01401c162ba714abde5df30725a0562ba98d_kicad_component_value.png)

---

Using the fixed schematic (and taking into account the correct footprint sizes), wire it up in KiCad. You should get something like this:

![TPS63070 Schematic Complete](https://hc-cdn.hel1.your-objectstorage.com/s/v3/579d30360238a3af6c4b2500296c6f77f0df82a5_tps63070_schematic_complete.png)

With VIN connecting to VSYS (battery or USB voltage) and VOUT connecting to +5V. Separate grounds are not needed here, so they are GND.

If you don't know what footprint size to add to the other components (resistors, inductors, etc.), don't worry. We will revise this later.

Now moving on to the final power part, the `LMR51430`.

Repeat the same as the other 2 parts: open the datasheet and look for the `Application and Implementation` section. Switching regulators (like the name implies) switch MOSFETs (tiny gates) open and close very fast in order to regulate voltage. This can be measured by the `switching frequency` of the chip. In this case, we have 2 tables under the schematic.

![LMR51430 Switching Frequency Tables](https://hc-cdn.hel1.your-objectstorage.com/s/v3/c2c003c8f0c2a754d10da8c861b01c4c79a9cf2e_lmr51430_switching_tables.png)

One for a switching frequency of 500 kHz and another one for 1.1 MHz (1100 kHz). With a higher switching frequency, it is less efficient and also can produce more heat. However, overall, the space it takes up is less than with the lower frequency. On the other hand, a lower switching frequency is more stable/efficient and doesn't heat up as fast. It also produces a lot less noise (which is what we need). So in this case, we will go with the lower switching frequency at 3.3V. If you want to wire it up based on the higher frequency, then feel free to do so. Just take into account the pros and cons of each one. (All of this information is from the datasheet, by the way.)

![LMR51430 Adjustable vs Fixed Schematic](https://hc-cdn.hel1.your-objectstorage.com/s/v3/25e145f3104c174ecfafce4c491454cf103f6156_lmr51430_adjustable_vs_fixed.png)

After routing it, you should get something like this (for a 500 kHz switching frequency at 3.3V):

![LMR51430 Schematic Complete](https://hc-cdn.hel1.your-objectstorage.com/s/v3/12c48e22668d221830bbf5506b9f4c494962c277_lmr51430_schematic.png)

Like the 5V regulator, VIN = VSYS, but VOUT = +3.3V as this chip is giving us 3.3V output.

Double-check the values on the resistor divider as that is what determines the output voltage. Also, in the reference schematic, it shows one capacitor of 44 µF, but in the table, it's 2 capacitors of 22 µF, so I used those.

## Sensors and Peripherals

Now that we've got power out of the way, it's time to route the sensors and the microSD.

### BMP580

Starting with the BMP580, when I try to open the datasheet, it says that no datasheet is defined. So you have to look it up on Google and found [this](https://cdn-shop.adafruit.com/product-files/6411/BMP580.pdf).

Looking around the table of contents, there is no `Application and Implementation` section, but there is a `Pinout and Connection Diagrams` which is close enough:

![BMP580 Pinout Diagram](https://hc-cdn.hel1.your-objectstorage.com/s/v3/fd3b0ecb0ef175d694bc3bcb97560aad700a3879_bmp580_pinout.png)

Taking a look at the different schematics, there are different ways of connecting the chip through `SPI`, `I2C`, and `I3C`. Above in the **Communication Protocols** section, I explained what each of these mean. For this chip, I plan on using `I2C` as it's the default mode of communication for this chip. (This is personal preference; feel free to use whichever mode of communication you wish.)

When implementing `I2C`, you need to have pull-up resistors on each line. However, if you recall, the battery charging circuit uses I2C as well, and we already put pull-up resistors there, so it isn't necessary to add them here.

![BMP580 I2C Schematic](https://hc-cdn.hel1.your-objectstorage.com/s/v3/cf7bc0cf2019990da40c8508102c893f75a1472d_bmp580_i2c_schematic.png)

Following this schematic, after wiring it up in KiCad, you should get this:

![BMP580 KiCad Wired](https://hc-cdn.hel1.your-objectstorage.com/s/v3/d61a0d62bf40d2104ece87a58e6fff91399f384a_bmp580_kicad_wired.png)

I wired both VDD and VDDIO to 3.3V as that is the voltage that all of the other chips are running at (microcontroller and sensors).

### ICM-45686

Looking at the `ICM-45686` [datasheet](https://invensense.tdk.com/wp-content/uploads/documentation/DS-000577_ICM-45686.pdf), it has different modes of operation like the BMP580. However, the one that interests us is this one:

![ICM-45686 SPI Schematic](https://hc-cdn.hel1.your-objectstorage.com/s/v3/91093a6afa2aab3180f57331f15e3a4953b419dc_icm45686_spi_schematic.png)

Changing things up a bit, we are going to connect the sensors to the microcontroller through SPI. This gives us the advantage of faster data and also allows us to learn how to implement it later on in code.

Also, in the schematic, looking at pin 14, it serves the dual purpose of being a SDIO or SDI. However, in our case, we want to use it as SDI to use the full capacity of SPI.

You should end up with something like this after:

![ICM-45686 KiCad Wired](https://hc-cdn.hel1.your-objectstorage.com/s/v3/17a5cc24631657793a6482987753cc03799cbf35_icm45686_kicad_wired.png)

### MicroSD Card

MicroSD works on the same principle as SPI but can have more channels for faster data throughput. This form of communication is called SDIO (Secure Digital Input Output) and can work in 1-bit or 4-bit data modes (4-bit has more channels and faster data transfers).

Here is an example schematic of how the SD card should be wired, but we are going to modify it a bit to fit our needs. There are 8 pins on the microSD, and here's a table showing their meaning:

![MicroSD Pinout Table](https://hc-cdn.hel1.your-objectstorage.com/s/v3/1368ecdbe4c0da0ba65fa7630b56cef150c9a34b_microsd_pinout.png)

In SDIO (SDMMC) mode, DAT0-3 are used for data transfer, CLK for clock, and CMD for sending/receiving commands between the microcontroller and microSD card. DAT3 can also be considered a CD (Card Detect) pin, but usually, there is a 9th pin on most symbols that uses the case directly to detect if there is an SD card or not.

Another thing to keep in mind when wiring up the microSD card: **10K PULL-UPS ARE REQUIRED FOR EVERY PIN ON THE MICROSD CARD** (excluding the 9th pin/GND/VCC).

![MicroSD Pullup Requirements](https://hc-cdn.hel1.your-objectstorage.com/s/v3/70d9b5177979f4ed131b8acf6d75e27911024cf6_microsd_pullup_requirements.png)

After wiring it up, you should get something like this:

![MicroSD KiCad Wired](https://hc-cdn.hel1.your-objectstorage.com/s/v3/5affaf2d791825d5efef5c7ab7c298da871b5dca_microsd_kicad_wired.png)

Now all that's left is to connect everything to the microcontroller!

# Microcontroller Break

Since we are using an STM32, there is a really cool piece of software called STM32CubeMX. It basically allows you to select the functions and types of communication that you need, and it automatically selects the pins so that we don't have to read the datasheet and get stuff wrong.

To start, [download it here](https://www.st.com/en/development-tools/stm32cubemx.html) and wait for it to install.

After installing it and opening it, you should be presented with this screen:

![STM32CubeMX Startup Screen](https://hc-cdn.hel1.your-objectstorage.com/s/v3/1798957db12ac9a10935d0f4d33f8a253c594d5b_stm32cubemx_startup.png)

Click on `ACCESS TO MCU SELECTOR` as we are going to create a new project based on the MCU that we are using: in this case, `STM32F722RET`.

After searching for the MCU, you should see this screen:

![STM32CubeMX MCU Selector](https://hc-cdn.hel1.your-objectstorage.com/s/v3/b284f0aa7617463dc5a9b27c5cd6c68eb9e33c57_stm32cubemx_mcu_selector.png)

Here, it shows different variations of that version for the STM32, but we are going to select the `STM32F722RET6` version as it is the one that has the most in stock on LCSC.

![STM32F722RET6 Selected](https://hc-cdn.hel1.your-objectstorage.com/s/v3/b3576e122a84ad794536c05e436f77b257198536_stm32cubemx_mcu_selected.png)

After that, hit "Start Project" at the top. If any windows pop up, say yes.

After loading/downloading the firmware, you should be greeted with this window:

![STM32CubeMX Pinout Configuration](https://hc-cdn.hel1.your-objectstorage.com/s/v3/73a1a83a53f8ecfc333b3b7571cd8ef6dead97d7_stm32cubemx_pinout_config.png)

This is where you will be configuring the pinout for the STM32. On the left, you can see the different sections that are able to be configured. However, the only ones that concern us for now are the `System Core`, `Timers`, and `Connectivity` sections.

## Connectivity

Here, we can see the different ways that we can connect the STM32 to different peripherals through `I2C`, `SPI`, `UART`, `SDMMC`, `USB_OTG_FS`, and more. For now, enable the first I2C channel. This will be for the battery charger and pressure sensor. It should look like this:

![STM32CubeMX I2C Enabled](https://hc-cdn.hel1.your-objectstorage.com/s/v3/27049091e21ed6f794ba0f727f537191e58ba7ef_stm32cubemx_i2c_enabled.png)

Also, be sure to select pins on either side for the battery charger interrupt and chip enable pins. The BQ_INT pin should be set as a GPIO_EXTIx (x is any number) pin as this lets the STM32 know that this pin is going to be an interrupt pin.

![STM32CubeMX BQ_INT GPIO Configuration](https://hc-cdn.hel1.your-objectstorage.com/s/v3/2e11bb87c76fd8fa537fe8948019e0184a22e424_stm32cubemx_bq_int_gpio.png)

For BQ_CE, make sure that there's a pin set to GPIO_Output. According to the datasheet, when the pin is low, charging is on, and when it's high, the battery doesn't charge. We can change this later in the code for further customization in case you don't want the battery charge controller running during flight.

![STM32CubeMX BQ_CE GPIO Configuration](https://hc-cdn.hel1.your-objectstorage.com/s/v3/4d9b3b29b10020c5d9728779270ece69d9c57b01_stm32cubemx_bq_ce_gpio.png)

**MAKE SURE TO ADD THE INTERRUPT PIN FOR THE BMP580.**

When selecting an interrupt, if it deletes another interrupt, choose another pin as some interrupts use multiple pins.

![STM32CubeMX BMP580 Interrupt Configuration](https://hc-cdn.hel1.your-objectstorage.com/s/v3/80c2a59bd8b85ac4a2672beabcb5ef21191ced7e_stm32cubemx_bmp_interrupt.png)

Then enable an SPI channel for the IMU. You are free to use whichever channel you wish, but I am going to select the first one. Select `Full Duplex Master` as the STM32 will be the master and the IMU the slave, and full duplex because we are using both MOSI and MISO and not just one channel for input/output (half duplex/SDIO). There is also an option under the selection to activate a `Hardware NSS Signal`. This is used if we have just one device under the SPI bus and makes it so that the STM32 manages the `Chip Select` pin instead of us having to select a GPIO for it. I enabled it as `Hardware NSS Signal Output` as the IMU will be the input. After selecting SPI, it should look like this (it can be different if you want to use a different pin for the Chip Select):

![STM32CubeMX SPI Configured](https://hc-cdn.hel1.your-objectstorage.com/s/v3/c500c296dc42ffa3157cd5c80eef336e9e1f6361_stm32cubemx_spi_configured.png)

Also, don't forget to add the 2 interrupt pins on the IMU as GPIO_EXTIx (x is any number):

![STM32CubeMX IMU Interrupts](https://hc-cdn.hel1.your-objectstorage.com/s/v3/684938f807fe0e3b58a65fbcbad5c28a4464435a_stm32cubemx_imu_interrupts.png)

After you've done that, it's time to select `USB_OTG_FS`. This means USB On-The-Go Full Speed, and it differs from `USB_OTG_HS` (USB On-The-Go High Speed) as it is slower and doesn't need any extra pins to configure. It's sufficient for our needs of flashing and sending serial data. Set it to host or device (you'll be changing this later depending on your needs). For now, I will leave it as host, and it shows where the USB pins are on the chip.

![STM32CubeMX USB OTG Configuration](https://hc-cdn.hel1.your-objectstorage.com/s/v3/644566c8defed3a1ce9f27c15f2d44ed007c04cd_stm32cubemx_usb_otg.png)

Now enable `SDMMC` as this is the communication protocol that we will be using to write/read to our microSD. This should be enabled and set to a 4-bit bus.

![STM32CubeMX SDMMC Enabled](https://hc-cdn.hel1.your-objectstorage.com/s/v3/751aeac27931452c3b6f08421b021755527600a6_stm32cubemx_sdmmc_enabled.png)

Also, remember to add an extra pin next to it for the card detect pin and make it a GPIO_Input:

![STM32CubeMX SDMMC Card Detect](https://hc-cdn.hel1.your-objectstorage.com/s/v3/70d2111b1516cdcd5ae22a58df15035460e64029_stm32cubemx_sdmmc_card_detect.png)

Now that we are done with our peripherals/sensors, we are going to configure some other stuff that would be important in starting the STM32 and configuring the servos.

Go to the `System Core` tab, then click on `RCC`, and set both the high-speed clock and low-speed clock as a crystal/ceramic resonator. By doing this, we are telling the STM32 that we will have some external clocks that it can use to achieve faster/stable clock timing throughout the entire chip. We will edit this in KiCad later along with the pins.

![STM32CubeMX RCC Configuration](https://hc-cdn.hel1.your-objectstorage.com/s/v3/59a3a6b88e05ad56d7d0353c2fa1e40ff0ba5706_stm32cubemx_rcc_config.png)

Now go to the `Timers` section. Here is where we can edit the PWM pins for the servos. Select any timer that has channels that support PWM and select 2 `PWM Generation CH` channels. We will be able to edit the **duty cycle** later in the firmware. Also edit the `Clock Source` and set it to the internal clock. This is needed for the PWM generation as it needs a clock to time the signals correctly.

![STM32CubeMX PWM Configuration](https://hc-cdn.hel1.your-objectstorage.com/s/v3/07ea5869e3b6401972ea540180a778eb1b73d048_stm32cubemx_pwm_config.png)

**MAKE SURE TO SAVE USING CTRL+S AND CREATE A NEW FOLDER IN THE ROOT OF YOUR GITHUB REPOSITORY CALLED `software` OR `firmware`.**

![STM32CubeMX Save Location](https://hc-cdn.hel1.your-objectstorage.com/s/v3/be24ef3122d8cea1d6630ebd394fa894baaf686f_stm32cubemx_save_location.png)

This is how my STM32 looks after selecting all of the pins:

![STM32CubeMX Final Pinout 1](https://hc-cdn.hel1.your-objectstorage.com/s/v3/fb798901d2d129b6317aeca9bc488ef36c2892ef_stm32cubemx_final_pinout1.png)
![STM32CubeMX Final Pinout 2](https://hc-cdn.hel1.your-objectstorage.com/s/v3/c87bf3996bea0834a1723249462dadae88036b17_stm32cubemx_final_pinout2.png)
![STM32CubeMX Final Pinout 3](https://hc-cdn.hel1.your-objectstorage.com/s/v3/a5ad9b0d1c095d89720d6ca1e5f5e00776448e0e_stm32cubemx_final_pinout3.png)

Keep this open while we configure the rest of the microcontroller in KiCad.

# Back to KiCad

Now after adding all of the pins and peripherals and knowing which pins you are going to use, we are going to finish wiring up the STM32 with what's called a `reference schematic`. If you want to learn more about this specific type of chip or any STM32 MCU in general, there is a documentation tab ([example](https://www.st.com/en/microcontrollers-microprocessors/stm32f722re.html#documentation)) that shows you all the implementations/peripherals that you can have with the STM32. After scrolling around, I found a [reference design](https://www.st.com/resource/en/application_note/an4661-getting-started-with-stm32f7-series-mcu-hardware-development-stmicroelectronics.pdf) to use with our STM32.

Going to the section named `Reference Design`, we are greeted with this:

![STM32 Reference Schematic](https://hc-cdn.hel1.your-objectstorage.com/s/v3/08dc401cc68c607831e88961c57e243e08141771_stm32_reference_schematic.png)

## Wiring up Power

Starting with the `decoupling capacitors` (capacitors that are placed near ICs to stabilize voltage on power supply lines—they are in parallel with voltage and connect to ground), it is generally good practice to place one **100 nF** per VDD pin and then use a bigger **1 µF** capacitor per section (e.g., VDD/VDDA/VBAT). Finally, finish off with a big **4.7 µF** or **10 µF** capacitor on the main voltage line before the STM32 to handle larger voltage spikes. If you have analog voltage (VDDA), it's also good practice to put a `ferrite bead` (like a capacitor, but it suppresses high-frequency noise currents) before connecting it to VCC to prevent noise from digital switching from interfering with sensitive analog functions.

It is also needed to place a 2.2 µF capacitor in series with VCAP and GND.

**VERY IMPORTANT: PUT A 2.2 µF DECOUPLING CAPACITOR ON EACH VCAP PIN OF THE STM32 OR IT WON'T BOOT UP.** (From experience)

Based on this information (and the schematic), try to wire up your STM32's VDD/VSS pins (VSS is GND, by the way). You should get something like this:

![STM32 VDD/VSS Wiring](https://hc-cdn.hel1.your-objectstorage.com/s/v3/e6095b36411c3e643774f58b9b3c081092aafb22_stm32_vdd_vss_wiring.png)

I placed the capacitors off to the side to make it look cleaner, but it's the same as if you were to connect them directly. Just make sure that when you are placing/routing them on the PCB, they are **AS CLOSE AS POSSIBLE TO THE PIN THAT THEY ARE DECOUPLING OR IT DEFEATS THE PURPOSE.**

## Clocks

Looking at the reference design above, it shows that we need some buttons for the reset and boot pins. These buttons allow us to restart the MCU and allow it to boot into its bootloader to allow for programming through USB.

We also have to add the 32.768 kHz and 25 MHz clocks mentioned in the datasheet. These clocks are important for PWM and other functionality that requires timing that you may want to add.

I am going to import all of these parts from LCSC using the script that we used before (including the ferrite bead). Here are the updated part numbers:

- C720477 (Button)
- C9006 (25 MHz Crystal)
- C32346 (32.768 kHz Crystal)
- C141723 (Ferrite Bead)

After running the script, import all of the parts in. I replaced the ferrite bead with the part from LCSC:

![KiCad Crystal Imports](https://hc-cdn.hel1.your-objectstorage.com/s/v3/91691ac20c4f8df67c7ba200e6293171f460e566_kicad_crystal_imports.png)

Now it's time to place the crystals. These crystal oscillators use a `piezoelectric` (ability of certain materials to generate an electric charge when subjected to mechanical stress, and conversely, to deform when an electric field is applied to them) `crystal` to generate a stable and accurate frequency reference signal. When using these crystals, you need to place `load capacitors`:

![Crystal Load Capacitors Concept](https://hc-cdn.hel1.your-objectstorage.com/s/v3/d3ba23499675e6512070856d276471b67ec2a60d_crystal_load_capacitors_concept.png)

Think of the crystal like a kid on a swing. It is going back and forth at a certain oscillation. The `load capacitors` would be weights that you add onto the swing to speed it up or slow it down to get the exact frequency. The same applies to the crystal oscillators. The capacitors are used to fine-tune the oscillations (clock speed) of the crystal.

Each crystal has a datasheet that specifies the load capacitance that it needs, and I have already looked them up for the crystals mentioned above. **REMEMBER THAT EACH CRYSTAL IS DIFFERENT EVEN IF THEY MIGHT HAVE THE SAME FREQUENCY.**

The capacitors for the 25 MHz crystal should be 20 pF and for the 32 kHz should be 6.8 pF. After you're done adding them, it should look like this:
![KiCad Crystals Wired](https://hc-cdn.hel1.your-objectstorage.com/s/v3/488106a8486103ec16373f9cf73232c74130121c_kicad_crystals_wired.png)

## Buttons

Now for the reset and boot buttons. These are super important for flashing or working with your STM32 in general. Taking a look at the reference design above, we need to connect the reset pin to a button parallel with a capacitor to ground. For the boot pin, we need to create a button that will set the boot pin to 3.3V when we press it. (Look at the datasheet to learn more.) This allows us to change the boot configuration depending on whether the boot pin is a 1 or a 0. In the end, it should look something like this:

![KiCad Reset and Boot Buttons](https://hc-cdn.hel1.your-objectstorage.com/s/v3/30fb452fc658a7f7d414cae4a78d54add0af4619_kicad_reset_boot_buttons.png)

## Servo Headers

Almost done, just need to add in some 3-pin headers to control the servos. They typically have a pinout of 5V - PWM - GND so it's good to keep the pinout in that same order. Mine looks like this in the end:

![KiCad Servo Headers](https://hc-cdn.hel1.your-objectstorage.com/s/v3/7d3ab72b1f8376df7fe260b52a718d59f6b87dbb_kicad_servo_headers.png)

# Finish Schematic

Now all that's left to do is to finish the schematic by adding net labels on all of the pins that we have used in STM32CubeMX. Your layout might look different from my layout if you're using a different chip or sensors, but here's how my STM32 looks after adding all of the net labels:

![KiCad Net Labels Schematic](https://hc-cdn.hel1.your-objectstorage.com/s/v3/34c585b194b51e08bafcf92fd029c35b274fff5f_kicad_net_labels_schematic.png)

For the USB lines, DM = DN, and DP = DP.

For the ICM SPI lines, SDI = MOSI. (For the ICM, it's an input, so it would be MOSI (Master Out Slave In) for the STM32.) By that logic, SDO = MISO.

Note that for the I2C lines, I changed the names to be able to connect to each of the devices like so:

![KiCad I2C Connections 1](https://hc-cdn.hel1.your-objectstorage.com/s/v3/e1a99f924c403e5ca44982fa1326b2f6ba094205_kicad_i2c_connections.png)
![KiCad I2C Connections 2](https://hc-cdn.hel1.your-objectstorage.com/s/v3/4615f7bec5f04cd21c69819354efb5a45eadc97e_kicad_i2c_connections2.png)

You may have a different pinout than me, but as long as you know which pins you are using and for what, then you'll be fine.

**DOUBLE TRIPLE CHECK THAT YOUR PINS MATCH THE ONES IN STM32CUBEMX.**

Now that you're done with your schematic, organize everything so that it looks nice. You might have to change the page settings via `File > Page Settings` in order to change the size of it:

![KiCad Page Settings](https://hc-cdn.hel1.your-objectstorage.com/s/v3/8154fb8f6a1c8275191cf1bbe07fdc3c391211ce_kicad_page_settings.png)

Now after organizing it a bit, your schematic should look like this:

![KiCad Final Schematic](https://hc-cdn.hel1.your-objectstorage.com/s/v3/86c7c8cc2b5632d2e4cbdc7bbabcc95df82542e4_kicad_final_schematic.png)

I placed text to name each block and added a title at the bottom right.

**Finally, we're done with the schematic!**

# Footprint Assignment

Before continuing on to the PCB, we have to `Assign Footprints` which basically tells KiCad how big each component is physically and how the connections look in real life to be able to solder it.

Click on this button to open the footprint selection screen:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/47bd7fde766bb2c548baa32176a3533c3103db33_footprint_assignment_button.png)

The lines in yellow are components whose footprints we have to assign:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/1cb8be2bf72a5f041a41b00fd790e0ffd0edd4ce_footprint_assignment_list.png)

But since it's mainly resistors and capacitors, that makes it a lot easier.
Since we're designing a flight controller, this has to be as small as possible, so I am going to be choosing the smallest footprints I can (while staying within good practices). The smaller the footprint, the more it can heat up and the less it can tolerate (for resistors and capacitors). A rule of thumb that I go by is any resistors under 80K I assign a 0201 footprint, over that and it's 0402. For capacitors, any `bulk capacitors` (capacitors that have high values like 4.7 µF or 10 µF) I usually assign 0402. Any bigger than 10 µF and I assign 0805, but it depends on the datasheet of the component. Under the application and implementation section there is usually a table that specifies which footprints/components to use. 


Now all that's left is to finish adding the footprints for these symbols:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/42be801f6fc4d7af4b65337780ca1afb4b01a196_footprint_remaining_symbols.png)

For the LED, I am going to have it in a 0402 package. And for the headers, I am going to use these footprints (basically the standard headers for jumper cables):

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/f8246043724ffe459aa341c245cff08d1e198467_header_footprints.png)

The inductors are a bit trickier. For this, you're gonna have to go into the datasheet and see where it says the size:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/d8449e733e2ae102ba2db187f6254531169b35b5_inductor_datasheet_size.png)

For that `5.6uH` inductor, I am going to be using `C18236327` (LCSC Part Number).


For the 5V buck-boost, I am going to be using `C3033018`. I also noticed that I had the inductor value wrong from the datasheet. **THIS IS WHY DOUBLE CHECKING IS IMPORTANT:**

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/f5c011b94dcb8880132b1bfbf4c25f4e2ada8786_inductor_value_correction.png)

For the final inductor in the battery charging IC, I am going to use `C435392`.

Press `Apply, Save Schematic & Continue` to save the footprints you have already placed and then import the new inductors that you have selected.


# PCB Layout

Now go to the PCB section in KiCad. There's a button at the top of the schematic page that says `Switch to PCB Editor` to go there.

Then to import all of our components from the schematic, we hit this button:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/5c74ad43a8d12b6293d3d5c8a165571429b15d21_pcb_import_button.png)

A screen should pop up:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/38d7e9aa0d1f121cdd315f49eea2970d624b423c_pcb_update_from_schematic.png)

There should be no errors or warnings. Then press Update PCB to import everything from the schematic.

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/acc124764d7af00c01c48aab5526f883f428efbc_pcb_components_imported.png)

Now comes the fun part, part placement!

## But wait, what's a PCB?

A `PCB` (Printed Circuit Board) is a board used to mechanically support and electrically connect electronic components. It is composed of layers of copper and a `dielectric material` (a material that acts as an "insulator" and isn't conductive). PCBs can have from 2-32 layers, although for this board, we will be working with 2 (maybe 4 if we need to).

In KiCad, if you look to the right, it shows the different layers:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/5e8975a52959dff20a3e83a73cd1b9c36cede118_pcb_layers_panel.png)

`F.Cu` and `B.Cu` (Front Copper and Back Copper) are our copper layers (denoted by the `.Cu`). The only other layers that are important to us are `F/B.Silkscreen` and `Edge.Cuts`. The silkscreen layers allow us to put text/images and is usually that white text that you find on any PCB. `Edge.Cuts` is the layer for the edges of the board (e.g., where JLCPCB will cut to make the outline). For now we will focus on the copper layers and routing. We can add more copper layers later in the board settings.

Now we have to connect each of the components and `route` them (create copper lines between each of them).

## Layout

I personally have always relied on this one trick to route my PCBs and it has always helped me without fail. First, separate the components into their respective groups (e.g., all of the components for the battery charger, 5V regulator, 3.3V regulator, STM, etc.), then lay them out and route them in those groups, finally put the groups together on the PCB and route the connections between them.

Starting with USB-C, go to the schematic and select the USB-C section:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/a84b22f03308e15d2e999dd0c2f0c62e3386d37d_schematic_usbc_selection.png)

Then going back to the PCB editor, you should see that the connector and its parts are selected. Then drag them off to one side.

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/bf96d2f4b657f7c458e53cf5cad485d0d5afd551_pcb_usbc_components_placed.png)

Do the same for each of the sections and after you've done that you should get something like this: 

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/51cd3927e5619231b3af5cd9604d8cd486de681a_pcb_all_groups_separated.png)

Now go section by section and place the components close to where they're supposed to be connected. Make sure to place decoupling capacitors close to the pins that they need to decouple or they won't work.

Example of the USB-C connector:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/3b629c240ec77ab266a3a0afa108f11405ccf7c3_pcb_usbc_layout_example.png)

I placed the resistors close to the pins that they need to decouple and in a good orientation so that I can connect that ground pin easily.

For the 3.3V Buck converter I routed it like this:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/6b75e5537f105b5c5353c57aed6bc4d04d905716_pcb_3v3_buck_initial.png)

But now I'm realizing that the components I chose are too small so I am going to make the capacitors and resistors a bit bigger:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/ec4820e3eabc124f44d0fae69a5be5e72f6fb5d0_pcb_3v3_buck_adjusted.png)

Ignore the silkscreen for now (the yellow) we are going to come back to that later.

Continue on for each of the chips. For example, here is how I placed the 5V buck-boost converter:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/803dc0894d23718ebdefc5765b7360d2ded21e1b_pcb_5v_buck_boost_layout.png)

As you can see, the capacitors are close to the pin and to each other, and all of the components I have placed in a way where I can create easy connections like so:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/188b44883ac680256966226baef217e27d79acf7_pcb_5v_buck_boost_routed.png)

Moving on to the battery charger:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/c50c289127f6626e398e1dd93f156aa9239ca0dc_pcb_battery_charger_layout.png)

Crystals:
![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/76f227974fe3d2b921e392e30138a33b9446e04f_pcb_crystals_layout.png)

microSD Card:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/41d6114e338889ba5d63748b70cfa9f866ba72e4_pcb_microsd_layout.png)

For the STM32/microcontroller, it's a personal preference of mine to rotate it 45 degrees so that it's "easier" (subjectively) to route later. You can change this by editing the `orientation` property:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/8c1f0de5244fd0ec0d7717ce06b3c9b516a39b67_pcb_stm32_orientation.png)

Also for these decoupling caps:
![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/76502c959ad4635ccd32438fe04be6963847d750_pcb_bulk_decoupling_caps.png)

I changed the sizes to be 0402 as they are bulk decoupling capacitors and should always be a bit bigger than the normal ones.

After laying out the decoupling capacitors for the STM32, it looks like this:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/5dfeaa33d4b381d5c84d2e703e40e1cc59e76e8a_pcb_stm32_decoupling_layout.png)

That one capacitor that is by itself on the right is the big 10 µF capacitor that I plan on laying out later depending on where the 3.3V is coming from.

### Final Layout

After you're done laying out all of the `passive components` (resistors, inductors, capacitors, etc.) and their respective ICs, it's time to layout each of those groups on the board.

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/dc1f136a2df1a4ca28bcb8c33d55769bf3cb4857_pcb_initial_board_layout.png)

Here's what my "board" layout is and I'm going to play around with the placement of each of the groups before routing to make it more compact.

**TIP**
![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/92272445077cc29c87fd74e989962ff542e9123c_pcb_group_components_tip.png)
It may be helpful to literally group them in KiCad to move them around easier.

After a bit of laying out and thinking I came up with this:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/3ef2a6374abc23e6a60bff482baacbaf339947b9_pcb_final_layout_organized.png)

The battery charger is close to VBUS and then VSYS has an easy path through to the 3.3V buck converter and 5V buck-boost. The battery connector is also on that side. On the top is the microSD card with a connection to the STM32 directly under it. On the top left are the buttons for boot and reset and also the 2 clocks. On the bottom left is the IMU that is kept separated from the rest to reduce noise (happened by accident lol) and the STM32 in the middle whose USB DP and DN pins are inline with the USB-C port.

You don't have to use this exact layout but try to have one that's "organized".

Now after defining the layout, go to the `Edge.Cuts` layer and create a rectangle with the tool on the side:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/2f8a0dea520b2ac94f1f2f45f5c41641d1f7ba56_pcb_edge_cuts_tool.png)

This will be the PCB outline.

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/448816c6d568b80d56df0a55174900900238a363_pcb_board_outline_drawn.png)

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/a0be299721829a198f4767003db2bde317e1fe49_pcb_board_dimensions.png)
When I originally created the board size to cover all of the parts, it had a size of 42.7mm x 47.8 mm so I decided to round it to 40mm x 46mm (optional). After creating the board outline, you may need to shuffle some stuff around for it to fit. It's good practice to put the USB-C connector hanging out a bit so that you have space to plug in the cable like so:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/a8d0756383184e8dfe1608b29c6214f451bf6638_pcb_usbc_overhang.png)

After organizing it, look at the board in the 3D viewer to get a good feel for how the components are going to look. Don't worry if the silkscreen/3D models look terrible for now, we will fix that at the end.

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/5d9e172b022b401c32c22f828ad2da025c2590c1_pcb_3d_view_top.png)

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/fd2612614f050ddaf3424b4a6970b447ff157a89_pcb_3d_view_side.png)

## Routing

Before we start routing, let's configure the `Design Rules`. These are rules that KiCad has to impose certain restrictions like spacing between components and track width and via size, among other things. It is also where we can add default sizes for `vias` (holes that connect tracks between layers) and `tracks` (copper lines that connect components).

Go to the `Pre-defined Sizes` section:
![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/8d91bc46653535a8416d3165bc3cff5bef3da659_pcb_predefined_sizes.png)

I am going to add `0.6mm`, `0.4mm` and `0.2mm` track widths. For vias, I usually go with vias that have `0.6mm Diameter / 0.3mm Hole` and `0.4 Diameter / 0.2mm Hole`.

Now after that we have to edit the `constraints` of the board so that KiCad doesn't throw an error when we try to place them. Go to the `Board Setup` and then `Constraints`.

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/1aadb0c0da8763f5512198ce4104451067d8ac24_pcb_board_setup_constraints.png)

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/151af206137f6852dc0e64675b698ed13e723c66_pcb_constraints_settings.png)

Here we are going to change a couple of settings due to the size of our board. We need to be able to place smaller vias and traces, so change the `Minimum via diameter` to `0.4mm` and the `Minimum through hole` to `0.2mm`. After that's done, click OK and you can start routing!

### How to Route

Basically connect each of the pads to their connections and try to use as few vias as possible. I usually try to route the signal stuff (USB, sensors, microSD, crystals, etc.) first and then the power.

(Press x to start routing or use the buttons on the side).

Starting with the USB-C data lines, these are what's known as a `differential pair`, so they have to be the same length as they carry a signal that needs to be in sync with the other and the only way for that to happen is if they're the same length. Start connecting them like so:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/5007b05f91d2c46e7748ab71fafc4dd2392e53ae_pcb_usb_differential_start.png)

Then go to `Route > Route Differential Pair` 
![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/e3044760e0daa41c1c2f93a840b88a1a24e39881_pcb_route_differential_pair_menu.png)
and then click on the USB_DP to the far right:
![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/f9bda1da977a8f5bbd12305a27a8ade3f0bda3a8_pcb_usb_differential_routing.png)
Then route it to the STM32. That's basically the only component that needs differential routing.

Moving on, just some general tips. I personally like to use `0.6mm` or `0.4mm` width for power stuff, mainly anything that runs either 5V (0.6mm) or 3.3V (0.4mm), and you can change the track width or via size from these drop downs at the top.

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/17ab1fcc961849b7c96f3142f1cb00eadc32fe91_pcb_track_width_dropdown.png)

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/531b3f680cbc585654d518cdafe03b0a691225dd_pcb_via_size_dropdown.png)

I also like to do the same as in the layout where I route all of the passive components to their respective ICs before then routing those groups together. For example, routing the decoupling capacitors to the IMU before connecting it to the STM32:

![IMU Decoupling Capacitors Routed](https://hc-cdn.hel1.your-objectstorage.com/s/v3/db81f7f25a949b3e66bfc40fad4fe114817212ae_pcb_imu_decoupling_routed.png)

You might have to rotate components as well to get a good placement. For vias, I aim to use a maximum of 2 per line like so:

![Via Placement Example](https://hc-cdn.hel1.your-objectstorage.com/s/v3/333c89c3eacdae130001e62cf12007d0a4beb12a_pcb_via_placement_example.png)

Don't worry about connecting the GNDs for now, as we are going to use what's called a `ground plane` (a copper area of GND that can connect to pins/pads).

Sometimes for VBUS on USB-C or any other component, you might have vias that can't pass through, so I added a `0.3mm` track width in the board settings and it works:

![VBUS Routing Issue](https://hc-cdn.hel1.your-objectstorage.com/s/v3/c6fab4f979d8a0060f953e24ba58aa6cda776e7f_pcb_vbus_routing_issue.png)

![VBUS Routing Fixed](https://hc-cdn.hel1.your-objectstorage.com/s/v3/ac63949260b423cb9e3545a33ce7e68caa42ae54_pcb_vbus_routing_fixed.png)

If KiCad doesn't let you place a via on a pad for whatever reason, you can edit the clearance in `Board Setup > Net Classes`. I set it to 0.15, but try not to set it any lower as the minimum for JLCPCB is `0.1mm`: 

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/ce45b43a0986bfd9f7c09d50e6264f37e2999a2f_pcb_net_classes_clearance.png)

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/907eb54dbe539772ada718d0a0494d23abd6ada0_pcb_via_on_pad_placed.png)


This is how I routed the Battery charger:
![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/f01878d60b3499c1f3119d121367adc095038a66_pcb_battery_charger_routed.png)

See how I used wider traces for power lines and thinner traces for the other pins. I plan on wiring the I2C lines and INT pins connecting to the BMP580 like so:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/c03529ba4eee753126b6da05aa60ca9f3615b498_pcb_bmp580_i2c_routing.png)

I connected them to the STM32 through the underside to save space (very useful sometimes). Also, I hid the silkscreen layer so that I can route easier.

Then routed the microSD card:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/2f7a053291e85d75db06de364503279d2fb4ecee_pcb_microsd_routed.png)

Then finally I routed the 3.3V line, using 0.6mm tracks and then branching off into smaller 0.3mm tracks to connect to the different ICs.

**REMEMBER THAT THE 3.3V MUST GO THROUGH THE DECOUPLING CAPACITORS FIRST BEFORE REACHING THE PIN LIKE SO:**
![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/3b489d22eedc68b7b8af7e759accc98384f6952d_pcb_3v3_through_decoupling_caps.png)

After routing your board should look something like this:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/6123dcda724abdbe564862cfd59c388e0b517837_pcb_all_routed_complete.png)

Now we are going to add the ground pours. This is so that we don't have to manually connect all of the ground pads and it also helps with interference and noise across the board.

Go to the right and click on `Draw filled zones` and click on one corner and a window should pop up:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/c3f4c371c8fd4741834a16bd88776552bde60f16_pcb_ground_pour_settings.png)

Here you need to select both layers of copper and select the GND net. Then you need to change the clearance and minimum width to both 0.2mm and also change the `Pad connection` to `Solid` or `Thermal reliefs`. Solid allows the ground plane to connect to the pads better but Thermal reliefs is good if you need to solder/fix the board as the solid ground plane makes it difficult to heat up specific components. For this tutorial I am going to use `Solid` but feel free to use `Thermal reliefs` if you want to be able to solder it later. Press OK and start creating the zone like so:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/cc3274a0944f55f82864c3bea41ba4661f439a0e_pcb_ground_pour_outline.png)

You want it to look something like this:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/cc3274a0944f55f82864c3bea41ba4661f439a0e_pcb_ground_pour_outline.png)

Then press `b` on your keyboard and it should fill the zone automatically (`Ctrl-b` to clear them).

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/e859b4408e82c40d7110b84e302d63c6321d0211_pcb_ground_pour_complete.png)

Now you should check if you have any `ratlines` (blue lines that signal unconnected pins) and fix them. In my case, I forgot to connect the servos so I will do that now.

Now you need to check if there are any holes that don't have any ground plane and add a `stitching via` (via that connects ground/power planes to cover everything) like so:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/7f4ea2670025d1c5407cfa5b9f8970bd26e693bd_pcb_stitching_via_location.png)

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/0489a1ccd8b17372d37ac83946b4439ebb4ba2c3_pcb_stitching_via_placed.png)

You also might see a ratline connecting a piece of the ground plane. This usually means that you need a stitching via in that area.

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/703ebc948aacf286334890e817b472366d6ff5b0_pcb_ground_plane_disconnected.png)

As you can see, the ground plane connecting to Pin 18 isn't connected to the rest of the ground plane, so we need to add a stitching via there like so:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/ec259459e9e0e4c3d3ec97dab4e053765ff8d524_pcb_ground_plane_connected.png)

**SUPER IMPORTANT: FOR ANY COMPONENTS THAT HAVE A THERMAL PAD, CONNECT IT TO GND WITH A STITCHING VIA (depends on the chip but check the datasheet to be sure):**

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/70c2572d368bbde4d8af647dafe78bf1b493eb01_pcb_thermal_pad_via.png)
(You can edit the properties by right clicking the pad and editing the `Net name`.)

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/3fe26fcb5a9cae8992bb10b34b497173445ac4bc_pcb_thermal_pad_net_edit.png)

Also Notice how I didn't connect the grounds together and connected both PGND and GND, that was made automatically by KiCad when I connected the EP Pin of the battery charger:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/36dd873c5b6c3f7f9e4329ad3f084c63c892d65b_pcb_pgnd_gnd_connection.png)

After connecting everything we are going to run `Check DRC` which basically checks the design rules and makes sure our board is ready for production.

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/f6a6cf323c7105e70c08637bea442c94347b4722_pcb_drc_check_button.png)


Then click on `Run DRC`:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/550bd5b3051d387fda135777b466598f695b90e5_pcb_drc_run_button.png)

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/9a99952db4d7dcb741463d6788c673ab0329500f_pcb_drc_results.png)

Unselect the warnings and look at the errors. If there are any errors about unconnected pads then you should probably go back and make sure that everything is connected. There are some errors but those are from the parts that we imported like the USB-C and microSD card that KiCad is complaining about the holes:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/ca24efa42d21abb21263b99ff999a1f61d7e940e_pcb_drc_errors_from_imports.png)

Those errors are safe to ignore but any others you should probably fix.

And with that out of the way, congrats! You've finished the PCB!

Now all that's left is to add silkscreen and make it look pretty and then get the files ready so you can order it on JLCPCB (or any other board manufacturer).

# Finishing Touches

Now I'm going to fix the silkscreen component names so that they look better (and a bit smaller). Go to `Edit > Text & Graphics Properties`

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/ac3b345f193c7bde36330edcabd45c878d050897_pcb_text_graphics_menu.png)

This window should show up:
![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/0f1bc20f8f294ffea47f49206060fb12132170de_pcb_reference_designators_window.png)

Here you're going to select `Reference designators` as this will select all of the designators (R1, C1, etc...) on the board so we can edit their properties. Then in the action I am going to change the font and the size:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/85edc6cf9f0421dd70af49c57c3ac9f0de3c0f29_pcb_silkscreen_font_settings.png)

You can set these values to whatever you want but I am going to go with this. Then click `Apply` to test it out and `Apply and Close` when you are done.

Now all I'm going to do is organize the references like this:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/712a95b8bd5dc06f155910859b92d2b0cb91bd29_pcb_silkscreen_before.png)
(before)
![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/b84fb7526df22229a5b75049c35bd29c2c9b61e0_pcb_silkscreen_after.png)
(after)

This is completely optional but look at how neat it looks now with all the designators/references properly sized and placed:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/6aa086f11b5db28d64eb4f1e5a0f1e14b202d60f_pcb_silkscreen_organized.png)

I even added text to the battery connector to show which side is + and -.

If you want to add the 3D models to render, then just go to properties and find a 3D model that works for you:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/6e9d9f24a82f3ddf2646ef9358a2859d422eb5e9_pcb_3d_model_properties.png)

(You may have to click on the folder icon next to the path/show button to change the 3D model from a `.wrl` to the `.step` in the same folder for imported LCSC parts for it to show. Just changing the name will not update it.)

![3D Model Before](https://hc-cdn.hel1.your-objectstorage.com/s/v3/2358fcf199d98f621b7d24eb48761363034edb07_pcb_3d_model_before.png)
(Before)

![3D Model After](https://hc-cdn.hel1.your-objectstorage.com/s/v3/b7dd0f50ab2463ee9a4802534349867b1ffbac7d_pcb_3d_model_after.png)
(After)

And you're done!

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/50d7618ce15309279a6206f3cdfa7024a8a57cb3_pcb_final_complete.png)

# Exporting Production Files

To get your project ready for submission, we need to export the production files (gerbers, etc.). These files tell JLCPCB or whatever board manufacturer how to make the board and which components to place.

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/a0641970cc3d80902ed1c175e30f17c2872ea231_jlcpcb_plugin_icon.png)

Thankfully, there's a plugin that KiCad has to make this export easy. Go to the `Plugin and Content Manager` in KiCad and search for `jlc`.

You should see this plugin show up:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/cbf1490de31b0932d2dcdc4515af6478308481e1_jlcpcb_plugin_install.png)

Press the install button and then `Apply Pending Changes` to install it. Finally, go back to your PCB screen and you should see this icon:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/912cf846c397933d69b474862440ff35b3b6f185_jlcpcb_fabrication_icon.png)

A window should open and click `Generate`:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/cd613f813c276c666a4f8dac1c326394d9614d5d_jlcpcb_generate_window.png)

It should create this directory in the `hardware` folder:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/69d6c2eb3eb07c8b5d1597a030fc1bf6048a6483_jlcpcb_production_folder.png)

But I'm going to copy it out of that folder and move it to the root so that reviewing is much easier.

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/8352ad45cd7ccff9c36babb4455258598c247a99_production_folder_moved.png)

Now open [JLCPCB](https://jlcpcb.com/) and upload the gerbers (ZIP file that has the name of the KiCad project) in the `production` folder to see how much it costs.

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/7e39144c9db40181e599d0ca5d7801a4b46a2949_jlcpcb_upload_gerbers.png)

Select `PCBA` and make sure that it is only one side and that you order 2 and not 5 boards assembled to minimize cost:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/89c577fe501c0d75c65cffc5779a8c087aaf1398_jlcpcb_pcba_settings.png)

Continue and upload the `BOM and CPL` (BOM = bom.csv, basically the components and their ID; CPL = positions.csv, where exactly the components are placed):

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/5d416a7f80f2a1edde04c7cddce06ae755dbeabe_jlcpcb_bom_cpl_upload.png)

Depending on the sensors you use, you may have to use standard PCBA:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/fae08bdf789daec4ad92938e3bb98aa2ccf00408_jlcpcb_standard_pcba.png)

If there are any components that have shortfall, then you need to order them separately and add them to your library before ordering:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/c228a66275da19d1c764edca0fd4b57594c1ec2d_jlcpcb_component_shortfall.png)

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/309859e47ab12113c2301b697d507e5930f1ad82_jlcpcb_parts_list.png)

Continue without placing the parts for now to get the general cost of the board:

![alt text](https://hc-cdn.hel1.your-objectstorage.com/s/v3/d0959ff7ab616e8d3d994604bad7e69b68ada6ad_jlcpcb_final_cost.png)

**CONGRATS! YOU'VE MADE YOUR FIRST FLIGHT CONTROLLER!**

Feel free to modify this board to include more sensors, servos, peripherals, microSD cards (lmao), literally anything you can put your mind to.

# Firmware

Now you can either write your firmware through STM32CubeMX/VSCode or use [STM32duino](https://github.com/stm32duino/Arduino_Core_STM32).

## STM32CubeMX

After you have received your board, you need to write the firmware to communicate with the STM32. From STM32CubeMX, go to the `Project Manager` section, then click on `Toolchain / IDE` and select `Makefile`. This allows you to use `VSCode` or any other code editor to edit the files much more easily without having to use ST's software.

![STM32CubeMX Toolchain Makefile](https://hc-cdn.hel1.your-objectstorage.com/s/v3/40d409ff6b572200bf5ab31adcf420c17a31d84c_stm32cubemx_toolchain_makefile.png)

Now click the `Generate Code` button at the top and download/install any packages that are required.

After that's done, open `VSCode` and open the `software` directory. You're also going to want to install this extension to make building the software much easier:

![VSCode STM32 Extension](https://hc-cdn.hel1.your-objectstorage.com/s/v3/d346cc47c7e62ee781fbfc7e4bb14bc64d8d0b6c_vscode_stm32_extension.png)

Then you should see this button on the side:
![VSCode STM32 Sidebar Button](https://hc-cdn.hel1.your-objectstorage.com/s/v3/184dc2fabc0d05636d18ecac6742d3b23ef22e47_vscode_stm32_sidebar_button.png)

This will allow you to build and flash your flight controller all from VSCode!

![VSCode STM32 Build and Flash](https://hc-cdn.hel1.your-objectstorage.com/s/v3/e30b0ede9b8baeb1f998cc37b3211cf05f45cd24_vscode_stm32_build_flash.png)

If you need to edit the pinout or functions of any pin, remember to generate the code again from STM32CubeMX.

Edit `main.c` and remember to keep your code inside the commented sections that say `USER CODE BEGIN` and `USER CODE END` to prevent it from being overwritten when you generate the code again. There are many tutorials online/on YouTube on how to program with STM32, so I'd recommend looking there. You will also need files called `drivers` to control each of the chips/sensors that you use, but those can be found on the internet/GitHub and can be imported into your project easily. ([example](https://youtu.be/dnfuNT1dPiM?t=1343))

## STM32duino

Follow the instructions in the [GitHub](https://github.com/stm32duino/Arduino_Core_STM32#getting-started)

---------

If you have any questions feel free to DM me on Slack (@NotARoomba) and if you want to check out my other projects, here's my [GitHub](https://github.com/notaroomba) / [Website](https://notaroomba.dev).