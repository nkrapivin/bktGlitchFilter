# bktGlitchFilter
odditica's bktGlitch GameMaker asset, as an IDE effect/filter!

# Installation

- Download this repo as a zip.
- Copy the `_filter_bktglitch` folder into `%PROGRAMDATA%\GameMakerStudio2-YOUR-CHANNEL\Cache\runtimes\runtime-YOUR-VERSION\bin\FiltersAndEffects\`

  where `YOUR-CHANNEL` might be `-Beta` if you use the Beta version, `-Dev` if you're a YoYo employee, or nothing at all if you use the release build.
  
  and `YOUR-VERSION` is your runtime version, might be something like `2.3.6.231` for release versions, something like `23.1.1.397` for Beta versions, and `9.2.1.2678` if you're a YoYo employee.

- Open your project, open any room, make a new effect layer, choose the new `bktGlitch` effect type.
- Observe the properties of said effect type, compare them to the original asset props.
- Have fun!

# Caveats,

(~~as with any thing really...~~)

- ~~Effects and filters in general only work for those who've activated a subscription~~ Not true anymore! If you still don't have filters&effects, Log out from the IDE completely and log back in, your license file should refresh. thx yoyo 💚
- If you wish to supply your own noise texture (which... you probably should), it MUST BE a power-of-two (e.g. `256x256`, the bigger the better) AND have `Separate Texture Page` enabled! This is VERY IMPORTANT and may break things if not considered!
- Due to timing issues of the `gm_pTime` uniform, I've exposed a setting called `Time multiplier`, it's not present in the original bktGlitch asset but it allows you to multiply the internal timer by a 0 to 1 factor, the default value is `1`, the original asset used `0.06`, play around with it. If you set it to 0, the time stops and everything's static.
- When you install or switch to a different runtime, you have to copy the `_filter_bktglitch` folder there as well, a bit annoying, hope it gets "fixed" in the future. (otherwise it just errors out lol)

# Credits

- [odditica](https://odditica.itch.io) for making the [original asset](https://odditica.itch.io/bktglitch)!
- cosmonaut for explaining how FX shaders work in FNA/IDE.
- best programmer juju adams (UV shenanigans...)
