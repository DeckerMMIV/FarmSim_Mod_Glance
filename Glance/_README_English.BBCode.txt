[b]Glance (v2.5.x)[/b]

[i]Remember to check the support topic for any additional information regarding this mod[/i]

[b][u]Changelog[/u][/b]
2.5.2
- Support for 'backporting' to FS2013.


[b][u]Mod description[/u][/b]

'Glance' is an attempt at making a more configurable and less screen occupying 'notification-and-status utility', similar to the mods; 'Inspector' and 'LoadStatus'.

The features of 'Glance' are:

- By default only visible when the Helpbox is turned off (default key: F1)
- Using columns, which should be easier to read
- Can be dynamically configured ...
-- ... to show only notifications you care about
-- ... with regards to what font-size and colors you want to use
-- ... how and which columns should be displayed in sequence
- Will show when a hired-worker has finished
- Displays the vehicle's location in the world and when within a map designated field-boundary
- Speed of the vehicle, and if it is being blocked by something (like a tree, fence or car)
- Animal husbandry; low productivity, full pallet, eggs available and more...
- Greenhouse placeables; low fill levels.


[b][u]How to use it[/u][/b]

First you must [u]turn off[/u] the Helpbox (default key: F1), to be able to see the Glance notifications.

The first time you ever run Glance, it will create a default configuration-file called [b]Glance_Config.XML[/b] in the MODS folder.

Due to the modifiable configuration - which maybe for some seem complex and confusing - there will in the support-topic for this mod, later be given instructions and examples on how/what to modify.

The configuration-file will be (re)loaded every time you leave the in-game menu (a.k.a. ESC-menu, ESC-screen.) So it is possible to pause the game, ALT-TAB out of FS15, then edit Glance_Config.XML, ALT-TAB back into FS15 to continue playing and see if the changes for Glance are acceptable.

[u]Switching it on/off[/u]

To see notifications from Glance, you have to switch off the Helpbox (default key: [b]F1[/b]), and have set a 'minimum notification level' that has a lower-or-equal value than the notifications you care about.

To hide Glance, either switch on the Helpbox again, or set the 'minimum notification level' to show less (i.e. a value higher than any of the notifications) using the action-key (default: [b]LEFT ALT[/b] + [b]L[/b]).

If you want to always have Glance visible, disregarding the F1-Helpbox, you need to edit the Glance_Config.XML file, and set the value for 'ignoreHelpboxVisibility' to 'true'. Then also set the 'positionXY' value, so Glance won't overlap the F1-Helpbox.

[b][u]Controls[/u][/b]

The action-keys, which can be changed in the Options - Controls screen, are these by which you can in-game instantly set the 'minimum notification level':

[b]LEFT ALT[/b] + [b]M[/b] = Glance:More Notify - i.e. show more notifications, possibly showing everything.
[b]LEFT ALT[/b] + [b]L[/b] = Glance:Less Notify - i.e. show less notifications, possibly showing nothing at all.

And just to clarify once again:

[b]F1[/b] = Toggle helpbox off to show Glance ([i]if ignoreHelpboxVisibility="false" in config-file.[/i])


[b][u]Restrictions[/u][/b]

This mod's script files MAY NOT, SHALL NOT and MUST NOT be embedded in any other mod nor any map-mod! - However it is accepted if this mod is packed into a mod-pack archive, when this mod's original ZIP-file and hash-value is kept intact.

Please do NOT upload this mod to any other hosting site - I can do that myself, when needed!

Keep the original download link!


[b][u]Problems or bugs?[/u][/b]

If you encounter problems or bugs using this mod, please use the support-thread at http://fs-uk.com - Find the mod (and correct version) in the mods section, in category 'Other - Game Scripts'.

Known bugs/problems:
- Detection of Marhu/TMT's SchweineZucht mod is not 100% accurate, if there are more than one map-mod in the MODS folder which have it embedded.
- Have not been extensively tested in multiplayer.


Credits:
Script: Decker_MMIV
Hungarian translations by: pokers
Russian translations by: Gonimy_Vetrom
German translations by: SchorschiBW & JakobT
Some Polish translations by: ja_pizgam    
