-- utils
local ini = {}

function ini.parse(s)
	local t = {}
	local section = nil
	for line in s:gmatch("[^\r\n]+") do
		local s = line:match("^%s*(.-)%s*$")
		if s ~= "" then
			local sec = s:match("^%[([^%[%]]+)%]$")
			if sec then
				section = sec
				t[section] = t[section] or {}
			else
				local key, value = s:match("^([^=]+)=(.*)$")
				if key and value then
					key = key:match("^%s*(.-)%s*$")
					value = value:match("^%s*(.-)%s*$")
					if section then
						t[section][key] = tonumber(value) or value
					else
						t[key] = tonumber(value) or value
					end
				end
			end
		end
	end
	return t
end

function ini.stringify(t)
	local s = {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			s[#s + 1] = "[" .. k .. "]"
			for k2, v2 in pairs(v) do
				s[#s + 1] = k2 .. "=" .. tostring(v2)
			end
		else
			s[#s + 1] = k .. "=" .. tostring(v)
		end
	end
	return table.concat(s, "\n")
end

local M = {
	count = 0,
	minute = 0,
	second = 0,
	status = 0,

	chunk = 4,
	round = 25,
	short_break = 5,
	long_break = 15,
}

-- local notify = require("notify")
-- notify.setup({
--   render = 'simple'
-- })

local formater = function(n)
	if n < 10 then
		return "0" .. tostring(n)
	end
	return tostring(n)
end

local n = function(msg)
	-- local title = '🍅 Tomato Timer 🍅'
	-- local level = vim.log.levels.INFO
	-- notify(msg, level, { title = title })
end

local icons = {
	tomato = "🍅",
	-- start = "⏰",
	start = "🙇",
	short_break = "☕",
	long_break = "☕☕",
}

local status = {
	reset = 0,
	start = 1,
	short_break = 2,
	long_break = 3,
}

function M.setup(option)
	if option then
		M.chunk = option.chunk
		M.round = option.round
		M.short_break = option.short_break
		M.long_break = option.long_break
	end
end

function M.getTimer()
	local timer = vim.loop.new_timer()
	M._timer = timer
	return timer
end

function M.closeTimer()
	if M._timer then
		M._timer:close()
	end
end

function M.record_tomato()
	local key = "count"
	local path = vim.loop.cwd() .. "/.tomato"
	local f = io.open(path, "r")
	if f ~= nil then
		local data = ini.parse(f:read("*all"))
		f:close()
		if type(data) ~= "table" then
			data = {}
		end
		data[key] = (data[key] or 0) + 1
		f = io.open(path, "w")
		f:write(ini.stringify(data))
		f:close()
	end
end

-- status switch
function M.switch(s)
	if s == status.start then
		M.start_round()
	elseif s == status.short_break then
		M.start_short_break()
	elseif s == status.long_break then
		M.start_long_break()
	elseif s == status.reset then
		M.reset()
	end
end

function M.start_round()
	if M.status == status.reset or M.status == status.short_break or M.status == status.long_break then
		M.status = status.start
		M.minute = M.round
		M.count = M.count + 1
		local timer = M.getTimer()
		n("Let's start round " .. tostring(M.count))
		timer:start(
			1000,
			1000,
			vim.schedule_wrap(function()
				if M.minute == 0 and M.second == 0 then
					timer:close()
					M.record_tomato()
					if M.count % M.chunk > 0 then
						M.switch(status.short_break)
					else
						M.switch(status.long_break)
					end
				elseif M.second == 0 then
					M.second = 59
					M.minute = M.minute - 1
				else
					M.second = M.second - 1
				end
			end)
		)
	end
end

function M.start_short_break()
	if M.status == status.start then
		M.status = status.short_break
		M.minute = M.short_break
		M.second = 0
		local timer = M.getTimer()
		n("Let's have a " .. tostring(M.short_break) .. " minutes rest " .. icons.short_break .. " !")
		timer:start(
			1000,
			1000,
			vim.schedule_wrap(function()
				if M.minute == 0 and M.second == 0 then
					timer:close()
					M.switch(status.start)
				elseif M.second == 0 then
					M.second = 59
					M.minute = M.minute - 1
				else
					M.second = M.second - 1
				end
			end)
		)
	end
end

function M.start_long_break()
	if M.status == status.start then
		M.status = status.long_break
		M.minute = M.long_break
		local timer = M.getTimer()
		n("Let's have a " .. tostring(M.long_break) .. " minutes rest " .. icons.long_break .. " !")
		timer:start(
			1000,
			1000,
			vim.schedule_wrap(function()
				if M.minute == 0 and M.second == 0 then
					timer:close()
					M.switch(status.start)
				elseif M.second == 0 then
					M.second = 59
					M.minute = M.minute - 1
				else
					M.second = M.second - 1
				end
			end)
		)
	end
end

function M.reset()
	if M.status > 0 then
		M.count = 0
		M.status = 0
		M.minute = 0
		M.second = 0
		M.closeTimer()
	end
end

function M.message()
	local icon = ""
	if M.status == status.start then
		icon = icons.start
	elseif M.status == status.short_break then
		icon = icons.short_break
	elseif M.status == status.long_break then
		icon = icons.long_break
	else
		icon = icons.tomato
		return icon .. " Not Start"
	end
	return icon .. " " .. formater(M.minute) .. ":" .. formater(M.second)
end

return M
