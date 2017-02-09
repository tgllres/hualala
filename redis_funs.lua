--[[
   author: dangersheng@hualala.com
   date: 2017/02/03
   version: 1.1
--]]

local redis = require "kong.core.redis_iresty"
local cache = require "kong.core.redis_cache"
local _M = {}
function _M.IsInGroupIds(set, value)
    local cache_key = set..'_'..value
    local cache_value = cache.get_or_set(cache_key, function()
		local red = redis:new()
		local res, err = red:sismember(set, value)
		if res == 1 then
			return true
		else
			return false
		end
	end)
	if cache_value then
		return true
	else
		return false
	end
end

function _M.GetValue(hkey, field)
    local cache_key = hkey..'_'..field
    local cache_value = cache.get_or_set(cache_key, function()
		local red = redis:new()
		--redis hashtable,from hkey
		local res, err = red:hget(hkey, field)
		if (res ~= nil) then
			ngx.log(ngx.ERR, "redis_search:"..res)
			return res
		else
			return false
		end
	end)
	if (cache_value ~= false) then
		return cache_value
	else
		return nil
	end
end
function _M.SetValue(set, value)
    local red = redis:new()
    local res, err = red:sadd(set, value)
    if res == 1 then
        return true
    else
        return false
    end
end
return _M
