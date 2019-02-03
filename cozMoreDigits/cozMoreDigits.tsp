-- MIT License
-- Copyright (c) 2019 Cuneyt Ozdas 
-- see https://github.com/cozdas/DMM6500 for full info and updates

-- contants
BUFLEN = 10000

function StringToUnit(str)
	stringToUnit= { 
		["Amp AC"]		= buffer.UNIT_AMP_AC, 
		["Amp DC"]		= buffer.UNIT_AMP,
		["Celsius"]		= buffer.UNIT_CELSIUS,
		["Decibel"]		= buffer.UNIT_DECIBEL,
		["dBm"]			= buffer.UNIT_DBM,
		["Fahrenheit"]	= buffer.UNIT_FAHRENHEIT,
		["Farad"]		= buffer.UNIT_FARAD,
		["Hertz"]		= buffer.UNIT_HERTZ,
		["Kelvin"]		= buffer.UNIT_KELVIN,
		["mX+b"]		= buffer.UNIT_X,
		["Ohm"]			= buffer.UNIT_OHM,
		["%"]			= buffer.UNIT_PERCENT,
		["Ratio"]		= buffer.UNIT_RATIO,
		["Reciprocal"]	= buffer.UNIT_RECIPROCAL,
		["Second"]		= buffer.UNIT_SECOND,
		["Volt AC"]		= buffer.UNIT_VOLT_AC,
		["Volt DC"]		= buffer.UNIT_VOLT,
		["Watt DC"]		= buffer.UNIT_WATT
	}
	
	if str==nil then return  buffer.UNIT_NONE end  

	_u = stringToUnit[str]
	if(_u==nil) then 
		_u = buffer.UNIT_NONE
		print("unit unknown: " .. str) 
	end
	return _u
end

function StringToSymbol(str)
	stringToSymbol= { 
		["Amp AC"]		= "A", 
		["Amp DC"]		= "A",
		["Celsius"]		= "C",
		["Decibel"]		= "dB",
		["dBm"]			= "dBm",
		["Fahrenheit"]	= "F",
		["Farad"]		= "F",
		["Hertz"]		= "Hz",
		["Kelvin"]		= "K",
		["mX+b"]		= "mX+b",
		["Ohm"]			= "Ohm",
		["%"]			= "%",
		["Ratio"]		= "R",
		["Reciprocal"]	= "1/X",
		["Second"]		= "s",
		["Volt AC"]		= "V",
		["Volt DC"]		= "V",
		["Watt DC"]		= "W"
	}
	
	if str==nil then return "" end

	_sym = stringToSymbol[str]
	if(_sym==nil) then 
		_sym = "?"
		print("unit unknown: " .. str) 
	end
	return _sym
end	

function ValuePrefix(value)
	if value>=9.9e37 then return "OVR","" end 
		
	a = math.abs(value)
	p = ""
	v = value
	
	if a==0.0 then
		return "0.0", ""
	elseif a <1e-12 then
		v = v * 1e15
		p = "f"
	elseif a<1e-9 then
		v = v * 1e12
		p = "p"
	elseif a<1e-6 then
		v = v * 1e9
		p = "n"
	elseif a<1e-3 then
		v = v * 1e6
		p = "u"
	elseif a<1 then
		v = v * 1e3
		p = "m"
	elseif a>1e15 then
		v = v * 1e-15
		p = "P"
	elseif a>1e12 then
		v = v * 1e-12
		p = "T"
	elseif a>1e9 then
		v = v * 1e-9
		p = "G"
	elseif a>1e6 then
		v = v * 1e-6
		p = "M"
	elseif a>1e3 then
		v = v * 1e-3
		p = "k"
	end
	
	return string.format("%.9f", v), p
end	



--get the current measure function
mFunction = dmm.measure.func

-- create a reading buffer with extra field to hold the sense voltage
readBuf = buffer.make(BUFLEN, buffer.STYLE_FULL)
readBuf.fillmode = buffer.FILL_CONTINUOUS


-- do one reading to grab the units
res = dmm.measure.read(readBuf)

-- determine the unit of the buffer
unitstr = readBuf.units[1]
unit = StringToUnit(unitstr)

extunitstr = readBuf.extravalueunits[1]
extunit = StringToUnit(extunitstr)

--create two writable buffers to store computed voltages
ValBuf = buffer.make(BUFLEN, buffer.STYLE_WRITABLE_FULL)
ExtBuf = buffer.make(BUFLEN, buffer.STYLE_WRITABLE_FULL)

-- TODO: set the units
buffer.write.format(ValBuf, unit, buffer.DIGITS_8_5) -- you can't set reading buffers to 8.5 digit 
buffer.write.format(ExtBuf, extunit, buffer.DIGITS_8_5) -- but write buffers accept it (actually default is 8.5). YAY!!!
ValBuf.fillmode = buffer.FILL_CONTINUOUS
ExtBuf.fillmode = buffer.FILL_CONTINUOUS

-- Set Display
-- unfortunately I can't set the graph buffers programatically. Needs to be done manually 
display.activebuffer = ValBuf

-- sample in a loop for interactive display
for x=1,BUFLEN do
	--Read the value and compute individual voltages
	dmm.measure.read(readBuf)
	n = readBuf.n
	val = readBuf.readings[n]
	ext = readBuf.extravalues[n]
	--date = readBuf.dates[n]
	fracsec = readBuf.fractionalseconds[n]
	sec = readBuf.seconds[n]
	sta = readBuf.statuses[n]
	--time = readBuf.times[n]
	--timestamp = readBuf.timestamps[n]
	unit = readBuf.units[n]
	extunit = readBuf.extravalueunits[n]
	
	sym = StringToSymbol(unit)
	extsym = StringToSymbol(extunit)
	
	--write computed values to write buffers
	buffer.write.reading(ValBuf, val, ext, sec, fracsec, sta)
	buffer.write.reading(ExtBuf, ext, val, sec, fracsec, sta)
	
	-- apply metric prefix
	valstr, prefval = ValuePrefix(val)
	extstr, prefext = ValuePrefix(ext)
	
	--display values
	s1 = string.format("In:%s%s Sense:%s%s", prefval, sym, prefext, extsym)
	display.settext(display.TEXT1, s1)
	
	s2 = string.format("I:%s S:%s", valstr, extstr)
	display.settext(display.TEXT2, s2)
end

