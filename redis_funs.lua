--[[ 
   author: dangersheng@hualala.com
   date: 2016/12/09
   version: 1.0 
--]]
local redis = require "kong.core.redis_iresty"
local _M = {}
function _M.IsInGroupIds(set, value)
    local red = redis:new()
    local res, err = red:sismember(set, value)
    if res == 1 then
        ngx.log(ngx.ERR, "redis_search:"..res)
        return true
    else
        ngx.log(ngx.ERR, "redis_search:"..res)
        return false
    end
end

function _M.GetValue(hkey, field)
    local red = redis:new()
    --redis hashtable,from hkey
    --ngx.log(ngx.ERR, "redis_field:"..field)
        local res, err = red:hget(hkey, field)
    if (res ~= nil) then
        ngx.log(ngx.ERR, "redis_search:"..res)
        return res
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
