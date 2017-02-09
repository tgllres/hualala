--[[
   author: dangersheng@hualala.com
   date: 2017/02/09
   version: 1.1
--]]
local resty_lock = require "resty.lock"
local cjson = require "cjson"
local cache = ngx.shared.cache
local ngx_log = ngx.log

local _M = {}

function _M.rawset(key, value, exptime)
  --ngx_log(ngx.ERR, key.."exptime time is:", exptime)
  return cache:set(key, value, exptime or 0)
end

function _M.set(key, value, exptime)
  if value then
    value = cjson.encode(value)
  end

  return _M.rawset(key, value, exptime)
end

function _M.rawget(key)
  return cache:get(key)
end

function _M.get(key)
  local value, flags = _M.rawget(key)
  if value then
    value = cjson.decode(value)
  end
  return value, flags
end

function _M.incr(key, value)
  return cache:incr(key, value)
end

function _M.delete(key)
  cache:delete(key)
end

function _M.delete_all()
  cache:flush_all() -- This does not free up the memory, only marks the items as expired
  cache:flush_expired() -- This does actually remove the elements from the memory
end

function _M.get_or_set(key, cb)
  -- Try to get the value from the cache
  local value = _M.get(key)
  if (value ~= nil) then 
	ngx_log(ngx.ERR, key.." get value is:", value)
	return value 
  end

  local lock, err = resty_lock:new("cache_locks", {
    exptime = 30,
    timeout = 5
  })
  if not lock then
    ngx_log(ngx.ERR, "could not create lock: ", err)
    return
  end

  -- The value is missing, acquire a lock
  local elapsed, err = lock:lock(key)
  if not elapsed then
    ngx_log(ngx.ERR, "failed to acquire cache lock: ", err)
  end

  -- Lock acquired. Since in the meantime another worker may have
  -- populated the value we have to check again
  value = _M.get(key)
  if (value == nil) then
    -- Get from closure
    value = cb()
    local exptime = 30
    local ok, err = _M.set(key, value, exptime)
    if not ok then
        ngx_log(ngx.ERR, err)
    end
	ngx_log(ngx.ERR, key.." cb value is:", value)
  end

  local ok, err = lock:unlock()
  if not ok and err then
    ngx_log(ngx.ERR, "failed to unlock: ", err)
  end

  return value
end

return _M
