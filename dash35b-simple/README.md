# M1PS Knight: Maxim 120 + Dash35B

This is a _**HIGHLY**_ customized package for my specific bike and controller.

There's a lot of code derivation from the `Dash35B` and `vl_bike_39p` packages, but this setup is not compatible with those.

Additionally, since I just work locally off this code, I don't have it properly setup to build packages from the `vesc_tool` at this time. Instead, I open the main lisp files and directly upload them to the proper component:

```
main-stm.lisp  --> maxim
main-esp.lisp  --> esp on the maxim (str365.io)
main-disp.lisp --> the dash35 (vdisp)
```

One other big notable item is that this setup uses hall sensing, but takes hall 1/2/3 signals via the controller's SWCLK/SWDIO/PPM pins because an accident fried my hall array.
