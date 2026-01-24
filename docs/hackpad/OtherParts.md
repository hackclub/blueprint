# Adding in other components!

The hackpad kit comes with more than just a few keyswitches! It comes with RGB LEDs, Rotary encoders, and a fancy 128x32 OLED screen!

The Orpheuspad example I designed has examples of every single one - I would also recommend looking at other repositories for inspo!

## 4+ keys

If you're using 4+ keys, you should use [matrix wiring!](https://docs.qmk.fm/how_a_matrix_works) There's an entire section on that in the [resources](/resources) section.

The specific diode is a 1N4148 diode from onsemi. Datasheet [here](https://www.onsemi.com/download/data-sheet/pdf/1n914-d.pdf)

For the footprint, I would recommend using `Diode_THT:D_DO-35_SOD27_P7.62mm_Horizontal`. You can use longer ones if you'd like for the aesthetic, but I find this one tends to work the best when assemblin

## Rotary encoders

Rotary encoders are knobs like [these](https://www.adafruit.com/product/377) - they turn both ways

The specific one we're using is the EC11E.

You _may_ see some implementations include pull-up resistors. This is not necessary for us since we're using the RP2040 which has built-in pull up resistors!

Firmware implementation can be found here:

[QMK](https://docs.qmk.fm/features/encoders) [KMK](https://github.com/KMKfw/kmk_firmware/blob/main/docs/en/encoder.md)

## SK6812MINI-E LEDs

These are pretty self explanatory! Here's some important things to note:

Important things to note:

- Make sure your pinout

Make sure your pinout matches the following screenshot:

![screenshot of SK6812MINI E](https://hc-cdn.hel1.your-objectstorage.com/s/v3/d5155d6e864d6f10_image.png)

Notice the small notch/cut on the bottom right corner - your LEDs _will_ not work if it's in a separate orientation!

## OLED Displays

MAKE SURE YOUR PINOUT IS LIKE THE FOLLOWING:

- GND
- VCC
- SCL
- SDA

and _not_ like the following:

- VCC

Pull-up resistors are _not_ necessary! The microcontroller we're using is based on the [Raspberry Pi RP2040](https://www.raspberrypi.com/products/rp2040/), which has built-in pullup resistors on every pin - this means you don't need to manually add 10k resistors
