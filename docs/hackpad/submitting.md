# Submitting your project

Finally finished your hackpad? Nice job! Follow along and we're going to make sure you have everything necessary to *ship* your project, which includes:

- Creating a new GitHub Repository
- Structuring your project files
- Adding a README
- Filling out the submission form

## Create a new GitHub Repository
GitHub is a website that allows you to host your project files! A GitHub repository is an individual project that you can share with others

GitHub has an awesome guide on how to create & manage repositories. You can find it here: [Creating a new repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository)

Once you create a repository, make sure to clone it! Cloning a repository downloads a local copy to your computer & lets you sync it with the version on GitHub servers. GitHub also has a guide on this! You can find it here: [Cloning a repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/cloning-a-repository)

**Once you have it cloned locally, drag and drop all your project files into the folder!**

## Structuring your project design files
To publish your project, we need to make sure that the source files of our project are formatted in a way that's complete & easy to navigate.

### 1) Make sure you have everything necessary:

Before we organize anything, make sure 
- A *complete* CAD model of the assembled case in .STEP or .STP file format!
    - This should include the PCB (a blank rectangle is okay!) and all parts of the case

Additionally, make sure your project follows the requirements:
- Your design uses a through-hole Seeed XIAO RP2040 as the main MCU
- Your PCB is smaller or equal to 100mmx100mm
- Your case fits within 200x200x100mm (length / width / height)
- You have less than 16 inputs (switches, encoders, etc)
- You are using [approved parts only](/parts)
- The PCB only uses 2 layers
- Your case only has 3D printed parts, no acrylic or laser cut parts

If you have all of that, it should be ready to go!

### 2) Organize your folders
The above is a LOT of files! To make organization easy, you should create a folder for each part of your macropad:

**CAD:**
This should contain a single file containing your ENTIRE hackpad. This should be a .STEP, .STP, or .3MF file

**PCB:**
This should contain your PCB Design files. This includes the .kicad_pro, .kicad_sch, and .kicad_pcb file if you're using KiCAD!

**Firmware:**
This should contain the source files for your firmware. main.py if you're using KMK, and then several files if you're using QMK

In total, you should have 3 folders in your project folder.


## Adding a README
A README is essential to all open-source projects. It allows people to know more about you and your project without having to dig into every single 

The README is pretty flexible, but you MUST include the following parts:

- A screenshot of your overall hackpad
- A screenshot of your schematic
- A screenshot of your PCB
- A screenshot of your case and how it'll fit together
- a BOM for your parts

It'll be different for each hackpad, but good examples of what I'm looking for are:

- [Orpheuspad example](https://github.com/hackclub/hackpad/blob/main/hackpads/orpheuspad/README.md)
- [My weather staton](https://github.com/hackclub/asylum/blob/main/designs/weather_stations/dari_awesome_example/README.md)
- [Ducc's Fidget Toy](https://github.com/hackclub/hackpad/blob/main/hackpads/Duccs%20Fidget%20Toy/README.md)
- [Cyaopad](https://github.com/hackclub/hackpad/blob/main/hackpads/cyaopad/README.md)

## Sync your repository

After adding all your files, you need to sync it with the remote. 

(insert instructions)!


## Send your project for review!

Now you need to submit your project for review! To do this, head on over to the "Dashboard tab"

Next, hit "submit design!" it'll prompt you to add a github repository




### After submitting
If everything went correctly, your submission will be reviewed (and hopefully approved!) by @alexren. You'll get a reply to your #highway-pitstop post, so MAKE SURE TO MAKE ONE!

If it's approved, then you'll get:
- A hackpad kit with all the parts you need to build your hackpad.
- A $18 Card grant to buy a soldering iron, if requested.
- A $15 Card grant to buy your PCB + Get a 3D printed case from another Hack Clubber!

If it needs updates, you'll get feedback on what you need to change!

Any questions? Check out the [FAQ](/hackpad/faq)

Drop me a follow on [GitHub](https://github.com/qcoral)!