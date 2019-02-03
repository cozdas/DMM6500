-- DUMP objects
------------------------------
seen={}

function printAndRecurse(prefix, val, name, skipunderscore)
	
	local note = ""
	local isNew = true
	if(seen[val]) then
		isNew = false 
		note = note .. " ***Listed Before***" 
	end
	
   	local skip = false
   	if skipunderscore and string.sub(name,1,2)=="__" then 
   		skip=true 
   		note = note .. " *skipped*"
   	end
	
    print(prefix, name .. " -> " .. tostring(val) .. " (" ..  type(val) .. ")" .. note)
    
    if type(val)=="table" and isNew and not skip then
        dump(val, prefix.."\t", skipunderscore)
    end
end

function dump(obj, prefix, skipunderscore)
	
	--print("dumping: " .. tostring(obj))
	
    seen[obj]=true
    local groups={}
    local n=0
    
    -- table
    for name, val in pairs(obj) do
    	local nn = tostring(name)
    	if nn == "Getters" then nn="0000 Getters" end --better sort
    	if nn == "Setters" then nn="0000 Setters" end
    	--n=n+1 
        --names[n] = nn
        if groups[type(val)]==nil then groups[type(val)]={} end
        n=table.getn(groups[type(val)])+1
        groups[type(val)][n]=nn
        --print(tostring(name) ..":" .. type(name) .. " " .. tostring(val) .. ":" .. type(val))
    end
    
    -- meta table
    local meta = getmetatable(obj)
    if meta!= nil and type(meta)=="table" then
	    for name, val in pairs(meta) do
   			local nn = tostring(name)
    		if nn == "Getters" then nn="0000 Getters" end  --better sort
    		if nn == "Setters" then nn="0000 Setters" end
    		if groups[type(val)]==nil then groups[type(val)]={} end
        	n=table.getn(groups[type(val)])+1
        	groups[type(val)][n]=nn
	    end
    end
    
    --sort groups
    table.sort(groups)
    
    --for all groups
    for key, names in groups do
    	
    	--sort within group
		table.sort(names)

		-- print and recurse    
	    for i, nn in ipairs(names) do
	    	name = nn
	    	if name=="0000 Getters" then name="Getters" end -- undo sort helper
	    	if name=="0000 Setters" then name="Setters" end
	    	
	    	--check in normal table
	    	val= obj[name]
	        if val then
	        	printAndRecurse(prefix, val, name, skipunderscore)
		    end
		   
		   --check in metatable
		   if meta and meta[name] then
		        local valm = meta[name]
		        printAndRecurse(prefix, valm, name, skipunderscore)
			end
	    end
	end
end

print("==================== DUMP: ki.display ==================")
seen={} dump(ki.display,"", false) 

--print("==================== DUMP: fan ==================")
--seen={} dump(fan,"", true)

--print("==================== DUMP: dmm ==================")
--seen={} dump(dmm,"", true)

--print("==================== DUMP: display ==================")
--seen={} dump(display,"", true)   

print("==================== DUMP: ALL ==================")
seen={} dump(_G ,"", false)  
