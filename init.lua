simple_dialogs = { }

local S = simple_dialogs.intllib  --TODO: ensure integration with intllib is working properly, I dont think it is now

-- simple dialogs by Kilarin

local contextctr = {}
local contextdlg = {}

local chars = {}
chars.topic="="
chars.reply=">"
chars.varopen="@["
chars.varclose="]@"

local max_goto_depth=3 --TODO:move these to config

local helpfile=minetest.get_modpath("simple_dialogs").."/simple_dialogs_help.txt"

local registered_varloaders={}
local registered_hooks={}




--##################################################################################
--# Translations                                                                   #
--##################################################################################

-- Check for translation method
local S
if minetest.get_translator ~= nil then
	S = minetest.get_translator("simple_dialogs") -- 5.x translation function
else
	if minetest.get_modpath("intllib") then
		dofile(minetest.get_modpath("intllib") .. "/init.lua")
		if intllib.make_gettext_pair then
			gettext, ngettext = intllib.make_gettext_pair() -- new gettext method
		else
			gettext = intllib.Getter() -- old text file method
		end
		S = gettext
	else -- boilerplate function
		S = function(str, ...)
			local args = {...}
			return str:gsub("@%d+", function(match)
				return args[tonumber(match:sub(2))]
			end)
		end
	end
end
simple_dialogs.intllib = S


--##################################################################################
--# Methods used when integrating simple_dialogs with an entity mod                #
--##################################################################################

--this should be used by your entity mod to load variables that you want to be available for dialogs
--example:
--		simple_dialogs.register_varloader(function(npcself,playername)
--		simple_dialogs.load_dialog_var(npcself,"NPCNAME",npcself.nametopic)
--		simple_dialogs.load_dialog_var(npcself,"STATE",npcself.state)
--		simple_dialogs.load_dialog_var(npcself,"FOOD",npcself.food)
--		simple_dialogs.load_dialog_var(npcself,"HEALTH",npcself.food)
--		simple_dialogs.load_dialog_var(npcself,"owner",npcself.owner)
--	end)--register_on_leaveplayer
function simple_dialogs.register_varloader(func)
	registered_varloaders[#registered_varloaders+1]=func
end


--register hook
function simple_dialogs.register_hook(func)
	registered_hooks[#registered_hooks+1]=func
end



----------------------------------------------------------------------------------------
-- the dialog control formspec is where an owner can create a dialog for an npc       --
-- NOT to be confused with the actual dialog formspec! where someone talks to the npc --
----------------------------------------------------------------------------------------


--this creates and displays an independent dialog control formspec
--dont use this if you are trying to integrate dialog controls with another formspec
function simple_dialogs.show_dialog_controls_formspec(playername,npcself)
	contextctr[playername]=simple_dialogs.set_npc_id(npcself) --store the npc id in local context so we can use it when the form is returned.  (cant store self)
	-- Make blank formspec
	local formspec = {
		"formspec_version[4]",
		"size[15,7]", 
		}
	--add the dialog controls to the above blank formspec
	simple_dialogs.add_dialog_control_to_formspec(playername,npcself,formspec,0.375,0.375)
	formspec=table.concat(formspec, "")
	minetest.show_formspec(playername, "simple_dialogs:dialog_controls", formspec )
end --show_dialog_controls_formspec


--this adds the dialog controls to an existing formspec, so if you already have a control formspec
--for the npc, then use this to add the dialog controls to that formspec
--if you use then, then you will need to add process_simple_dialog_control_fields to the 
--register_on_player_receive_fields function for the formspec to process the buttons when pushed
--I THINK this should work if your formspec is a string instead of a table, but I haven't tested that yet.
--TODO: allow control of width?
function simple_dialogs.add_dialog_control_to_formspec(playername,npcself,formspec,x,y)
	local dialogtext=""
	if npcself.dialog and npcself.dialog.text then dialogtext=npcself.dialog.text end
	local x2=x
	local y2=y+5
	local x3=x2+2
	local x4=x3+2
	local formspecstr=""
	local passedInString="NO"
	if type(formspec)=="string" then
		formspecstr=formspec
		formspec={}
		passedInString="YES"
	end
	formspec[#formspec+1]="textarea["..x..","..y..";14,4.8;dialog;"..S("Dialog")..";"..minetest.formspec_escape(dialogtext).."]"
	formspec[#formspec+1]="button["..x2..","..y2..";1.5,0.8;dialoghelp;"..S("Dialog Help").."]"
	formspec[#formspec+1]="button["..x3..","..y2..";1.5,0.8;save;"..S("Save").."]"
	formspec[#formspec+1]="button["..x4..","..y2..";3,0.8;saveandtest;"..S("Save & Test").."]"
	if passedInString=="YES" then
		return formspecstr..table.concat(formspec)
	end
end --add_dialog_control_to_formspec


--if you used add_dialog_control_to_formspec to add the dialog controls to an existing formspec,
--then use THIS in your register_on_player_receive_fields function
--it will process the save, saveandtest and dialog help buttons.
function simple_dialogs.process_simple_dialog_control_fields(playername,npcself,fields)
	--minetest.log("simple_dialogs->psdcf fields="..dump(fields))
	if fields["save"] or fields["saveandtest"] then
		simple_dialogs.load_dialog_from_string(npcself,fields["dialog"])
	end --save or saveandtest
	if fields["saveandtest"] then
		simple_dialogs.show_dialog_formspec(playername,npcself,"START")
	elseif fields["dialoghelp"] then
		--minetest.log("simple_dialogs->psdcf help")
		simple_dialogs.dialog_help(playername)
	end
end --process_simple_dialog_control_fields


--this function lets you load a dialog for an npc from a file.  So you can store predetermined dialogs
--as text files and load them for special npc or types of npcs (pirates, villagers, blacksmiths, guards, etc)
--we take modname as a parameter because you might have dialogs in a different mod that uses this mod
function simple_dialogs.load_dialog_from_file(npcself,modname,dialogfilename)
	local file = io.open(minetest.get_modpath(modname).."/"..dialogfilename)
	if file then
		local dialogstr=file:read("*all")
		file.close()
		simple_dialogs.load_dialog_from_string(npcself,dialogstr)
	end
end --load_dialog_from_file


------------------------------------------------------------------------
-- the dialog formspec is the formspec where someone talks to the npc --
------------------------------------------------------------------------


--this will be used to display the actual dialog to a player interacting with the npc
--normally displayed to someone who is NOT the entity owner
--call with topic=START for starting a dialog, or with no topic and it will default to start.
function simple_dialogs.show_dialog_formspec(playername,npcself,topic)
	--only show the dialog formspec if there is a dialog
	if npcself and npcself.dialog and npcself.dialog.dlg and npcself.dialog.text and npcself.dialog.text~="" then 
		if not topic then topic="START" end
		contextdlg[playername]={}
		contextdlg[playername].npcId=simple_dialogs.set_npc_id(npcself) --store the npc id in local context so we can use it when the form is returned.  (cant store self)
		local formspec={
			"formspec_version[4]",
			"size[28,15]", 
			"position[0.05,0.05]",
			"anchor[0,0]",
			"no_prepend[]",        --must be present for below transparent setting to work
			"bgcolor[;neither;]",  --make the formspec background transparent
			"box[0.370,0.4;9.6,8.4;#222222FF]", --draws a box background behind our text area
			simple_dialogs.dialog_to_formspec(playername,npcself,topic)
		}
		formspec=table.concat(formspec,"")
		minetest.show_formspec(playername,"simple_dialogs:dialog",formspec)
	end
end --show_dialog_formspec



--##################################################################################
--# convert string input into Dialog table                                         #
--##################################################################################


--[[
this is where the whole dialog structure is created.

A typical dialog looks like this:
===Start
Hello, welcome to Caldons tower of fun!
>caldon:Who is Caldon?
>name:Who are you?
>directions:How do I get into the tower?

topics start with = in pos 1 and can look like ===Start   or  =Treasure(5) (any number of ='s are ok as long as there is 1 in pos 1)
a number in parenthesis after the topic name is a "weight" for that entry, which is only used when you have multiple topics
with the same name and effects how frequently each is chosen.
weight is optional and defaults to 1.
you can have multiple topics with the same name, each gets a number, "subtopic", 
when you reference that topic one of the multiple results will be chosen randomly
topics can only contain letters, numbers, underscores, and dashes, all other characters are stripped (letters are uppercased)

After the topic is the "say", this is what the npc says for this topic.

Replies start with > in position 1, and are followed by a target and a colon.  The target is the "topic" this replay takes you to.
the reply follows the colon

You can also add commands, command start with a : in position 1
possible commands are:
:set varname=value
:if (a==b) then set varname=value
:if ( ((a==b) and (c>d)) or (e<=f)) then set varname=value

note that :if requires that the condition be in parenthesis.

The final structure of the dialog table will look like this:
npcself.dialog.vars                        (variable values for this npc)
npcself.dialog.text                        (the unprocessed dialog string)
npcself.dialog.
dlg[topic][subtopic].weight                    (the weight for this subtopic when chosen by random)
dlg[topic][subtopic].say                       (the text of the dialog that the npc says)
dlg[topic][subtopic].reply[replycount].target  (what topic this reply will go to)
dlg[topic][subtopic].reply[replycount].text    (the text of the reply)
dlg[topic][subtopic].cmnd[cmndcount].cmnd      (SET or IF)

dlg[topic][subtopic].cmnd[cmndcount].cmnd=SET
dlg[topic][subtopic].cmnd[cmndcount].varname   (variable name to be set)
dlg[topic][subtopic].cmnd[cmndcount].varval    (value to set the variable to)

dlg[topic][subtopic].cmnd[cmndcount].cmnd=IF
dlg[topic][subtopic].cmnd[cmndcount].condstr   (the condition string, a==b etc, must be in parens)
dlg[topic][subtopic].cmnd[cmndcount].ifcmnd.cmnd  (SET for now, GOTO later?, entire structure of subcommand will be here)

dlg[topic][subtopic].gototopic.topic               (used by goto to indicate which topic to goto)
dlg[topic][subtopic].gototopic.count             (goto depth count, used to ensure you can not get into an infinite goto loop)

--]]
function simple_dialogs.load_dialog_from_string(npcself,dialogstr)
	npcself.dialog = {}
	npcself.dialog.dlg={}
	npcself.dialog.vars = {}
	--local dlg=npcself.dialog.dlg  --shortcut to make things more readable
	--this function was too long and complicated, so I broke it up into sections
	--the table wk is passed to each sub function as a common work area
	local wk={}  
	wk.topic = ""
	wk.subtopic=1
	wk.weight=1
	wk.dlg=npcself.dialog.dlg
	
	--loop through each line in the string (including blank lines) 
	for line in (dialogstr..'\n'):gmatch'(.-)\r?\n' do 
		--minetest.log("simple_dialogs->ldfs line="..wk.line)
		wk.line=line
		local firstchar=string.sub(wk.line,1,1)
		--minetest.log("simple_dialogs->ldfs firstchar="..firstchar.." #firstchar="..#firstchar)
		if firstchar == chars.topic then  --we found a topic, process it
			simple_dialogs.load_dialog_topic(wk)
		elseif firstchar == chars.reply and wk.topic ~= "" then  --we found a reply, process it
			simple_dialogs.load_dialog_reply(wk)
		elseif firstchar==":" and #wk.line>1 then --commands
			--minetest.log("simple_dialogs->ldfs : line="..wk.line)
			local newcmnd=simple_dialogs.load_dialog_cmnd(string.sub(wk.line,2))
			if newcmnd then
				local cmndcount=#wk.dlg[wk.topic][wk.subtopic].cmnd+1
				wk.dlg[wk.topic][wk.subtopic].cmnd[cmndcount]=newcmnd 
			end --if newcmnd
		--we check that a topic is set to avoid errors, just in case they put text before the first topic
		--we check that replycount=0 because we are going to ignore any text between the replies and the next topic
		elseif wk.topic~="" and #wk.dlg[wk.topic][wk.subtopic].reply==0 then  --we found a dialog line, process it
			wk.dlg[wk.topic][wk.subtopic].say=wk.dlg[wk.topic][wk.subtopic].say..wk.line.."\n"
		end
	end --for line in dialog
	--now double check that every entry has at least 1 reply
	for t,v in pairs(wk.dlg) do
		for st=1,#wk.dlg[t],1 do
			--I could also FORCE an end topic onto every replylist that didn't have one. consider that in the future.
			if not wk.dlg[t][st].reply or not wk.dlg[t][st].reply[1] then
				wk.dlg[t][st].reply={}
				wk.dlg[t][st].reply[1]={}
				wk.dlg[t][st].reply[1].target="END"
				wk.dlg[t][st].reply[1].text="END"
			end --if
		end --for st
	end --for t
	npcself.dialog.text=dialogstr
	--minetest.log("simple_dialogs->ldfs end dlg="..dump(wk.dlg))
end --load_dialog_from_string


--this function is used to load a topic into the dialog table in load_dialog_from_string 
--wk is our working area variables.
--topics will be in the form of
--=topicname(weight)
--weight is optional, and there can be any number of equal signs
function simple_dialogs.load_dialog_topic(wk)
	wk.topic=wk.line  --this might still include weight, = signs will be stripped off when we filter
	--get the weight from parenthesis
	wk.weight=1
	local i, j = string.find(wk.line,"%(") --look for open parenthesis
	local k, l = string.find(wk.line,"%)") --look for close parenthesis
	--if ( and ) both exist, and the ) is after the (
	if i and i>0 and k and k>i then --found weight
		wk.topic=string.sub(wk.line,1,i-1) --cut the (weight) out of the topicname
		local w=string.sub(wk.line,i+1,k-1) --get the number in parenthesis (weight)
		wk.weight=tonumber(w)
		if wk.weight==nil or wk.weight<1 then wk.weight=1 end
		--minetest.log("simple_dialogs->ldt line="..wk.line.." topic="..wk.topic.." i="..i.." k="..k.." w="..w)
	end
	--strip topic down to only allowed characters
	wk.topic=simple_dialogs.topic_filter(wk.topic) --this also strips all leading = signs
	wk.subtopic=1
	if wk.dlg[wk.topic] then --existing topic
		--minetest.log("simple_dialogs->ldt topic="..wk.topic.." subtopic="..wk.subtopic)
		wk.subtopic=#(wk.dlg[wk.topic])+1
		wk.weight=wk.dlg[wk.topic][wk.subtopic-1].weight+wk.weight  --add previous weight to current weight
		--weight is always the maximum number rolled that returns this subtopic
		--TODO: further notes on weight?  here or in readme?
	else --if this is a new topic
		wk.dlg[wk.topic]={} 
	end
	wk.dlg[wk.topic][wk.subtopic]={}
	wk.dlg[wk.topic][wk.subtopic].say=""
	wk.dlg[wk.topic][wk.subtopic].weight=wk.weight
	wk.dlg[wk.topic][wk.subtopic].reply={}
	wk.dlg[wk.topic][wk.subtopic].cmnd={}
end --load_dialog_topic


--this function is used to load a REPLY into the dialog table in load_dialog_from_string
--wk is our working area variables.
--replies will be in the form of
-->target:replytext
--target is the topic we will go to if this reply is clicked
--replytext is the text that will be shown for the reply
function simple_dialogs.load_dialog_reply(wk)
	--split into target and reply
	local i, j = string.find(wk.line,":")
	if i==nil then 
		i=string.len(wk.line)+1 --if they left out the colon, treat the whole line as the topic
	end
	local replycount=#wk.dlg[wk.topic][wk.subtopic].reply+1
	wk.dlg[wk.topic][wk.subtopic].reply[replycount]={}
	--TODO: use variables for targets, filter later, not here?
	wk.dlg[wk.topic][wk.subtopic].reply[replycount].target=simple_dialogs.topic_filter(string.sub(wk.line,2,i-1))
	--the match below removes leading spaces
	wk.dlg[wk.topic][wk.subtopic].reply[replycount].text=string.match(string.sub(wk.line,i+1),'^%s*(.*)')
	if wk.dlg[wk.topic][wk.subtopic].reply[replycount].text=="" then
		wk.dlg[wk.topic][wk.subtopic].reply[replycount].text=string.sub(wk.line,2,i-1)
	end
end --load_dialog_reply



--this will create a command from the dialog input string, ready to be loaded into the dialog input table.
--it is called by both load_dialog_from_string and also by load_dialog_cmnd_if (to load ifcmnd)
--do not pass in the leading colon
function simple_dialogs.load_dialog_cmnd(line)
	--minetest.log("simple_dialogs->ldc line="..line)
	local newcmnd=nil
	local spc=string.find(line," ",1)
	if spc then
		local cmndname=string.upper(string.sub(line,1,spc-1))
		local str=simple_dialogs.trim(string.sub(line,spc+1)) --rest of line without the command
		if not str then str="" end
		--minetest.log("simple_dialogs->ldc cmnd="..cmndname.." str="..str)
		if cmndname=="SET" then
			newcmnd=simple_dialogs.load_dialog_cmnd_set(str)
		elseif cmndname=="IF" then
			newcmnd=simple_dialogs.load_dialog_cmnd_if(str)
		elseif cmndname=="GOTO" then
			newcmnd={}
			newcmnd.cmnd="GOTO"
			newcmnd.topic=simple_dialogs.topic_filter(str)
		elseif cmndname=="HOOK" then
			--:hook teleport -500,3,-80
			newcmnd={}
			newcmnd.cmnd="HOOK"
			local spc2=string.find(str," ",1)
			--minetest.log("simple_dialogs->ldc hook str="..str.." spc2="..spc2)
			if spc2 then
				newcmnd.func=string.upper(string.sub(str,1,spc2-1))
				newcmnd.str=simple_dialogs.trim(string.sub(str,spc2+1))
				newcmnd.parm={}
				local c=0
				--now break the rest of the command into parms, if possible
				for word in string.gmatch(newcmnd.str, '([^,]+)') do
					c=c+1
					newcmnd.parm[c]=word
				end
			newcmnd.parmcount=c
			end --if spc2
			--minetest.log("simple_dialogs->ldc hook="..dump(newcmnd))
		end --if cmndname
	end --if spc
	--minetest.log("simple_dialogs->ldc newcmnd="..dump(newcmnd))
	return newcmnd
end --load_dialog_cmnd


--this function is used to load a SET cmnd into the dialog table in load_dialog_from_string and in load_dialog_if
--str is the string after the :set and should be in the format of varname=varval
--returns a cmnd in format of:
--cmnd.cmnd="SET"
--cmnd.varname=variablename
--cmnd.varval=value to set variable to
function simple_dialogs.load_dialog_cmnd_set(str)  
	local cmnd=nil
	local eq=string.find(str,"=")
	if eq then
		--minetest.log("simple_dialogs->ldcs eq")
		local varname=string.sub(str,1,eq-1)
		local varval=string.sub(str,eq+1)
		--minetest.log("simple_dialogs->ldcs varname="..varname.." varval="..varval)
		if varval then
			cmnd={}
			cmnd.cmnd="SET"
			cmnd.varname=varname
			cmnd.varval=varval
			---minetest.log("simple_dialogs->ldcs after dlg["..topic.."]["..subtopic.."].cmnd="..dump(dlg[topic][subtopic].cmnd))
			--note that we have NOT populated any vars at that point, that happens when the dialog is actually displayed
		end --if varval
	end --if eq
	return cmnd
end --load_dialog_cmnd_set


--this function is used to load an IF cmnd into the dialog table in load_dialog_from_string 
--str is the string after the :if
--if must have all if conditions enclosed in one paren group, even single condition must be in parens
--if (condition) then 
--if ((condition) and (condition) or (condition)) then 
--yes, this has a recursive call to load_dialog_cmnd.  It should NOT cause problems because it can
--only be built from the string that was passed in.  there is no way to fall into an infinate recursive loop.
--function simple_dialogs.load_dialog_cmnd_if(wk,str)
function simple_dialogs.load_dialog_cmnd_if(str)
	--minetest.log("simple_dialogs->ldci top str="..str)
	local cmnd=nil
	local grouping=simple_dialogs.build_grouping_list(str,"(",")")
	if grouping.first>0 then --find " THEN " after the last close paren
		local t=string.find(string.upper(str)," THEN ",grouping.list[grouping.first].close)
		if t then
			--minetest.log("simple_dialogs->ldci t="..t)
			cmnd={}
			cmnd.cmnd="IF"
			cmnd.condstr=string.sub(str,1,t-1)
			local thenstr=simple_dialogs.trim(string.sub(str,t+6)) --trim ensures no leading spaces			
			cmnd.ifcmnd=simple_dialogs.load_dialog_cmnd(thenstr)
			--minetest.log("simple_dialogs->ldci cmnd="..dump(cmnd))
		end --if t
	end --if grouping.first
	return cmnd
end --load_dialog_cmnd_if




--[[ *******************************************************************************
convert Dialog table into a formspec
--]]

--this is kind of an awkward solution for handling gotos, but it works.
--the meat of the formspec creation happens in dialog_to_formspec_inner
--but if that process hits a "goto", then it increments gototopic.count
--and if gototopic.count<4 it sets gototopic.topic and returns.
--then this function calls dialog_to_formspec_inner AGAIN with the new topic.
--if gototopic>=4 then we ignore it.  This prevents any possibility of an eternal loop
function simple_dialogs.dialog_to_formspec(playername,npcself,topic)
	--minetest.log("simple_dialogs->dtf top npcself.dialog="..dump(npcself.dialog))
	--first we make certain everything is properly defined.  if there is an error we do NOT want to crash
	--but we do return an error message that might help debug.
	local errlabel="label[0.375,0.5; ERROR in dialog_to_formspec, "
	if not npcself then return errlabel.." npcself not found]" 
	elseif not npcself.dialog then return errlabel.." npcself.dialog not found]" 
	elseif not topic then return errlabel.." topic passed was nil]"
	end
	npcself.dialog.gototopic={}
	local gototopic=npcself.dialog.gototopic
	gototopic.count=0
	gototopic.topic=topic  --because this is where we are going first, will get changed and pop out if we hit a goto
	local formspec
	repeat
		--this check has to be inside the repeat to catch topics changed by goto
		if gototopic.topic and gototopic.topic=="END" then 
			minetest.close_formspec(playername, "simple_dialogs:dialog")
			return ""
		elseif not npcself.dialog.dlg[topic] then return errlabel.. " topic "..topic.." not found in the dialog]" 
		end 
		--minetest.log("simple_dialogs->dtf before")
		formspec=simple_dialogs.dialog_to_formspec_inner(playername,npcself)
		--minetest.log("simple_dialogs->dtf after gototopic="..dump(gototopic))
		until not gototopic.topic
	return formspec
end


--[[
this is the other side of load_dialog_from_string.  dialog_to_formspec turns a dialog table into 
a formspec with the say text and reply list.
this is when variables are substituted, functions executed, and commands run.

a quick note on weight.  the weight number for each subtopic is the maximum weight for that topic.
So, for example, if you have three treasure topics like this
=Treasure(2)
=Treasure(4)
=Treasure(7)
you will get weights like this:
dlg[Treasure][1].weight=2
dlg[Treasure][2].weight=6    (2+4=6)
dlg[Treasure][3].weight=13   (6+7=13)
this means we can just roll a random number between 1 and 13,
then select the first subtopic for which our random number is less than or equal to its weight.
--]]
function simple_dialogs.dialog_to_formspec_inner(playername,npcself)
	--minetest.log("simple_dialogs->dtf playername="..playername)
	--minetest.log("simple_dialogs->dtf: npcself="..dump(npcself))
	local dlg=npcself.dialog.dlg  --shortcut to make things more readable
	local topic=npcself.dialog.gototopic.topic
	npcself.dialog.gototopic.topic=nil --will be set again if we hit a goto
	--load any variables from calling mod
	for f=1,#registered_varloaders do
		--minetest.log("simple_dialogs-> dtfi loading varloaders")
		registered_varloaders[f](npcself,playername)
	end
	local formspec={}
	--how many matching topics (subtopics) are there  (for example, if there are 3 "TREASURE" topics)
	local subtopicmax=#dlg[topic]
	--get a random number between 1 and the max weight
	local rnd=math.random(dlg[topic][subtopicmax].weight)
	--subtopic represents which topic was chosen when you had repeated topics
	local subtopic=1
	--we loop through all the matching topics and select the first one for which our random number
	--is less than or equal to that topics weight.
	for st=1,subtopicmax,1 do
		--minetest.log("simple_dialogs->dtf t="..t.." rnd="..rnd.." topic="..topic.." subtopicmax="..subtopicmax.." weight="..dlg[topic][t].weight)
		if rnd<=dlg[topic][st].weight then 
			subtopic=st
			break 
		end
	end
	--now subtopic equals the selected subtopic
	--minetest.log("simple_dialogs->dtf topic="..topic.." subtopic="..subtopic)
	--minetest.log("simple_dialogs->dtf before formspec npcself.dialog="..dump(npcself.dialog))
	--
	--very first, run any commands
	--minetest.log("simple_dialogs->dtf topic="..topic.." subtopic="..subtopic)
	--minetest.log("simple_dialogs->dtf dlg["..topic.."]["..subtopic.."]="..dump(dlg[topic][subtopic]))
	for c=1,#dlg[topic][subtopic].cmnd do
		--minetest.log("simple_dialogs->dtf c="..c.." cmnd="..dump(dlg[topic][subtopic].cmnd[c]))
		simple_dialogs.execute_cmnd(npcself,dlg[topic][subtopic].cmnd[c],playername)
		if npcself.dialog.gototopic.topic then 
			--minetest.log("simple_dialogs->dtfi topic set:"..npcself.dialog.gototopic.topic)
			return "" 
		end
	end --for c
	--
	--populate the say portion of the dialog, that is simple.
	local say=dlg[topic][subtopic].say
	say=simple_dialogs.populate_vars_and_funcs(npcself,say,playername)
	if not say then say="" end
	--
	--now get the replylist
	local replies=""
	for r=1,#dlg[topic][subtopic].reply,1 do
		if r>1 then replies=replies.."," end
		local rply=dlg[topic][subtopic].reply[r].text
		--minetest.log("simple_dialogs->dtfsi reply rply bfr="..rply)
		rply=simple_dialogs.populate_vars_and_funcs(npcself,rply,playername)
		--minetest.log("simple_dialogs->dtfsi reply rply aft="..rply)
		--if string.len(rply)>70 then rply=string.sub(rply,1,70)..string.char(10)..string.sub(rply,71) end  tried wrapping, it doesn't work well.
		replies=replies..minetest.formspec_escape(rply)
		--minetest.log("simple_dialogs->dtfsi reply rply fnl="..rply)
	end --for
	--
	local x=0.45
	local y=0.5
	local x2=0.375
	local y2=y+8.375
	formspec={
		"textarea["..x..","..y..";9.4,8;;;"..minetest.formspec_escape(say).."]",
		"textlist["..x2..","..y2..";27,5;reply;"..replies.."]"  --note that replies were escaped as they were added
	}
	--store the topic and subtopic in context as well
	contextdlg[playername].topic=topic
	contextdlg[playername].subtopic=subtopic
	return table.concat(formspec,"")
end --dialog_to_formspec


--you pass in a cmnd table, and this will execute the command.
--this is called from dialog_to_formspec, but it is ALSO called recursively on if, 
--because if the if condition is met, we then execute the ifcmnd
--for the structure of each cmnd table, check the documentation on load_dialog_from_string
function simple_dialogs.execute_cmnd(npcself,cmnd,playername)
	--minetest.log("simple_dialogs->ec cmnd="..dump(cmnd))
	--local dlg=npcself.dialog.dlg
	if cmnd then
		if cmnd.cmnd=="SET" then
			--minetest.log("simple_dialogs ec set cmnd="..dump(cmnd))
			simple_dialogs.save_dialog_var(npcself,cmnd.varname,cmnd.varval,playername)  --load the variable (varname filtering and populating vars happens inside this method)
			--minetest.log("simple_dialogs ec set after vars="..dump(npcself.dialog.vars))
		elseif cmnd.cmnd=="IF" then
			simple_dialogs.execute_cmnd_if(npcself,cmnd,playername)
		elseif cmnd.cmnd=="GOTO" then
			local gototopic=npcself.dialog.gototopic
			gototopic.count=gototopic.count+1
			--we only goto the new topic if we have not exceeded depth, and the topic exists.
			if gototopic.count<=max_goto_depth and npcself.dialog.dlg[cmnd.topic] then --gototopic.count guarantees no infinate goto loops
				gototopic.topic=cmnd.topic
				return ""
			end --if gototopic.count
		elseif cmnd.cmnd=="HOOK" then
			--minetest.log("simple_dialogs->ec hook")
			for f=1,#registered_varloaders do
				local rtn=registered_hooks[f](npcself,playername,cmnd)
				--minetest.log("simple_dialogs->ec hook rtn="..dump(rtn))
				if rtn and rtn=="EXIT" then
					npcself.dialog.gototopic.topic="END"
					return ""
				end --if rtn
			end --for
		end --if cmnd.cmnd=
	end --if cmnd exists
end --execute_cmnd





--this executes an :if command, run during dialog_to_formspec
--pass dlg[topic][subtopic].cmnd[c] 
--cmnd.cmnd="IF"
--cmnd.condstr  This will be the condition, example: ( ( (hitpoints<10) and (name=="badguy") ) or (status=="asleep") )
--cmnd.ifcmnd   This is the command that will be executed if condstr evaluates as true. entire structure of subcommand will be here
--yes, this makes a recursive call, the ifcmnd can even be another if statement.
--BUT, there should be no danger of infinite recursion, because the cmnd structure can NOT be altered during processing.
--so there will always be a finite depth to the recursion.
function simple_dialogs.execute_cmnd_if(npcself,cmnd,playername)  
	--minetest.log("simple_dialogs->eci if cmnd="..dump(cmnd))
	--first thing, populate any vars and run any functions in the condition string
	local condstr=simple_dialogs.populate_vars_and_funcs(npcself,cmnd.condstr,playername)
	--minetest.log("simple_dialogs->eci condstr="..condstr)
	--minetest.log("simple_dialogs->eci vars="..dump(npcself.dialog.vars))
	local ifgrouping=simple_dialogs.build_grouping_list(condstr,"(",")")
	for i=1,#ifgrouping.list,1 do
		local condsection=simple_dialogs.grouping_section(ifgrouping,i,"EXCLUSIVE")  --one paren bounded section of condstr
		local op=simple_dialogs.split_on_operator(condsection)  --gives op.left, op.operator, op.right. op.output
		--split_on_operator ALWAYS returns an op table, no matter what the input, so no need to check if op exists
		--minetest.log("simple_dialog->eci if op="..dump(op))
		condstr=simple_dialogs.grouping_replace(ifgrouping,i,op.output,"EXCLUSIVE")
		--minetest.log("simple_dialogs->ecir if left="..op.left.."| operator="..op.operator.." right="..op.right.."| output="..op.output.." condstr="..condstr)
	end --for
	--minetest.log("simple_dialogs->gdtar if before calc cond="..condstr)
	--at this point we should be down to nothing but zeros and ones, and AND and ORs
	--replace AND with * and OR with + and we have a mathematical equation that will resolve the boolean logic.
	condstr=string.gsub(string.upper(condstr),"AND","*")
	condstr=string.gsub(string.upper(condstr),"OR","+")
	--minetest.log("simple_dialogs->eci if and or subst cond="..condstr)
	--run the string through our sandboxed and filtered math function
	local ifrslt=simple_dialogs.sandboxed_math_loadstring(condstr)
	--minetest.log("simple_dialogs->eci if after calc ifrslt="..ifrslt)
	--now if ifrslt=0 test failed.  if ifrslt>0 test succeded
	if ifrslt>0 then
		--if cmnd.ifcmnd.cmnd=="SET" then
		--	--minetest.log("simple_dialogs->eci if executing set")
		--	simple_dialogs.execute_cmnd_set(npcself,cmnd.ifcmnd)
		--end --ifcmnd SET
		--if the if condition was met, then we execute the ifcmnd, which can be any command
		--minetest.log("simple_dialogs->eci executing ifcmnd "..dump(cmnd))
		simple_dialogs.execute_cmnd(npcself,cmnd.ifcmnd,playername)
		--minetest.log("simple_dialogs->eci back from ifcmnd")
	end --ifrst
end --execute_cmnd_if



--this is used by execute_cmnd_if
--it takes in a condstr that is ONE equation from a possibly more complex if cond str.
--something like (hitpoints<10), it MUST be enclosed in parenthesis.
--it splits it up and returns a table op with the structure:
--op.pos       where the operator was found 
--op.left      what was on the left side of the operator
--op.operator  the operator string
--op.right     what was on the right side of the operator
--op.output    1 if the equation was true, 0 if the equation was false
function simple_dialogs.split_on_operator(condstr)
	local op={}
	if condstr then
		--this is just a slightly less ugly way to search for multiple patterns
		find_operator(op,condstr,">=")
		find_operator(op,condstr,"<=")
		find_operator(op,condstr,"==")
		find_operator(op,condstr,"~=")
		find_operator(op,condstr,">")
		find_operator(op,condstr,"<")
		--minetest.log("simple_dialogs->soo op="..dump(op))
		if op.pos then
			op.left=string.sub(condstr,1,op.pos-1)
			op.right=string.sub(condstr,op.pos+#op.operator)
		else --no operator
			op.left=condstr
			op.operator="nop"
			op.right=""
			op.pos=#condstr+1  --shouldnt matter
		end --if op.pos
		--I built a really cool table of functions, with the operator strings as the keys.  
		--and it WAS cool, but I realized upon looking at it that it made it much more difficult 
		--to understand what was going on.  SO, I replaced it with the chained "if" that is ugly,
		--and inelegant, but easy to understand
		--ifopfunc[op.operator](op)
		if op.operator == ">=" then
			if op.left >= op.right then op.output="1" else op.output="0" end
		elseif op.operator == "<=" then
			if op.left <= op.right then op.output="1" else op.output="0" end
		elseif op.operator == "==" then
			if op.left == op.right then op.output="1" else op.output="0" end
		elseif op.operator == "~=" then
			if op.left ~= op.right then op.output="1" else op.output="0" end
		elseif op.operator == ">" then
			if op.left > op.right then op.output="1" else op.output="0" end
		elseif op.operator == "<" then
			if op.left < op.right then op.output="1" else op.output="0" end
		else
			op.operator="nop"
			op.left=condstr
			op.right=""       --shouldn't matter
			op.pos=#condstr+1 --shouldn't matter
			op.output=condstr 
			--if you didnt provide an operator, then the output is just whatever was there
			--and it had better well resolve to a 0 or when when run through sandboxed_math
		end --if op.operator
	else --if condstr was nil (just in case)
		op.operator="nop"
		op.left=""
		op.right=""
		op.pos=1
		op.output=""
	end --if condstr
return op
end --split_on_operator


--this is just a slightly less ugly way to search for multiple patterns
--op.operator and op.pos will be updated if the passed in operator
--is found in condition string and op.pos is not set or p is before existing op.pos
function find_operator(op,condstr,operator)
	local p=string.find(condstr,operator)
	--of op was found, AND either op.pos is not set, or p is before previous op.pos
	if p and (not op.pos or p > op.pos) then
		op.operator=operator
		op.pos=p
	--minetest.log("simple_dialogs->fo found operator="..operator.." op="..dump(op))
	end --if 
--minetest.log("simple_dialogs->fo notfound operator="..operator.." op="..dump(op))
end --find operator




--this displays the help text
--I need a way to deal with this by language
function simple_dialogs.dialog_help(playername)
	--local file = io.open(minetest.get_modpath("simple_dialogs").."/simple_dialogs_help.txt", "r")
	--minetest.log("simple_dialogs-> dh top")
	local file = io.open(helpfile, "r")
	if file then
		--minetest.log("simple_dialogs-> dh if file")
		--local help
		local helpstr=file:read("*all")
		file.close()
		local formspec={
		"formspec_version[4]",
		"size[15,15]", 
		"textarea[0.375,0.35;14,14;;Simple_Dialogs-Help;"..minetest.formspec_escape(helpstr).."]"
		}
		minetest.show_formspec(playername,"simple_dialogs:dialoghelp",table.concat(formspec))
	else
		minetest.log("simple_dialogs->dialoghelp: ERROR unable to find simple_dialogs_help.txt in modpath")
	end 
end --dialog_help

--------------------------------------------------------------



function simple_dialogs.save_dialog_var(npcself,varname,varval,playername)
	if npcself and varname then
		if not npcself.dialog.vars then npcself.dialog.vars = {} end
		if not varval then varval="" end
		--minetest.log("simple_dialogs->---sdv bfr varname="..varname.." varval="..varval)
		varname=simple_dialogs.populate_vars_and_funcs(npcself,varname,playername)  --populate vars
		varname=simple_dialogs.varname_filter(varname)  --filter down to only allowed chars
		varval=simple_dialogs.populate_vars_and_funcs(npcself,varval,playername)  --populate vars
		--minetest.log("simple_dialogs->sdv aft varname="..varname.." varval="..varval)
		npcself.dialog.vars[varname] = varval  --add to variable list
		--minetest.log("simple_dialogs->sdv end npcself.dialog.vars="..dump(npcself.dialog.vars))
	end
end --save_dialog_var


function simple_dialogs.get_dialog_var(npcself,varname,playername,defaultval)
	if npcself and varname then
		if not defaultval then defaultval="" end
		if not npcself.dialog.vars then npcself.dialog.vars = {} end
		--minetest.log("simple_dialogs->---gdv bfr varname="..varname)
		varname=simple_dialogs.varname_filter(varname)  --filter down to only allowed chars, no need for trim since spaces are not allowed
		--minetest.log("simple_dialogs->---gdv aft varname="..varname)
		if varname=="PLAYERNAME" then
			--playername must be dealt with differently.  we can not just store it as a variable because 
			--If two players spoke to the same npc at the same time, one would overwrite the others playername
			return playername 
		elseif npcself.dialog.vars[varname] then return npcself.dialog.vars[varname]
		else return defaultval
		end
	end
end --get_dialog_var



--[[ *******************************************************************************
Grouping
--]]


--this function will go through a string and build a list that tells what order
--to process parenthesis (or any other open close delimiter) in.
--example:
--12345678901234
--((3*(21+2))/4)
--list[1].open=5 close=10
--list[2].open=2 close=11
--list[3].open=1 close=14
--note that if you pass this txt that has bad syntax, it will not throw an error, but instead stop processing and return the list up to that point.
--list[].open and close are inclusive.  it includes the delimeter
--list[].opene and closee are exclusive.  it does NOT include the delimiter
--so in the above example:
--list[1].opene=6 close=9
--list[2].opene=3 close=10
--list[3].opene=2 close=13
--
--if you pass funcname then only entries that start with funcname( are returned in the final list
--for funcname we can NOT just pass funcname( as the opendelim, because if we did, grouping
--would NOT take into account other functions or parenthesis.  example:
--add(goodnums,calc(@[x]@+1))  <- we need add to recognize the calc function or it will get the wrong close delimiter
function simple_dialogs.build_grouping_list(txt,opendelim,closedelim,funcname)
	--minetest.log("simple_dialogs->bgl top, txt="..txt.." funcname="..dump(funcname))
	if funcname then funcname=simple_dialogs.trim(string.upper(funcname)) end
	local grouping={}
	grouping.list={}
	grouping.origtxt=txt --is this useful?
	grouping.txt=txt
	grouping.first=0  --this will store the grouping index of the first delim in the string
	local openstack={}
	local funcstack={}
	local opendelim_len=string.len(opendelim)
	grouping.opendelim_len=opendelim_len
	local closedelim_len=string.len(closedelim)
	grouping.closedelim_len=closedelim_len
	for i=1,string.len(txt),1 do
		if string.sub(txt,i,i+opendelim_len-1)==opendelim then --open delim
			openstack[#openstack+1]=i  --open pos onto stack.
			--minetest.log("simple_dialogs->bgl i="..i.." open  openstack["..#openstack.."]="..openstack[#openstack])
			if funcname and ((i-#funcname)>0) and (string.upper(string.sub(txt,i-#funcname,i-1))==funcname) then
				funcstack[#openstack]=funcname --just a flag to let us know this openstack matches our function
				openstack[#openstack]=i-#funcname
				--minetest.log("simple_dialogs->bgl open <FUNCNAME> openstack["..#openstack.."]="..openstack[#openstack].." funcname="..funcname.." #funcname="..#funcname)
			end
		elseif string.sub(txt,i,i+closedelim_len-1)==closedelim then -- close delim
			--minetest.log("simple_dialogs->bgl i="..i.." close ")
			--if you find parens out of order, just stop and return what you have so far
			if #openstack<1 then return grouping end 
			--minetest.log("simple_dialogs->bgl close openstack="..dump(openstack).." funcstack="..dump(funcstak))
			if (not funcname) or (funcstack[#openstack]) then
				--minetest.log("simple_dialogs->bgl notfuncname or is func")
				local l=#grouping.list+1
				grouping.list[l]={}
				local gll=grouping.list[l]
				gll.open=openstack[#openstack]
				gll.opene=gll.open+(opendelim_len)
				--minetest.log("simple_dialogs->bgl bfr func: gll="..dump(gll))
				if funcname then gll.opene=gll.opene+#funcname end
				gll.close=i+(closedelim_len-1)
				gll.closee=i-1
				--grouping.first is the first delim in the string.  if grouping.first=0 then we have not set it at all
				if grouping.first==0 then grouping.first=l
				elseif gll.open<grouping.list[grouping.first].open then grouping.first=l
				end
				--minetest.log("simple_dialogs->bgl end close: gll="..dump(gll))
			end --if not funcname
			table.remove(openstack,#openstack) --remove from stack
			table.remove(funcstack,#openstack+1) --may or may not be there, +1 because we just reduced the size of openstack by one
		end --if
	end --while
	return grouping
end --build_grouping_list



function simple_dialogs.grouping_section(grouping,i,incl_excl)
	if not incl_excl then incl_excl="INCLUSIVE" end
	--minetest.log("simple_dialogs->gs top i="..i.." incl_excl="..incl_excl.." grouping="..dump(grouping))
	local gli=grouping.list[i]
	--minetest.log("GGGs after gli")
	if incl_excl=="INCLUSIVE" then
		--minetest.log("GGGs inclusive")
		return string.sub(grouping.txt,gli.open,gli.close)
	else
		--minetest.log("GGGs exclusive") 
		return string.sub(grouping.txt,gli.opene,gli.closee)
	end
end --grouping_section



function simple_dialogs.grouping_sectione(grouping,i)
	--minetest.log("GGGse i="..i.." grouping="..dump(grouping))
	simple_dialogs.grouping_section(grouping,i,"EXCLUSIVE")
end --grouping_sectione


function simple_dialogs.grouping_replace(grouping,idx,replacewith,incl_excl)
	--minetest.log("***GGGR top grouping="..dump(grouping).." idx="..idx.." replacewith="..replacewith.." incl_excl="..incl_excl)
	if not incl_excl then incl_excl="INCLUSIVE" end
	local s=grouping.list[idx].open
	local e=grouping.list[idx].close
	if incl_excl=="EXCLUSIVE" then 
		s=grouping.list[idx].opene
		e=grouping.list[idx].closee
	end 
	local origlen=e-s+1
	local diff=string.len(replacewith)-origlen
	local txt=grouping.txt
	grouping.txt=string.sub(txt,1,s-1)..replacewith..string.sub(txt,e+1)
	for i=1,#grouping.list,1 do
		local gli=grouping.list[i]
		if gli.open>s then gli.open=gli.open+diff end
		if gli.opene>s then gli.opene=gli.opene+diff end
		if gli.close>s then gli.close=gli.close+diff end
		if gli.closee>s then gli.closee=gli.closee+diff end
	end --for
	--minetest.log("GGGR bot grouping="..dump(grouping))
	--minetest.log("GGGR2 bot origtxt="..grouping.origtxt)
	--minetest.log("GGGR2 bot     txt="..grouping.txt)
return grouping.txt
end--grouping_replace



--[[ ##################################################################################
func splitter
--]]



function simple_dialogs.func_splitter(line,funcname,parmcount)
	--minetest.log("simple_dialogs->fs--------------- funcname="..funcname.." line="..line)
	if not parmcount then parmcount=1 end
	local grouping=simple_dialogs.build_grouping_list(line,"(",")",funcname)
	--minetest.log("simple_dialogs->fs grouping="..dump(grouping))
	for g=1,#grouping.list,1 do
		grouping.list[g].parm={}
		local sectione=simple_dialogs.grouping_section(grouping,g,"EXCLUSIVE") --get section from string
		--minetest.log("simple_dialogs->fs g="..g.." sectione="..sectione)
		local c=1
		while c<=parmcount do
			local comma=string.find(sectione,",")
			if c<parmcount and comma then 
					grouping.list[g].parm[c]=string.sub(sectione,1,comma-1)
					sectione=string.sub(sectione,comma+1)
			else
				grouping.list[g].parm[c]=sectione
				sectione=""
			end
			c=c+1
		end --while
	end --for
	return grouping
end --func_splitter





--[[ ##################################################################################
very generic utilities
--]]

--trims leading and trailing spaces
function simple_dialogs.trim(s)
	if not s then s="" end
	return s:match "^%s*(.-)%s*$"
end


--this function loops through every entity in the game until it finds the one that 
--matches the passed in id, and returns it.
--I kept thinking there simply HAD to be a faster better way to do this,
--but I didn't find it.
function simple_dialogs.get_npcself_from_id(npcId)
	if npcId==nil then return nil
	else
		for k, v in pairs(minetest.luaentities) do
			if v.object and v.id and v.id == npcId then
				return v
			end--if v.object
		end--for
	end --if npcId
end--func


--this function checks to see if an entity already has an id field
--if it does not, it creates one
--the format of npcid was inherited from mobs_npc, which inherited it from something else
--and it may change in the future (Which should have no impact on anything) 
function simple_dialogs.set_npc_id(npcself)
	if not npcself.id then
		npcself.id = (math.random(1, 1000) * math.random(1, 10000))
			.. npcself.name .. (math.random(1, 1000) ^ 2)
	end
	return npcself.id
end


--this is just a function for dumping a table to the logs in a readable format
function dump(o)
	if type(o) == 'table' then
		local s = '{ '
		for k,v in pairs(o) do
			if type(k) ~= 'number' then k = '"'..k..'"' end
			s = s .. '['..k..'] = ' .. dump(v) .. ','
		end
	return s .. '} '
	else
		return tostring(o)
	end
end


--This function processes a string as a mathmatical equation using loadstring
--The string is filtered so that ONLY mathematical symbols are allowed.
--furthermore, loadstring is run within a sandbox so that no other lua functions can be called
--and finally the whole thing is run within a pcall so that any errors in the math can 
--not cause a crash.
function simple_dialogs.sandboxed_math_loadstring(mth)
	if not mth then return "" end
	--first we filter the string to allow NOTHING but numbers, parentheses, period, and +-*/^
	mth=simple_dialogs.calc_filter(mth)
	--now we sandbox (do not allow arbitrary lua code execution)  
	--This is overkill, the filtering should ensure this is safe, but why not?
	--better too much security than too little
	local env = {loadstring=loadstring} --only loadstring can run
	local f=function() return loadstring("return "..mth.."+0")() end
	setfenv(f,env) --allow function f to only run in sandbox env
	--minetest.log("simple_dialogs->sml before mth="..mth)
	pcall(function() mth=f() end) --pcall ensures this can NOT cause an error
	--minetest.log("simple_dialogs->sml after mth="..dump(mth))
	--we should ALWAYS return a number to prevent possible errors
	if not mth then mth=0 --this deals with if it comes back as nil
	elseif type(mth)~="number" then mth=0  --and this deals with if comes back as a string
	end --if not mth
	--minetest.log("simple_dialogs->sml after error mth="..dump(mth))
	return mth
end --sandboxed_math_loadstring


--[[ ##################################################################################
more simple_dialog specific utilities
--]]


--topics will be upper cased, and have all characters stripped except for letters, digits, dash, and underline
function simple_dialogs.topic_filter(topicin)
	local allowedchars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_%-" --characters allowed in dialog topics %=escape
	return string.upper(topicin):gsub("[^" .. allowedchars .. "]", "")
end --topic_filter


--variable names will be upper cased, and have all characters stripped except for letters, digits, dash, underline, and period
function simple_dialogs.varname_filter(varnamein)
	local allowedchars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_%-%." --characters allowed in variable names %=escape
	return string.upper(varnamein):gsub("[^" .. allowedchars .. "]", "")
end --varname_filter


--ONLY mathmatical symbols allowed. 
function simple_dialogs.calc_filter(mathstrin)
	local allowedchars = "0123456789%.%+%-%*%/%^%(%)" --characters allowed in math	
	return string.upper(mathstrin):gsub("[^" .. allowedchars .. "]", "")
end --calc_filter


--this function populates variables
--do not call this directly, use populate_vars_and_funcs instead
function simple_dialogs.populate_vars(npcself,line,playername)
	if npcself and npcself.dialog.vars then
		local grouping=simple_dialogs.build_grouping_list(line,chars.varopen,chars.varclose)
		--minetest.log("CCC vars="..dump(npcself.dialog.vars))
		for i=1,#grouping.list,1 do
			--local gli=grouping.list[i]
			--minetest.log("CCC beforesectione i="..i.." grouping="..dump(grouping))
			local varname=simple_dialogs.grouping_section(grouping,i,"EXCLUSIVE") --get variable name
			--minetest.log("CCC i="..i.." sectione="..sectione.." varname="..varname)
			line=simple_dialogs.grouping_replace(grouping,i,simple_dialogs.get_dialog_var(npcself,varname,playername),"INCLUSIVE")
		end --for
	end --if
	return line
end --populate_vars


--this function executes the add(var,value) and rmv(var,value) and IsInList() and NotInList() and calc() functions
--do not call this directly, use populate_vars_and_funcs instead
--calc(math)
--add(variable,stringtoadd)
--rmv(variable,stringtoremove)
--isinlist(variable,stringtolookfor)
--NotInList(variable,stringtolookfor)
--isSet(varname)       returns true of the variable exists in the list, and is not empty.  false otherwise
--isNotSet(varname)    returns true of the variable does NOT exists in the list, or is empty, false if it does
--YesNo(func())         convert 0 or N into No and 1 or Y into Yes (for display purposes)  (Do not use direcly in if as it does not return 0 or 1)
function simple_dialogs.populate_funcs(npcself,line,playername)  
	--minetest.log("simple_dialogs->pf top line="..line)
	if npcself and npcself.dialog.vars and line then
		--CALC   calc(math)
		local grouping=simple_dialogs.func_splitter(line,"CALC",1)
		if grouping then
			--minetest.log("simple_dialogs->pf calc #grouping.list="..#grouping.list)
			for g=1,#grouping.list,1 do
				local mth=grouping.list[g].parm[1]
				mth=simple_dialogs.calc_filter(mth)  --noting but number and mathmatical symbols allowed!
				--minetest.log("simple_dialogs->pf calc filter mth="..mth)
				mth=simple_dialogs.sandboxed_math_loadstring(mth)
				--minetest.log("simple_dialogs->pf calc loadstr mth="..mth)
				line=simple_dialogs.grouping_replace(grouping,g,mth,"INCLUSIVE")
			end --for
		end --if grouping CALC
		--ADD  add(variable,stringtoadd)
		local grouping=simple_dialogs.func_splitter(line,"ADD",2)
		if grouping then
			--minetest.log("simple_dialogs->pf add #grouping.list="..#grouping.list)
			for g=1,#grouping.list,1 do
				local var=grouping.list[g].parm[1]  --populate_vars should always already have happened
				local value=grouping.list[g].parm[2]
				--minetest.log("simple_dialogs->pf var="..var.." value="..value)
				--: simple_dialogs->pf var=dd(list value=singleplayer
				local list=simple_dialogs.get_dialog_var(npcself,var,playername,"|")
				if string.sub(list,-1)~="|" then list=list.."|" end --must always end in |
				--minetest.log("simple_dialogs->dialog.vars="..dump(npcself.dialog.vars))
				--minetest.log("simple_dialogs->bfradd list="..list) 
				if not string.find(list,"|"..value.."|") then
					list=list..value.."|" --safe because we guaranteed the list ends in | above
				end
				line=simple_dialogs.grouping_replace(grouping,g,list,"INCLUSIVE")
				--minetest.log("simple_dialogs->aftadd list="..list) 
			end --for
		end --if grouping ADD
		--RMV  rmv(variable,stringtoremove)
		grouping=simple_dialogs.func_splitter(line,"RMV",2)
		if grouping then
			for g=1,#grouping.list,1 do
				local var=grouping.list[g].parm[1]  --populate_vars should always already have happened
				local value=grouping.list[g].parm[2]
				local list=simple_dialogs.get_dialog_var(npcself,var,playername)
				--minetest.log("simple_dialogs->pf rmv list="..list.."<")
				list=string.gsub(list,"|"..value.."|","|")
				line=simple_dialogs.grouping_replace(grouping,g,list,"INCLUSIVE")
			end --for
		end --if grouping RMV
		--ISINLIST  isinlist(variable,stringtolookfor)  returns 1(true) or 0(false)
		grouping=simple_dialogs.func_splitter(line,"ISINLIST",2)
		line=simple_dialogs.in_list(npcself,grouping,"IS",line,playername)
		--NOTINLIST NotInList(variable,stringtolookfor) returns 1 if not in the list, 0 if it is in the list
		grouping=simple_dialogs.func_splitter(line,"NOTINLIST",2)
		line=simple_dialogs.in_list(npcself,grouping,"NOT",line,playername)
		--isSet(varname) returns true if the variable exists in the list, and is not empty. false otherwise
		grouping=simple_dialogs.func_splitter(line,"ISSET",1)
		line=simple_dialogs.is_set(npcself,grouping,"IS",line)
		--isNotSet(varname) returns true if the variable does NOT exist in the list, or is empty, false if it does
		grouping=simple_dialogs.func_splitter(line,"ISNOTSET",1)
		line=simple_dialogs.is_set(npcself,grouping,"NOT",line)
		--YesNo(func())  YesNo turn 0 or N into No and 1 or Y into Yes (for display purposes)
		--do NOT use YesNo in a :if!!!!
		grouping=simple_dialogs.func_splitter(line,"YESNO",1)
		if grouping then
			for g=1,#grouping.list,1 do
				local str=grouping.list[g].parm[1]  --populate_vars should always already have happened
				local testchar=string.sub(string.upper(simple_dialogs.trim(str).." "),1,1) --trim can not return nil
				local rtn="No"
				if testchar=="1" or testchar=="Y" then rtn="Yes" end
				line=simple_dialogs.grouping_replace(grouping,g,rtn,"INCLUSIVE")
			end --for
		end --if grouping 
	end --if npcself
	--minetest.log("simple_dialogs->pf bot line="..line)
	return line
end --populate_funcs


--this function executes the isinlist and notinlist functions
--it checks to see if the value in parm[1] is in the list parm[2] 
--the items in the list in parm[2] should be separated by vertical bars 
--(and they will be if you used add and rmv to handle the list)
--when parm isornot="NOT" the result is reversed.  (1=not inlist, 0=inlist)
--the result returned is the line passed in with the function replaced by its result
function simple_dialogs.in_list(npcself,grouping,isornot,line,playername)
	if grouping then
		--minetest.log("simple_dialogs-> il grouping)
		for g=1,#grouping.list,1 do
			local var=grouping.list[g].parm[1]  --populate_vars should always already have happened
			local lookfor=grouping.list[g].parm[2]
			local list=simple_dialogs.get_dialog_var(npcself,var,playername)
			local rtn="0"
			if string.find(list,"|"..lookfor.."|") then rtn="1" end  --using string, numbers cause problems sometimes
			rtn=is_or_not(rtn,isornot)
			line=simple_dialogs.grouping_replace(grouping,g,rtn,"INCLUSIVE")
		end --for
	end --if grouping
	return line
end --in_list



--this function executes the isset and isnotset functions.
--it checks to see if the variable name (in parm[1]) is set
--it counts a variable as set when it both exists, and is not empty
--when parm isornot="NOT" the result is reversed.  (1=not set, 0=set)
--the result returned is the line passed in with the function replaced by its result
function simple_dialogs.is_set(npcself,grouping,isornot,line)
	--minetest.log("simple_dialogs->is vars="..dump(npcself.dialog.vars))
	if grouping then
		for g=1,#grouping.list,1 do
			local varname=grouping.list[g].parm[1]  --populate_vars should always already have happened
			local rtn="0"
			if npcself and varname then
				if not npcself.dialog.vars then npcself.dialog.vars = {} end
				varname=simple_dialogs.varname_filter(varname)  --filter down to only allowed chars, no need for trim since spaces are not allowed
				--playername always exists, it is not stored in dialog.vars
				if varname=="PlAYERNAME" or (npcself.dialog.vars[varname] and npcself.dialog.vars[varname]~="") then 
					rtn="1"
				end
			end
			rtn=is_or_not(rtn,isornot)
			line=simple_dialogs.grouping_replace(grouping,g,rtn,"INCLUSIVE")
			--minetest.log("simple_dialogs->is var="..varname.."< rtn="..rtn.." line="..line)
		end --for
	end --if grouping
	return line
end --is_set

--rtn passed in will be "1" (true) or "0" false.
--if isornot="NOT" then rtn will be reversed
function is_or_not(rtn,isornot)
	if isornot=="NOT" then
		if rtn=="0" then rtn="1" else rtn="0" end 
	end --if isornot
	return rtn
end --is_or_not



--this function combines populate_vars and populate_funcs
--the others should never be called directly, use this one.
function simple_dialogs.populate_vars_and_funcs(npcself,line,playername)
	if npcself and line and playername then
		line=simple_dialogs.populate_vars(npcself,line,playername)
		line=simple_dialogs.populate_funcs(npcself,line,playername)
	end
	return line
end --populate_vars_and_funcs


--[[ ##################################################################################
registrations
--]]


--when the player exits, wipe out their context entries
minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	contextctr[name] = nil
	contextdlg[name] = nil 
end)--register_on_leaveplayer


--this handles returned fields for the dialog control formspec
--this will only work if you use show_dialog_control_formspec.  If you have integrated the dialog controls 
--into another formspec you will have to call process_simple_dialog_control_fields from your own player receive fields function
minetest.register_on_player_receive_fields(function(player, formname, fields)
	local playername = player:get_player_name()
	if formname ~= "simple_dialogs:dialog_controls" then 
		if contextctr[playername] then contextctr[playername]=nil end
		return 
	end
	--minetest.log("simple_dialogs->receive controls: fields="..dump(fields))
	local npcId=contextctr[playername] --get the npc id from local context
	local npcself=nil
	if not npcId then return --exit if npc id was not set 
	else npcself=simple_dialogs.get_npcself_from_id(npcId)  --try to find the npcId in the list of luaentities
	end
	if npcself ~= nil then
		simple_dialogs.process_simple_dialog_control_fields(playername,npcself,fields)
	end --if npcself not nil
end) --register_on_player_receive_fields dialog_controls


--this handles returned fields for the regular dialog formspec
minetest.register_on_player_receive_fields(function(player, formname, fields)
	local playername = player:get_player_name()
	if formname ~= "simple_dialogs:dialog" then
		--can NOT clear context here because this can be called from inside the control panel, 
		--and that can be from a DIFFERENT mod where I cannot predict the name
		return 
	end
	--minetest.log("simple_dialogs->receive_fields dialog: fields="..dump(fields))
	if   not contextdlg[playername] 
		or not contextdlg[playername].npcId 
		or not contextdlg[playername].topic 
		or not contextdlg[playername].subtopic 
		then 
			minetest.log("simple_dialogs->receive_fields dialog: ERROR in dialog receive_fields: context not properly set")
			return 
	end
	local npcId=contextdlg[playername].npcId --get the npc id from local context
	local npcself=nil
	npcself=simple_dialogs.get_npcself_from_id(npcId)  --try to find the npcId in the list of luaentities
	local topic=contextdlg[playername].topic
	local subtopic=contextdlg[playername].subtopic
	--minetest.log("simple_dialogs->receive_fields dialog: topic="..topic.." subtopic="..subtopic.." npcId="..npcId)
	--minetest.log("simple_dialogs->receive_fields dialog: npcself="..dump(npcself))
	if   not npcself
		or not npcself.dialog
		or not npcself.dialog.dlg[topic]
		or not npcself.dialog.dlg[topic][subtopic]
		then 
			minetest.log("simple_dialogs->receive_fields dialog: ERROR in dialog receive_fields: npcself.dialog.dlg[topic][subtopic] not found")
			return
	end
	--
	--incoming reply fields look like: fields={ ["reply"] = CHG:1,}
	if fields["reply"] then 
		--minetest.log("simple_dialogs->sss got back reply!"..dump(fields["reply"]))
		local r=tonumber(string.sub(fields["reply"],5))
		--if npcself.dialog.dlg[topic][subtopic].reply[r].target == "END" then
		--	minetest.close_formspec(playername, "simple_dialogs:dialog")
		--else
			local newtopic=npcself.dialog.dlg[topic][subtopic].reply[r].target
			 simple_dialogs.show_dialog_formspec(playername,npcself,newtopic)
		--end
	end
end) --register_on_player_receive_fields dialog





