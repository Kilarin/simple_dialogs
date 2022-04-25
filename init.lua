simple_dialogs = { }

--local S = mobs.intllib_npc  TODO integrate with intllib

-- simple dialogs by Kilarin

local contextctr = {}
local contextdlg = {}

local chars = {}
chars.tag="="
chars.reply=">"
chars.varopen="@["
chars.varclose="]@"

--[[
local tag_filter=simple_dialogs.tag_filter
local wrap=simple_dialogs.wrap
local get_npcself_from_id=simple_dialogs.get_npcself_from_id
local set_npc_id=simple_dialogs.set_npc_id
]]--

--when the player exits, wipe out their context entries
minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	contextctr[name] = nil
	contextdlg[name] = nil 
end)--register_on_leaveplayer

--[[
		-- by right-clicking owner can switch npc between follow, wander and stand
		if self.owner and self.owner == name then
			minetest.show_formspec(name, "mobs_npc:controls", get_NPCControls_formspec(name,self) )
			--minetest.show_formspec(name,"mobs_npc:dialog",get_dialog_formspec(name,self,"START"))
		else
			minetest.show_formspec(name,"mobs_npc:dialog",get_dialog_formspec(name,self,"START"))
		end
	end
]]--


--this creates and displays an independant dialog control formspec
--dont use this if you are trying to integrate dialog controls with another formspec
function simple_dialogs.show_dialog_controls_formspec(pname,npcself)
	minetest.show_formspec(pname, "simple_dialogs:dialog_controls", get_dialog_controls_formspec(pname,npcself) )
end --show_dialog_controls_formspec


--this gets an independant dialog control formspec
function simple_dialogs.get_dialog_controls_formspec(pname,npcself)
	contextctr[pname]=simple_dialogs.set_npc_id(npcself) --store the npc id in local context so we can use it when the form is returned.  (cant store self)
	-- Make npc controls formspec 
	local formspec = {
		"formspec_version[4]",
		"size[15,7]", 
		}
	simple_dialogs.add_dialog_control_to_formspec(pname,npcself,formspec,0.375,0.375)
	--minetest.log("simple_dialogs->getdialogcontrols: formspec after="..dump(formspec))
	table.concat(formspec, "")
	return table.concat(formspec, "")
end --get_dialog_controls_formspec



--this adds the dialog controls to an existing formspec, so it could be used with another formspec
--TODO: allow control of width?
function simple_dialogs.add_dialog_control_to_formspec(pname,npcself,formspec,x,y)
	--note that if this is called from get_dialog_controls_formspec set_npc_id will just return the value already set
	contextctr[pname]=simple_dialogs.set_npc_id(npcself)
	local dialogtext=""
	if npcself.dialogtext then dialogtext=npcself.dialogtext end
	formspec[#formspec+1]="textarea["..x..","..y..";14,4.8;dialog;Dialog;"..minetest.formspec_escape(dialogtext).."]"
	local x2=x
	local y2=y+5
	formspec[#formspec+1]="button["..x2..","..y2..";1.5,0.8;help;Help]"
	local x3=x2+2
	formspec[#formspec+1]="button["..x3..","..y2..";1.5,0.8;save;Save]"
	local x4=x3+2
	formspec[#formspec+1]="button["..x4..","..y2..";3,0.8;saveandtest;Save & Test]"
	--minetest.log("simple_dialogs->adddialogcontrol: formspec="..dump(formspec))
end --add_dialog_control_to_formspec



--this will only work if you use show_dialog_control_formspec.  If you have integrated the dialog controls 
--into another formspec you will have to call process_simple_dialog_control_fields from your own player receive fields function
minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()
	if formname ~= "simple_dialogs:dialog_controls" then 
		if contextctr[pname] then contextctr[pname]=nil end
		return 
	end
	--minetest.log("simple_dialogs->recieve controls: fields="..dump(fields))
	local npcId=contextctr[pname] --get the npc id from local context
	local npcself=nil
	if not npcId then return --exit if npc id was not set 
	else npcself=simple_dialogs.get_npcself_from_id(npcId)  --try to find the npcId in the list of luaentities
	end
	if npcself ~= nil then
		simple_dialogs.process_simple_dialog_control_fields(pname,npcself,fields)
	end --if npcself not nil
end) --register_on_player_receive_fields dialog_controls



function simple_dialogs.process_simple_dialog_control_fields(pname,npcself,fields)
	if fields["save"] or fields["saveandtest"] then
		simple_dialogs.load_dialog_from_string(npcself,fields["dialog"],pname)
	end --save or saveandtest
	if fields["saveandtest"] then
		minetest.show_formspec(pname,"simple_dialogs:dialog",simple_dialogs.get_dialog_formspec(pname,npcself,"START"))
	elseif fields["help"] then
		simple_dialogs.dialog_help(pname)
	end
end --process_simple_dialog_control_fields





--[[
this is where the whole dialog structure is created.

A typical dialog looks like this:
===Start
Hello, welcome to Jarbinks tower of fun!
>jarbink:who is jarbink?
>name:who are you?
>directions:How do I get into the tower?

tags start with = in pos 1 and can look like ===Start   or  =Treasure(5) (any number of ='s are ok as long as there is 1 in pos 1)
a number in parenthesis after the tag name is a "weight" for that entry, which effects how frequently it is chosen.
weight is optional and defaults to 1.
you can have multiple tags with the same name, each gets a number, "tagcount", 
when you reference that tag one of the multiple results will be chosen randomly
tags can only contain letters, numbers, underscores, and dashes, all other characters are stripped (letters are uppercased)

After the tag is the "say", this is what the npc says for this tag.

Replies start with > in position 1, and are followed by a target and a colon.  The target is the "tag" this replay takes you to.
the reply follows the colon
--]]
function simple_dialogs.load_dialog_from_string(npcself,dialogstr,pname)
	npcself.dialog = {}
	npcself.dialogvars = {}
	--add playername to variables IF it was passed in
	if pname then simple_dialogs.load_dialog_var(npcself,"PLAYERNAME",pname) end
	local tag = ""
	local tagcount=1
	local weight=1
	local say = ""
	local replycount = ""
	local reply = ""
	for line in dialogstr:gmatch '[^\n]+' do
		--minetest.log("simple_dialogs->loadstr: line="..line)
		local firstchar=string.sub(line,1,1)
		if firstchar == chars.tag then  --we found a tag, process it
			tag=line  --this might still include weight
			--get the weight from parenthesis
			weight=1
			local i, j = string.find(line,"%(") --look for open parenthesis
			local k, l = string.find(line,"%)") --look for close parenthesis
			--if ( and ) both exist, and the ) is after the (
			if i and i>0 and k and k>i then --found weight
				tag=string.sub(line,1,i-1) --cut the (weight) out of the tagname
				local w=string.sub(line,i+1,k-1) --get the number in parenthesis (weight)
				weight=tonumber(w)
				if weight==nil or weight<1 then weight=1 end
			end
			--
			--strip tag down to only allowed characters
			tag=simple_dialogs.tag_filter(tag) --this also strips all leading = signs
			--
			tagcount=1
			if npcself.dialog[tag] then --existing tag
				tagcount=#(npcself.dialog[tag])+1
				weight=npcself.dialog[tag][tagcount-1].weight+weight  --add previous weight to current weight
				--weight is always the maximum number rolled that returns this tagcount
				--TODO: further notes on weight?  here or in readme?
			else --if this is a new tag
				npcself.dialog[tag]={} 
			end
			say=""
			replycount=1
			npcself.dialog[tag][tagcount]={}
			npcself.dialog[tag][tagcount].weight=weight
			npcself.dialog[tag][tagcount].reply={}
		elseif firstchar == chars.reply and tag ~= "" then  --we found a reply, process it
			--if we got a reply, then the say is ended, add it
			npcself.dialog[tag][tagcount].say=say
			--split into target and reply
			local i, j = string.find(line,":")
			if i==nil then 
				i=string.len(line)+1 --if they left out the colon, treat the whole line as the tag
			end
			npcself.dialog[tag][tagcount].reply[replycount]={}
			npcself.dialog[tag][tagcount].reply[replycount].target=simple_dialogs.tag_filter(string.sub(line,2,i-1))
			npcself.dialog[tag][tagcount].reply[replycount].text=string.sub(line,i+1)
			if npcself.dialog[tag][tagcount].reply[replycount].text=="" then
				npcself.dialog[tag][tagcount].reply[replycount].text=string.sub(line,2,i-1)
			end
			replycount=replycount+1
		--we check that a tag is set to avoid errors, just in case they put text before the first tag
		--we check that replycount=1 because we are going to ignore any text between the replies and the next tag
		elseif firstchar==":" then --commands
			local spc=string.find(line," ",2)
			if spc then
				local cmnd=string.upper(string.sub(line,2,spc-1))
				local str=string.sub(line,spc+1) --rest of line without the command
				str=simple_dialogs.populate_vars(npcself,str) --populate any variables
				if cmnd=="SET" then
					local eq=string.find(str,"=",6)
					if eq then
						local k=string.sub(str,1,eq-1)
						local v=string.sub(str,eq+1)
						if v then
							k=simple_dialogs.varname_filter(k)
							simple_dialogs.load_dialog_var(npcself,k,v) 
						end --if v
					end --if eq
				end --if cmnd
			end --if spc
		elseif tag~="" and replycount==1 then  --we found a dialog line, process it
			say=say..line.."\n"
		end
	end --for line in dialog
	npcself.dialogtext=dialogstr
	--minetest.log("simple_dialogs->loadstr npcself.dialog="..dump(npcself.dialog))
end --load_dialog_from_string



--tags will be upper cased, and have all characters stripped except for letters, digits, dash, and underline
function simple_dialogs.tag_filter(tagin)
	local allowedchars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_%-" --characters allowed in dialog tags %=escape
	return string.upper(tagin):gsub("[^" .. allowedchars .. "]", "")
end --tag_filter



--variable names will be upper cased, and have all characters stripped except for letters, digits, dash, underline, and period
function simple_dialogs.varname_filter(varnamein)
	local allowedchars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_%-%." --characters allowed in variable names %=escape
	return string.upper(varnamein):gsub("[^" .. allowedchars .. "]", "")
end --varname_filter


--this function lets you load a dialog for an npc from a file.  So you can store predetermined dialogs
--as text files and load them for special npc or types of npcs (pirates, villagers, blacksmiths etc)
--there are several dialog files already available in this mod.
--we take modname as a parameter because you might have dialogs in a different mod that uses this mod
function simple_dialogs.load_dialog_from_file(npcself,modname,dialogfilename)
	local file = io.open(minetest.get_modpath(modname).."/"..dialogfilename)
	if file then
		local dialogstr=file:read("*all")
		file.close()
		simple_dialogs.load_dialog_from_string(npcself,dialogstr)
	end
end --load_dialog_from_file



function simple_dialogs.dialog_help(pname)
	local file = io.open(minetest.get_modpath("simple_dialogs").."/simple_dialogs_help.txt", "r")
	if file then
		--local help
		local helpstr=file:read("*all")
		file.close()
		local formspec={
		"formspec_version[4]",
		"size[15,15]", 
		"textarea[0.375,0.35;14,14;;help;"..minetest.formspec_escape(helpstr).."]"
		}
		minetest.show_formspec(pname,"simple_dialogs:dialoghelp",table.concat(formspec))
	else
		minetest.log("simple_dialogs->dialoghelp: ERROR unable to find simple_dialogs_help.txt in modpath")
	end 
end --dialog_help


----------------------------------------------------------------------


--call with tag=START for starting a dialog, or with no tag
function simple_dialogs.show_dialog_formspec(pname,npcself,tag)
	if not tag then tag="START" end
	minetest.show_formspec(pname,"simple_dialogs:dialog",get_dialog_formspec(pname,npcself,tag))
end --show_dialog_formspec


--this gets the dialog formspec for chatting with the npc
function simple_dialogs.get_dialog_formspec(pname,npcself,tag)
	--minetest.log("simple_dialogs->getdialogformspec: npcself="..dump(npcself))
	contextdlg[pname]={}
	contextdlg[pname].npcId=simple_dialogs.set_npc_id(npcself) --store the npc id in local context so we can use it when the form is returned.  (cant store self)
	---minetest.log("FFF setting contextdlg[pname] contextdlg="..dump(contextdlg))
	local formspec={
		"formspec_version[4]",
		"size[10,11.375]", 
		"position[0.75,0.5]",
		simple_dialogs.get_dialog_text_and_replies(pname,npcself,tag)
	}
	return table.concat(formspec,"")
end --get_dialog_formspec




function simple_dialogs.get_dialog_text_and_replies(pname,npcself,tag)
	--minetest.log("simple_dialogs->getdialogtar: pname="..pname.." tag="..tag)
	--minetest.log("simple_dialogs->getdialogtar: npcself="..dump(npcself))	
	--first we make certain everything is properly defined.  if there is an error we do NOT want to crash
	--but we do return an error message that might help debug.
	local errlabel="label[0.375,0.5; ERROR in get_dialog_text_and_replies, "
	if not npcself then return errlabel.." npcself not found]" 
	elseif not npcself.dialog then return errlabel.." npcself.dialog not found]" 
	elseif not tag or tag==nil then return errlabel.." tag passed was nil]"
	elseif not npcself.dialog[tag] then return errlabel.. " tag "..tag.." not found in the dialog]"
	end
	--
	local formspec={}
	--how many matching tags are there  (for example, if there are 3 "TREASURE" tags)
	local tagmax=#npcself.dialog[tag]
	--get a random number between 1 and the max weight
	local rnd=math.random(npcself.dialog[tag][tagmax].weight)
	local tagcount=1
	--we loop through all the matching tags and select the first one for which our random number
	--is less than or equal to that tags weight.
	for t=1,tagmax,1 do
		--minetest.log("simple_dialogs->getdialogtar: t="..t.." rnd="..rnd.." tag="..tag.." tagmax="..tagmax.." weight="..npcself.dialog[tag][t].weight)
		if rnd<=npcself.dialog[tag][t].weight then 
			tagcount=t
			break 
		end
	end
	--now tagcount equals the selected tagcount
	--minetest.log("simple_dialogs->getdialogtar: tag="..tag.." tagcount="..tagcount)
	--minetest.log("simple_dialogs->getdialogtar: before formspec npcself.dialog="..dump(npcself.dialog))
	local say=npcself.dialog[tag][tagcount].say
	say=simple_dialogs.populate_vars(npcself,say)
	--
	--now get the replylist
	local replies=""
	for r=1,#npcself.dialog[tag][tagcount].reply,1 do
		if r>1 then replies=replies.."," end
		local rply=npcself.dialog[tag][tagcount].reply[r].text
		rply=simple_dialogs.populate_vars(npcself,rply)
		--if string.len(rply)>70 then rply=string.sub(rply,1,70)..string.char(10)..string.sub(rply,71) end
		--TODO: this is a problem, wrapping once works, but is crowded.  wrapping 3 or more times overlaps text.
		--TODO: also, how to determine what the REAL wrap length should be based on player screen width?
		replies=replies..minetest.formspec_escape(simple_dialogs.wrap(rply,72,"     ",""))
	end --for
	local x=0.375
	local y=0.5
	local y2=y+5.375
	formspec={
		"textarea["..x..","..y..";9.4,5;;Dialog;"..minetest.formspec_escape(say).."]",
		"textlist["..x..","..y2..";9.4,5;reply;"..replies.."]"  --note that replies were escaped as they were added
	}
	--store the tag and tagcount in context as well
	contextdlg[pname].tag=tag
	contextdlg[pname].tagcount=tagcount
	return table.concat(formspec,"")
end --get_dialog_text_and_replies




--from http://lua-users.org/wiki/StringRecipes
function simple_dialogs.wrap(str, limit, indent, indent1)
	indent = indent or ""
	indent1 = indent1 or indent
	limit = limit or 72
	local here = 1-#indent1
	local function check(sp, st, word, fi)
		if fi - here > limit then
			here = st - #indent
			return "\n"..indent..word
		end
	end
	return indent1..str:gsub("(%s+)()(%S+)()", check)
end



minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()
	if formname ~= "simple_dialogs:dialog" then
		--if contextdlg[pname] then contextdlg[pname]=nil end  
		--can NOT clear context here because this can be called from inside the control panel, 
		--and that can be from a DIFFERENT mod where I can not predict the name
		return 
	end
	--minetest.log("simple_dialogs->receive_fields dialog: fields="..dump(fields))
	if   not contextdlg[pname] 
		or not contextdlg[pname].npcId 
		or not contextdlg[pname].tag 
		or not contextdlg[pname].tagcount 
		then 
			minetest.log("simpleDialogs->recieve_fields dialog: ERROR in dialog receive_fields: context not properly set")
			return 
	end
	local npcId=contextdlg[pname].npcId --get the npc id from local context
	local npcself=nil
	npcself=simple_dialogs.get_npcself_from_id(npcId)  --try to find the npcId in the list of luaentities
	local tag=contextdlg[pname].tag
	local tagcount=contextdlg[pname].tagcount
	--minetest.log("simple_dialogs->receive_fields dialog: tag="..tag.." tagcount="..tagcount.." npcId="..npcId)
	--minetest.log("simple_dialogs->receive_fields dialog: npcself="..dump(npcself))
	if   not npcself 
		or not npcself.dialog 
		or not npcself.dialog[tag] 
		or not npcself.dialog[tag][tagcount]
		then 
			minetest.log("simple_dialogs->receive_fields dialog: ERROR in dialog receive_fields: npcself.dialog[tag][tagcount] not found")
			return
	end
	--
	--incoming reply fields look like: fields={ ["reply"] = CHG:1,}
	if fields["reply"] then 
		--minetest.log("simple_dialogs-> sss got back reply!"..dump(fields["reply"]))
		local r=tonumber(string.sub(fields["reply"],5))
		if npcself.dialog[tag][tagcount].reply[r].target == "END" then
			minetest.close_formspec(pname, "simple_dialogs:dialog")
		else
			local newtag=npcself.dialog[tag][tagcount].reply[r].target
			minetest.show_formspec(pname,"simple_dialogs:dialog",simple_dialogs.get_dialog_formspec(pname,npcself,newtag))
		end
	end
end) --register_on_player_receive_fields dialog


--------------------------------------------------------------



function simple_dialogs.load_dialog_var(npcself,varname,varval)
	if npcself then
		if not npcself.dialogvars then npcself.dialogvars = {} end
		npcself.dialogvars[simple_dialogs.varname_filter(varname)] = varval
	end
end --load_dialog_var



--this function populates variables within dialog text
function simple_dialogs.populate_vars(npcself,line)
	if npcself and npcself.dialogvars then
		local grouping=simple_dialogs.build_grouping_list(line,chars.varopen,chars.varclose)
		--minetest.log("CCC vars="..dump(npcself.dialogvars))
		for i=1,#grouping.list,1 do
			--local gli=grouping.list[i]
			--minetest.log("CCC beforesectione i="..i.." grouping="..dump(grouping))
			local sectione=simple_dialogs.grouping_section(grouping,i,"EXCLUSIVE") --get section from string
			local k=simple_dialogs.varname_filter(sectione)  --k is our key value
			--minetest.log("CCC i="..i.." sectione="..sectione.." k="..k)
			if npcself.dialogvars[k] then --is this if necessary?
				line=simple_dialogs.grouping_replace(grouping,i,npcself.dialogvars[k],"INCLUSIVE")
			--line=string.sub(line,1,list[i].open-1)..string.upper(string.sub(line,list[i].open,list[i].close))..string.sub(line,list[i].close+1)
			end --if
		end --for
	end --if
	return line
end --populate_vars




--------------------------------------------------------------


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




--[[ *******************************************************************************
Grouping
These would probably be better separated into a different lua, perhaps even a different mod?
--]]





--this function will go through a string and build a list that tells what order
--to process parenthesis (or any other open close delimiter) in.
--example:
--12345678901234
--((3*(21+2))/4)
--list[1].open=5 close=10
--list[2].open=2 close=11
--list[3].open=1 close=14
--note that if you pass this txt that has bad syntax, it will not throw an error, but instead return an empty list
--list[].open and close are inclusive.  it includes the delimeter
--list[].opene and closee are exclusive.  it does NOT include the delimiter
--so in the above example:
--list[1].opene=6 close=9
--list[2].opene=3 close=10
--list[3].opene=2 close=13
function simple_dialogs.build_grouping_list(txt,opendelim,closedelim)
	--minetest.log("GGG build grouping top, txt="..txt)
	local grouping={}
	grouping.list={}
	grouping.origtxt=txt --is this useful?
	grouping.txt=txt
	local openstack={}
	local opendelim_len=string.len(opendelim)
	grouping.opendelim_len=opendelim_len
	local closedelim_len=string.len(closedelim)
	grouping.closedelim_len=closedelim_len
	--local i=string.find(txt,opendelim)-1 --start just before first open delim   (causes problems because of [ being a special character to find)
	for i=1,string.len(txt),1 do
		if string.sub(txt,i,i+opendelim_len-1)==opendelim then --open delim
			openstack[#openstack+1]=i  --open pos onto stack.
		elseif string.sub(txt,i,i+closedelim_len-1)==closedelim then -- close delim
			--if you find parens out of order, just stop and return an empty list
			if #openstack<1 then return {} end 
			local l=#grouping.list+1
			grouping.list[l]={}
			local gll=grouping.list[l]
			gll.open=openstack[#openstack]
			gll.opene=gll.open+(opendelim_len)
			gll.close=i+(closedelim_len-1)
			gll.closee=i-1
			--gll.section=string.sub(grouping.origtxt,gll.open,gll.close)
			--gll.sectione=string.sub(grouping.origtxt,gll.opene,gll.closee)
			table.remove(openstack,#openstack) --remove from stack
		end --if
	end --while
	--minetest.log("GGG about to return")
	return grouping
end --build_grouping_list



function simple_dialogs.grouping_section(grouping,i,incl_excl)
	if not incl_excl then incl_excl="INCLUSIVE" end
	--minetest.log("GGGs top i="..i.." incl_excl="..incl_excl)
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


