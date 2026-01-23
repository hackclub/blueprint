| title       | Blinky Board Assembly Guide                                   |
| ----------- | ----------------------------------------- |
| description | Learn how to correctly assemble a Blinky Board |
| unlisted    | true                                      |

### Step 1: Join Hack Club Slack  
- Start by joining [Hack Club’s Slack](http://hackclub.com) by visiting the website and clicking on join slack.  
- This is where you can ask for help on your project, and learn about new ways that you can keep building awesome hardware and software projects.  

### Step 2: Lay Out Components  
- Lay out the components in your kit.  
- Match them to the components in your schematic.  

### Step 3: Learn to Solder  
- If you’re new to soldering, please check out some of the ‘how to solder’ guides like this one before you start.  
- Refer to [Adafruit’s Guide to Excellent Soldering](https://learn.adafruit.com/adafruit-guide-excellent-soldering).  

### Step 4: Insert Chips  
- Start by adding the chips into the board. Both the 555 (U2) and the 4017 (U4) have indications of where the top of the chip is.  
- Look for either a notch on the top edge or a dot next to pin 1, which is always the top left pin.  
- Carefully insert those chips one at a time into the board paying attention to the drawing on the PCB which indicates where the top should be.  
- As each chip is inserted, turn it over and carefully solder all pins in place.  
- Make sure that the chip is completely seated on the board before soldering.  
- Note that chips are sensitive to overheating so try not to keep the soldering iron on the pin your soldering for any longer than it takes to melt the solder and let it flow around the pin.  
- A well soldered pin will have a smooth coating of solder, with no parts of the pin’s hole visible.  
![Image 1](/old-cdn/ecfad937e5afccde3361afeec1f442a290bbba64_image_1.webp)  

### Step 5: Install LEDs  
- Next put in your LED1-LED10 LEDs.  
- Choose any colors that you wish: all one color or a mix.  
- Install them by orienting the flat side of the LED with the flat side of the outline.  
- Note that the flat side of the LED corresponds to the short lead of the LEDs which marks its cathode (negative) side.  
- Again, solder carefully making sure you don’t overheat the LEDs.  
![Image 2](/old-cdn/a6bee3823ca490db121e9bd595f2aa76a1896fd6_image_2.webp)  

### Step 6: Mount Capacitor C1  
- Mount C1, the 1 microfarad electrolytic capacitor.  
- Note that its negative side is marked.  
- The unmarked side opposite the minus is the positive side.  
- Insert that in the hole on the C1 outline marked with a ‘+’.  
- Solder the capacitor in place.  
![Image 3](/old-cdn/dc714e4689acd4bddea5bdeea3caa9582c38e7d9_image_3.webp)  

### Step 7: Install Potentiometer  
- Install and solder the potentiometer.  
- Make sure you can reach the adjustment screw with a small screwdriver.  
![Image 4](/old-cdn/983f17254765ec883f62937f0f8612bf19068ca9_image_4.webp)  

### Step 8: Mount Resistors and Capacitor C2  
- Mount and solder all the 2 lead components: R1, R2, and C2.  
- It doesn’t matter which direction you mount them.  
- Note that the bands on the resistors may be hard to read.  
- The 470 ohm resistor has bands that are yellow-violet-black-brown.  
- The 1K ohm resistor has bands that are brown-black-black-red.  
![Image 5](/old-cdn/aff5e52797d5e81c27b879af9d4122d1f5080395_image_5.webp)  

### Step 9: Install Headers  
- Mount the two pin and 1 pin headers.  
- The two pin header will be used to power the circuit.  
- The one pin header is optional and can be used to see the clock on an oscilloscope or drive another project.  
![Image 6](/old-cdn/f388ebbee86f8d944eb1d85bf6070f9faec4ae7f_image_6.webp)  

### Step 10: Connect Battery Clip  
- Connect the two pins of the battery clip to the 2 pin header.  
- Make sure that the positive (red) side of the battery clip pins connects to the positive voltage on your card.  
- The positive is the one that is connected by PCB wires to pins 8 of U2 (upper right) and pin 16 of U4 (upper right).  

### Step 11: Test Your Circuit  
- Connect a fresh 9 volt battery to your battery clip. 
- If you see blinking you’re done! Congratulations.  
- If you need help debugging, or just want to show us what you’ve built, go to the [#blueprint-support](https://hackclub.slack.com/archives/C09CMJV6V6K) channel on the Hack Club Slack (start at [Hack Club](http://hackclub.com)) and let us know what’s up!
