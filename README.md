# Simple_Dialogs for Minetest entities
***version 0.1 ***
##### This mod allows you to add dialogs for npcs and other entities, controlled by an in game text file.

## License
This code is licensed under the MIT License

![](https://i.imgur.com/bhZ9Hjw.png)

Simple Dialogs is NOT a stand alone entity mod, rather it is an add on that is designed to be (rather easily) integrated with other entity mods.

Simple Dialogs allows you to create conversation trees (dialogs) for any entity.  And those dialogs are created using only a simple in game text file.  No API or LUA programming required.

![](https://i.imgur.com/MPfJg92.png)

This means that any player who has ownership of an npc can create their own customized dialogs for that npc.  A player building a shop can write a dialog for the npc shop keeper.  A player who builds a huge castle can craft their own custom dialog for the guard at the gate to tell people about the castle.  AND, since the control mechanisim is just text, the players have no direct lua access, avoiding some security risks.

Of course, dialogs can be used by the server owner/game designer as well.  They can create individually customized dialogs for npcs in the same manner that any player can.  BUT, they can also add text file containing a dialog to the game folder, and have it automatically uploaded to specific kinds of entities whenever they are spawned.

So, how does all of this work?  The heart and key to simple dialogs is the dialog control text.  Which, at it's simplist, looks something like this:

```plaintext
===Start
Shiver me timbers, but you caught me by surprise matey!
What be ye doin here?  Arrrgh!  This be no fit place for land lubbers!
>name:What is your name
>arrg:Why do pirates always say Arrrgh?
>treasure:I'm looking for treasure.  Can you tell me where the treasure is?
>rude:What's got you so cranky?  Did a beaver chew on your wooden leg?
```

```text
===Start2
Shiver me timbers, but you caught me by surprise matey!
What be ye doin here?  Arrrgh!  This be no fit place for land lubbers!
>name:What is your name
>arrg:Why do pirates always say Arrrgh?
>treasure:I'm looking for treasure.  Can you tell me where the treasure is?
>rude:What's got you so cranky?  Did a beaver chew on your wooden leg?
```

```
===Start3
Shiver me timbers, but you caught me by surprise matey!
What be ye doin here?  Arrrgh!  This be no fit place for land lubbers!
>name:What is your name
>arrg:Why do pirates always say Arrrgh?
>treasure:I'm looking for treasure.  Can you tell me where the treasure is?
>rude:What's got you so cranky?  Did a beaver chew on your wooden leg?
```