# Simple_Dialogs for Minetest entities
***version 0.1 ***
##### This mod allows you to add dialogs for npcs and other entities, controlled by an in game text file.

## License
This code is licensed under the MIT License

![](https://i.imgur.com/ErgHNQP.png)

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
## TOPICS ##

The dialog starts with a topic, a topic is any line that has an equal sign "=" in pos one.  Every dialog file must have at least one START topic.
Topics are not case sensitive, and any characters besides letters, digits, dashes, and underscores are removed.  Start, start, st art, and START will all be treated the same by simple dialogs.  This also means all equal symbols will be removed.  Every topic must start with one equal sign, I like three, I think it makes them stand out more, but it doesn't matter how many equal signs you have at the begining, as long as you have at least one, in position one.
You can also add a "weight" to a topic line if you wish, we will talk more about that later.

Following the topic will be the dialog you want the character to say.  This can be as long or as short as you wish.  Just don't start any lines with "=", ":", or ">" in position one.

## REPLIES #

After the dialog will come the replies.  Replies all start with a > sign.  Followed by a target, followed by a colon, then by the text of the reply.  The target is the dialog topic you want to go to next.

```
>name:What is your name
```

So in the above reply, the target is "name", and the display field is "What is your name"
"What is your name" will be displayed in the reply area, and if the user clicks on it, the dialog will move to the "name" topic.

There is one special target, that is "end"  That does NOT go to another dialog topic, instead it closes the formspec and ends the conversation.

## ADDING MORE TOPICS ##

Of course, every "target" in a reply must have a corresponding topic to go to.  So lets expand our dialog with another topic:

```
===Start
Shiver me timbers, but you caught me by surprise matey!
What be ye doin here?  Arrrgh!  This be no fit place for land lubbers!

>name:What is your name
>arrg:Why do pirates always say Arrrgh?
>treasure:I'm looking for treasure.  Can you tell me where the treasure is?
>rude:What's got you so cranky?  Did a beaver chew on your wooden leg?
>end:Good bye.

===name
My name be Davey Jones.  Not that it be any business of a bildge rat like you!
>bildge rat:What's a bildge rat?
>arrg:Why do pirates always say Arrrgh?
>treasure:I'm looking for treasure.  Can you tell me where the treasure is?
>rude:What's got you so cranky?  Did a beaver chew on your leg?
```

Now we have created the "Name" topic.  So, if the player clicks on "What is your name" in the start section, the dialog will move to the "name" section and display that.
You keep adding sections until every possible path through the dialog has a dialog topic for it.
It is very important that you do NOT have reply targets that do not actually match up with a dialog topic.  If you do, your dialog will not work.


## WEIGHTED TOPICS ##

It is possible to have multiple topics with the same topic name.  When you do that, simple_dialogs will chose randomly which topic is shown.
Example:

```
===Start
I am the mystic of the temple.  Do you have a question?
>dragon:Where does the dragon live and how can I defeat him?
>end:No thank you, I'm just looking around.

===Dragon
You do not appear wise enough to handle the answer to that question.
>start:I really need to know the answer though!
>end:Oh well, good bye then!

===Dragon
You ask the wrong questions.  Go and gain more wisdom first, perhaps study with the master of trees in the crystal forest, then come and ask again.
>start:I dont have TIME to go find another mystic, I need to know now!
>end:I will go and seek for more knowledge then.

===Dragon
Hmmm, I think you are foolish to ask this question, but wisdom comes through hard trials.
The dragon lives on the black mountain in the land of the elves.  As for how to defeat him?  Ask the elves.
>end:Thank you!
```

So in the above dialog, if the player clicks on "Where does the dragon live and how can I defeat him?"  He will get one of three possible responses randomly.  Each just as likely to come up as the others.

BUT, what if you wanted to change the odds of which topic shows up?  Well, that is actually quite easy to do.  You just add a weight (in parenthesis) after the topic name.  like below:

```
===Dragon(4)
You do not appear wise enough to handle the answer to that question.
>start:I really need to know the answer though!
>end:Oh well, good bye then!

===Dragon(3)
You ask the wrong questions.  Go and gain more wisdom first, perhaps study with the master of trees in the crystal forest, then come and ask again.
>start:I dont have TIME to go find another mystic, I need to know now!
>end:I will go and seek for more knowledge then.

===Dragon(1)
Hmmm, I think you are foolish to ask this question, but wisdom comes through hard trials.
The dragon lives on the black mountain in the land of the elves.  As for how to defeat him?  Ask the elves.
>end:Thank you!
```

so, in the above example, the first "dragon" topic has a weight of 4, the second 3, and the last one 1.  When going to the dragon topic, simple_dialogs will roll a random number between 1 and 8 (4+3+1=8) If the number comes up 1-4, the first Dragon topic will show.  If it comes up 5-7, the second topic will show.  And only if the number comes up 8 will the last topic show.


## VARIABLES ##

You can use variables in your dialogs.  Variables should be enclosed in at sign brackets, like this:
@[playername]@
Variables are not case sensitive, and all characters other than letters, numbers, underscore, dash, and period are stripped out.
So @[PlayerName]@,  @[playername]@, and @[Player Name]@ are all the same.

The variable playername is set by simple_dialogs and will always be available.  Other variables may be set by the entity mod using simple_dialogs.  Such as @[NPCNAME]@ or @[Owner]@
And you can set your own variables (more on that later)

An example of using a variable in a dialog:

```
===Start
Hello @[playername]@.  I am the wizard Fladnag.  I forsaw that you would come to see me today.
>tower:Tell me about your tower please?
>spell:Will you cast a spell for me?
>end:I prefer not to meddle in the affairs of wizards, for they are subtle and quick to anger.
```

When the above dialog is displayed @[playername]@ will be replaced by the actual playername.

## COMMANDS ##

For more advanced simple_dialogs you can add commands.  commands start with a : in position one.  Commands can be anywhere within the topic that makes sense to you.  I usually put them between the dialog and the replies.  They will be executed in the order they appear, as soon as the topic is displayed.
Commands that are currently supported are

### SET ###

:set variablename=value

This lets you set your own variables.  Some examples of the command in use:

:set angry=Y
:set friendlist=|Joe|SallyMiner|BigBuilder|
:set myname=@[npcname]@

Note that we enclosed npcname in at brackets, and we did NOT enclose myname in at brackets.  That is because we want the VALUE of the variable npcname to be placed into the variable myname.  If we had said :set myname=npcname then myname would be equal to the string "npcname"

An important note about set and compound variables:
In a multiplayer game, remember that the variables for an npc are global.  If you want to create a variable that is player specific, create a compound variable with the playername as the first part.  For example:

:set @[playername]@.trust=High

sets a variable "trust" that would be DIFFERENT for every player.  For example, if the players name is singleplayer, the actual variable set would be singleplayer.trust
To access the content of that variable you would use this format:
@[@[playername]@.trust]@  (it will process the inner brackets first and populate the playername, then process the outerbrackets and get the stored variable)


### GOTO ###

:goto topic

This is very simple, it just allows you to go to another topic.  This means that if you have a :GOTO command in a topic, that topic will NEVER be seen, because the commands are always executed first and the goto command will move to another topic.
You can only nest gotos 3 levels deep, so there is no risk of getting stuck in a goto loop.
While there ARE reasons to use a goto command directly in a dialog, it is most often used in conjunction with the :if command.

### HOOK ###

Hook commands allow you to do things that are outside the purview of simple_dialogs, but have been allowed and coded by the entity mod.  For example, a hook might allow an npc to teleport you:

:HOOK Teleport 5000,3,2132

or a hook might allow the npc to trade:

:HOOK TRADE

But the implementation of hooks is entirely up to the entity mod that is using simple_dialogs.  (As is the security around them!)

### IF ###

:if (cond in parents) then cmnd

The condition for if has to be enclosed in parenthesis.  the cmnd that follows the "THEN" can be any cmnd simple_dialogs can process.  SET, GOTO, HOOK, or even another if, although there is no logical reason to do that.

Examples:

:if (@[hunger]@>3) then goto feedme
:if (@[playername]@==@[owner]@) then set greeting=Hello Boss!
:if ( (@[angry]@==N) and (isInList(FriendList,@[playername]@)) ) then set friendstatus=You are my very best friend!

You probably noticed the function isInList() in there, more on that later.
Some important things to remember about :If
you MUST include the command name to be executed after the "THEN".
then greeting=Hello Boss!
will NOT work.  It has to be
then set greeting=Hello Boss!
And do not forget to enclose the if condition in parenthesis.  You can nest parenthesis as deeply as you wish, but the entire condition must be enclosed in parenthesis.

Note that there is no ELSE functionality.  We may add that in the future.


## FUNCTIONS ##


Several functions are available for you use.  These can be used in commands OR directly within a dialog

### FIRST A NOTE ON LISTS ###
functions add, rmv, isInList, and notInList all work on list that contain strings surrounded by vertical bars.
So, for example a list of pets might look like
|dog|cat|mouse|parakeet|
As long as you are using the above mentioned functions to deal with the list, you don't need to worry about the vertical bars.  They will be added for you.

### ADD() ###

add(variablename,stringtoadd)

Adds a new element to a list, if that element is not already in the list.

Examples:

:set FriendList=add(FriendList,@[playername]@)
:set petlist=add(petlist,alligator)

### RMV() ###

rmv(variablename,stringtoremove)

Removes an element from a list

Examples:

:set FriendList=rmv(FriendList,@[playername]@)
:set petlist=rmv(petlist,mouse)

### isInList() ###

isInList(variablename,stringToLookFor)

Returns true if stringToLookFor is contained in the list in variablename.  (surrounded by vertical bars)

Examples:

:if (isInList(friendlist,@[playername]@)) then goto friendly
:if (isInList(petlist,hippo)) then set petresponse=And you can see my friendly hippo over in the mud pond.

### notInList ###

notInList(variablename,stringToLookFor)

this is just the opposite of isInList

Examples:

:if (isNotInList(friendlist,@[playername]@)) then goto enemy
:if (isNotInList(petlist,hippo)) then set petresponse=Do you have a hippo?  I need one.

### isSet() ###

isSet(variablename)

This returns true if the variable variablename exists for this npc and is not empty.

Example:

if (isSet(npcname)) then set myname=@[npcname]@

### isNotSet() ###

isNotSet(variablename)

This is the opposite of isSet and returns true if the variable variablename does NOT exist for this npc, or is empty.

Example:

if (isNotSet(npcname)) then set myname=Guido

### yesno() ###

yesno(input)

When input is "0" or "N", this will return "No"
When input is "1" or "Y", this will return "Yes"
It is useful for displaying function results or variables directly in a dialog.  Do NOT use this in an If statement, since that expects "1" or "0"

Examples:

Am I angry? yesno(@[angry]@)
Are you in my friendlist? YesNo(isinlist(FriendList,@[playername]@))

### calc() ###

calc(stringOfMath)

This function does math on input strings.

Examples:

:set value=calc(2*(12/4)+1)
:set buyat=calc(@[gold]@*2)

### WARNING: Variables by name or reference ###

Be careful about referencing variables to be clear whether you want the variable name (literal) or the variable value (in at brackets)
So, for example:
:set myname=Long John Silver
will set the variable myname to the value "Long John Silver"
but this:
:set myname=Long John Silver
:set @[myname]@=Calico Jack
Will first replace myname with whatever value is in there.  Which is "Long John Silver"
And THEN execute the set command, so in the end it would actually be doing:
:set LONGJOHNSILVER=Calico Jack

When you want to reference a variable name, do not use at brackets.
When you want to replace a variable with it's value, use at brackets.

---
## Integrating simple_dialogs with an entity mod ##

simple_dialogs is NOT a stand alone entity mod.  It just does the dialogs.  It needs to be integrated into an existing entity mod.  
So, how do we do that?

Lets start by detecting whether simple_dialogs exists (the entity mod should run fine without simple_dialogs)
To do that, add the following near the top of your entity mod:

```
local useDialogs="N"
if (minetest.get_modpath("simple_dialogs")) then
	useDialogs="Y"
end
```

We will be adding some more here later, but this is enough for now.  

### Add simple_dialog controls to the NPC right click menu ###

There are two simple_dialogs right click menus.  One for the simple_dialog controls, where the owner can create and test a dialog.  And another for non-owners where we actually display the dialog conversation to another player.  Both are pretty easy to add.  But there are two ways to do it, depending on whether your entity already has a right click menu for owners or not.

#### If the entity mod does not already have a right click menu for owners ####

Just add the simple_dialogs right click menu, something like this:

```
  on_rightclick = function(self, clicker)
    self.id=set_npc_id(self)  --you must set self.id to some kind of unique string for simple_dialogs to work
...
  -- if simple_dialogs is present, then show right click menus
  if useDialogs=="Y" then 
    if self.owner and self.owner == name then
      simple_dialogs.show_dialog_controls_formspec(name,self)
    else simple_dialogs.show_dialog_formspec(name,self)
    end --if self.owner
  end --if useDialogs
```

simple_dialogs will take care of the register_on_player_receive_fields for you.

#### if the entity mod already has a right click menu  for owners ####

Then you just want to add the simple_dialogs contols to your already existing formspec.  And this is actually pretty easy to do:

Here is an example of an existing right click npc owner menu that has simple_dialogs controls added to it:

<pre>
function get_npc_controls_formspec(name,self)
	...
	-- Make npc controls formspec
	local text = "NPC Controls"
	local size="size[3.75,2.8]"
	<b>if useDialogs=="Y" then size="size[15,10]" end</b>
	local formspec = {
		size,
		"label[0.375,0.5;", minetest.formspec_escape(text), "]",
		"dropdown[0.375,1.25; 3,0.6;ordermode;wander,stand,follow;",currentorderidx,"]",
		"button[0.375,2;3,0.8;exit;Exit]"
		}
	<b>if useDialogs=="Y" then simple_dialogs.add_dialog_control_to_formspec(name,self,formspec,0.375,3.4) end</b>
	table.concat(formspec, "")
	context[name]=npcId --store the npc id in local context so we can use it when the form is returned.  (cant store self)
	return table.concat(formspec, "")
end
</pre>

Note that only two lines had to be added here.

