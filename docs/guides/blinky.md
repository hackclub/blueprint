# Blinky Board

Made by @CAN

Hi there! This is a tutorial on how to make a 555 LED Chaser board otherwise known as a “Blinky Board”. You can follow this tutorial, customize your design and you will be shipped the parts to build it! 

## Here is what we will be building:

We will all build this LED chaser which blinks 10 LEDs in a variable speed sequence. 

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/766c5aee15a8c57b1bd57467f3382fc68c0a627c_unnamed.gif)

Here’s the schematic: 

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/e089878c0586cfaaef00bc5f3b7da4044525edf6__3A16B0A8-2A46-4CCC-9F58-228AC47FAB86_.png)

## What we’ll be doing

- Set up [EasyEDA](https://easyeda.com/)/[GitHub](https://github.com/)
- Design a Schematic
- Create a Printed Circuit Board (PCB)
- Submit your board for manufacturing at JLCPCB
- Get a PCB grant from Hack Club Blueprint
- Wait a week for your board to come back
- Solder your board
- Test your board and enjoy!

## Set up accounts

If you haven’t already, you should create an account on [EasyEDA](https://easyeda.com/) and [GitHub](https://github.com/). EasyEDA is what you will use to design the PCB and GitHub is where you will share it.

## Create your project

Go to [easyeda.com/editor](http://easyeda.com/editor) and click Design Online > STD edition. We are using the standard edition for simplicity sake but the pro edition is nice and its free!

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/a83f8d3eb5790cd6666ed4bf6600e5985f8cd87a__A476BF7E-89EE-422E-B563-63182A7A19B7_.png)

Now click New Project > Name your Project > Save

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/49fcf0556cda7a369c0949d7fa8d21f5f6df16d8__188E0BAB-5E62-4FD4-9D15-9791E8A4DB0C_.png)

## Create your schematic

You should see something like the image below. That is the schematic editor where you will be making your circuit diagram. Below are some useful tools.

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/8cc3b535f214f0b6be2e74aa564047dd41c72dd7__21B71484-212D-4F6E-BE33-5CC7F8DD864B_.png)

Here are the components we will be using: (IC stands for Integrated Circuit)

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/d91b426a709588e2ab5803427c3624a753450f45__771DD54A-39E4-4922-9E2C-BAE6DBCC179B_.png)

In schematic, things are represented as symbols. Here are the symbols for the components above:

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/ca8bd830950c4bf32c887793df420ea52141425e__83C593DD-25FA-4281-B875-CDAFA65B4C39_.png)

In order to place components (aka symbols), you need to click “Library” and search for a component number such as “CD4017BCN”.

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/4f0fc7ce84b7e363a93d6c04860ce5dfc76e45d4__A96120AA-08F2-49DF-AB22-62FBFAA633F5_.png)

You will now need to go through and find all of your components. Luckily, we already compiled a list of everything you need to place. Go to Library>Click on the part number>Place for each of the parts below:

- **C46749** (this is your 555 IC which is famous in circuitry)
- **C32710674** (this is your main 4017 IC. It controls all of the LED’s flashing given an input from the 555)
- **C492401** (this is your header, or little pins which you will use to power your circuit)
- **C81276** (this is another little header which you can use for debugging your circuit)
- **C62934** (this is an electrolytic capacitor, it is directional so be careful!)
- **C249157** (this is another cap)
- **C713997** (this is a 1k ohm resistor)
- **C58592** (this is a 470 ohm resistor)
- **C118912** (this is a potentiometer otherwise known as a variable resistor. You can use this to control the speed of the flashes)

You will also need to place a total of 10 of the different colored LEDs below. You will get 10 of each color in the kit so don’t worry!

- **C2844743** (red LED)
- **C779445** (orange LED)
- **C330770** (yellow LED)
- **C2895483** (emerald LED)
- **C473834** (blue LED) (elite ball knowlege required)
- **C2895480** (white LED)

Here is a good point to remind you. If you ever need help, ask in #blueprint-support on the Hack Club Slack. 

## Place your components

Now that you have placed all of your components, you should arrange it as below. This will make it easier when you wire.

- You can use ‘r’ to rotate them
- Use Copy and Paste when you need more, E.g. to make 10  LED’s
- Remember to save (Control-C or  ⌘-C) often !!!!

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/b86449f89ce3fbcc4dfb37cfea56d0e402fbd122__0B589CAB-0E7F-403F-90D3-7350DD6C9C88_.png)

## Wire your components

Don’t mess this up! Make sure your wiring matches the diagram below. The little red dots indicate that two wires are connected. Make sure that the wires which are supposed to pass over each other are not connected!

- Click “w” or the wire button, or click on a terminal of a component
- Wire together GND of all the LEDs
- Check out Shortcut keys (Settings-> Shortcut key settings)
- Remember to save (Control-C or  ⌘-C) often !!!!

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/778ce6cb2c018696f8354aabb15b7112f4873a99__BBC27CE3-7A26-4E46-AFA7-E725BDBB9552_.png)

Your schematic is complete! 

Reminder: ⌘+ S OR Ctrl + S to save your design often!

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/5aaf335b6f95cb2efb09573d6b4c74a52d61f8ed__534392E2-01CF-42B4-B1E8-7F2185EB0ACD_.png)

## Create a Printed Circuit Board (PCB)

Now, its time to convert your schematic (circuit connection guide) into a PCB (the physical layout of the connections).

At the top of your screen, click 

**Design > Convert Schematic to PCB**

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/111cd17b9f2a14453f1ba78ca456d652ccda152b__D27CDDB5-8BEC-4FF4-880A-04901B93BCE1_.png)

<aside>

Note if you are trying to make changes to your PCB later:

Use Update PCB! It preserves your PCB layout!

</aside>

## Create an outline for your PCB

For this tutorial, I will be making a rectangular for simplicity sake. However, 

**YOU NEED TO CUSTOMIZE YOUR BOARD WITH A CUSTOM OUTLINE AND ART**

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/d3c10a29dc99ea3ab31c5ff7d3d893319974b98d__BA6D32FD-B511-4C8B-AAD5-D6D800E09D17_.png)

First, select the “Board Outline” on the sidebar. 

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/9f20de70d8fa423169ec12cf1fb5fd9318276b63__1841ADE8-E6F4-47D0-8E13-D9BB8295298E_.png)

Next, you can either make your own board outline using the “Line” and other features in the toolbar.

…or you can find a custom DXF online to have a custom outline.

File→Import→DXF

(you can also convert an image to a DXF using an online converter such as convertio) 

One thing about the DXF’s you may need to scale it online. Make sure to always keep your board below 100x100mm. 

## PCB Layout

Once you have your board outline, you need to organize and wire your components. You should get familiar with the PCB tools:

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/cac16711c0f9702ef11d943fd693658a2e30f9ed_image.png)

A PCB is made out of multiple layers. Our boards are “two layer” meaning that they have two layers of copper wire. 

The layers include: 

Top and bottom solder mask: the white ink where you can do art 

Top and bottom copper layer: the layers where you make your copper wires 

Substrate: The actual plastic (usually green) which makes up your board

Via: the tunnels which connect the top and bottom copper layers

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/c2ec73f247fdb1f466903fc86d345fe0f4b47b6f_image.png)

## Place your components

Place all of your components inside the Board Outline. Move components to shorten ratlines, which are are the straight blue lines. You can use ‘r’ to rotate.

Remember to save (Control-C or  ⌘-C) often !!!!

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/066ff9acb3435c5bd772890417b8702c9edde7a7_image.png)

(remember that your board outline, the purple lines, should not be a rectangle but some custom shape)

## Wiring your components

The ratlines (the blue straight lines) in-between your components is not the complete wiring. They are just telling you where connections should happen. 

On the side bar, you can choose either top layer (red) or bottom layer (blue), or a combination of both to wire your components. 

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/8ea222f123d51cdd5bf2cac00b055ce98718d1d0_image.png)

If it is impossible to make a connection in one layer, you can add a via. A via acts as a tunnel to connect between the two copper layers. As you are wiring you can click ‘v’ to place a via and switch to the other side.

Your PCB is routed!

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/a8846471c379ddc28fc84b366451824d841dfee6_image.png)

## Customization

You may have already added some text and art to customize your board. if not, you can click “TopSilkLayer” and use the text tool.

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/28771d826d2ce20407a101f5c342212a67b547f8_image.png)

To add art, just select the “Top Silkscreen Layer” or “Bottom Silkscreen Layer” in the sidebars. Then you can do: 

File→import→image 

to add custom art. 

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/0eb5896b961ad09975eeb0ae08aec282107ba53c_image.png)

Your board is now beautiful

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/e2462343267cd8a90cd643b0eea6dac4adb34b28_image.png)

## Run Design Rules Check

Click Design → Run Design Rules Check 

This runs a script which makes sure that your board has no interference errors, no components are off the board, and no wires are intersecting. It does not however confirm that your board works.

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/45d9dc52ccf5d311e8105d5d6b5498618cd0dd0f_image.png)

Using the output, correct any errors. 

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/ac4cbd4a863e01e5f5b6609f40a1945a42a3481e_image.png)

Once your PCB passes the DRC, it is finished!

In PCB editor click View > 3D View to see your finished work!

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/50638b1bb956cd429eab5755e7aaf142ffe088db_image.png)

## Creating your project repo

Now it is time to order your board.

Get the following files of your project: 

- A screenshot of your 3d view (see above)
- A PDF of your schematic (In your schematic editor do File → Export → PDF)
- Your schematic (in your schematic editor do File → Export → EasyEDA)
- Your Gerber (in your PCB editor do File → Generate PCB Fabrication File (Gerber))
- Your PCB (in your PCB editor do File → Export → EasyEDA)

A PDF of your schematic (In your schematic editor do File → Export → PDF)

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/5e6decf5d2fa92253b9a567b15b92ab3e684266d_image.png)

Your schematic (in your schematic editor do File → Export → EasyEDA)

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/4066809bebc778265301e03e75d70c686cb5e6ed_image.png)

Your Gerber (in your PCB editor do File → Generate PCB Fabrication File (Gerber))

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/647519e77f09584480f0cefe7b8ed5b6f21d96f3_image.png)

Your PCB (in your PCB editor do File → Export → EasyEDA)

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/ab6f09e8041e0c5eb56a74e34a87aab1e8a936c6_image.png)

## Creating your GitHub Repo

Once you have the five files, create a repository on [Github.com](http://Github.com). (you may need to create an account)

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/8c2a28ed6838101ae8c5def10c9115042637a201_image.png)

You need to 

- **Name it** - I named it 555 Chaser but you can do whatever
- **Write a nice description** - this can be short
- **Make it public**
- **Enable  a README** so others can see what you made

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/86cd75d246e16ce3a172caa472c49f2648ee92eb_image.png)

Once your repo is created, it is time to upload the five files you downloaded before. 

Click Add File → Upload files 

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/470145098fd2379b9385c1f49ddf795fbadfa1a3_image.png)

Drag in your: 

- PCB Screenshot
- Schematic PDF
- Gerber
- PCB EasyEDA file
- Schematic EasyEDA file

(you should have added all of these before)

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/8116375daf649aa342be5d409e010a5769f5ed81_image.png)

You can then click to commit your changes and your repo is done! Make sure to save the URL for your repo for later!

## Ordering Your Board

Go to [https://jlcpcb.com/](https://jlcpcb.com/) and make an account. Then, add your Gerber file for the instant quote. 

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/baaa0ca887d51110c30cba9d862968acbef618f8_image.png)

Settings: 

You should keep the default settings for everything. The only thing you should/can change is the PCB Color. I did black as seen below:

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/2b2ea8e606d05ddff382fdcc7934da4bff70615c_image.png)

For high-spec options, also keep the default. Do not click PCB assembly as we will give you a kit to hand-solder your board.

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/053061912ca84c66c46323ccef5b12cb71c7d721_image.png)

Once you have successfully *Not* changed any of the settings (except the board color), on the right, change the shipping method to Global Standard Direct, and take a screenshot (this is very important). 

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/6f538d5f301eae997544c43c1d6ce6daca01331d_image.png)

## Creating your project on Blueprint

You are almost done! At this stage you should have: 

- A completed board
- A GitHub repo for your board
- A price estimate and screenshot for your board

Now, you just need to create your project on Blueprint. Blueprint not only allows people to share their projects, but acts as a gallery of all the projects made. 

First, create your Blueprint account on [https://blueprint.hackclub.com/](https://blueprint.hackclub.com/) (⇒ Sign in). In the future, you will be able to log into your account anywhere, anytime to make your project. 

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/b7cf34ff897d78ad13372226165e67814934dae3_image.png)

Your screen should look something like this.

Click the “+ Start a Project” button at the bottom of your screen. You need to fill out the form (you can just copy the name and description from your GitHub repo). For your banner, just upload the 3d render of your PCB.

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/84fa13d1537256ffdb6f5fd9939f96f4f0603bd3_image.png)

IMPORTANT: 
Make sure you select the LED Chaser as your guide. Doing this will bypass the need for a journal in order to ship. For your future Blueprint projects, you will need to make an updated guide with what you are making.

Also, make sure you click “I need funding”

Now click “Create Project”

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/283a56a17d26ee6e3d42a9d20975cbaa25b04964_image.png)

Once your project is created, click into it on the project screen.

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/a73a0deeb8dbf8e604f0ebfda1f95f6f6ccd6daa_image.png)

Now, click “Ship It”

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/6d1688e2383ca416db27b57942698e7f24a88da9_image.png)

Blueprint will run some checks. If any are red, you need to fix them.

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/0e646bc3c854746bfd51172fa68cdba8a9df1625_image.png)

Enter the dollar amount which you previously screenshotted on JPCLCB (don’t worry, we will give you extra for any fluctuations). 

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/22dfe9ac0998e14b4f9418b118f37eeee29a5561_image.png)

Click “No” for 3d print

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/cd0755158d34ae939d044a3d350e0ca6c4cb6ea7_image.png)

Upload your JLCPCB screenshot from earlier

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/0aaa8f8f94dab1567dfdaff06ca5ac755b07f131_image.png)

Check your project…. and ship!

![](https://hc-cdn.hel1.your-objectstorage.com/s/v3/9306e1f8bb9e33f20e757051d90f47fe1f8035e0_image.png)

You may need to verify your Hack Club identity if you have not already.

You are done!

You should wait for  a reviewer to approve your project! Once it is approved, you can complete the checkout on JLCPCB (making sure to use Global Standard Direct), and your kit/soldering iron will be sent to you! 

While you wait….

Check out more Blueprint projects on [https://blueprint.hackclub.com/explore](https://blueprint.hackclub.com/explore)! You can also make any hardware project you want on Blueprint, and get up to $400 to make it. For future Blueprint projects, you will need to make a journal throughout your development process. Again, if you have any questions, ask in #blueprint-suppport on Slack.